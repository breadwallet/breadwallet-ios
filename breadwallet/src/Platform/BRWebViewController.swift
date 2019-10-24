//
//  BRWebViewController.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 12/10/15.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import UIKit
import WebKit

open class BRWebViewController: UIViewController, WKNavigationDelegate, BRWebSocketClient {
    var wkProcessPool: WKProcessPool
    var webView: WKWebView?
    var bundleName: String
    var server = BRHTTPServer()
    var debugEndpoint: String?
    var mountPoint: String
    var walletAuthenticator: TransactionAuthenticator
    
    var didClose: (() -> Void)?

    // bonjour debug endpoint establishment - this will configure the debugEndpoint 
    // over bonjour if debugOverBonjour is set to true. this MUST be set to false 
    // for production deploy targets
    let debugOverBonjour = false
    let bonjourBrowser = Bonjour()
    var debugNetService: NetService?
    
    // didLoad should be set to true within didLoadTimeout otherwise a view will be shown which
    // indicates some error. this is to prevent the white-screen-of-death where there is some
    // javascript exception (or other error) that prevents the content from loading
    var didLoad = false
    var didAppear = false
    var didLoadTimeout = 2500
    
    // we are also a socket server which sends didview/didload events to the listening client(s)
    var sockets = [String: BRWebSocket]()
    
    // this is the data that occasionally gets sent to the above connected sockets
    var webViewInfo: [String: Any] {
        return [
            "visible": didAppear,
            "loaded": didLoad
        ]
    }
    
    var indexUrl: URL {
        return URL(string: "http://127.0.0.1:\(server.port)\(mountPoint)")!
    }
    
    private let messageUIPresenter = MessageUIPresenter()

    private var notificationObservers = [String: NSObjectProtocol]()
    
    init(bundleName: String, mountPoint: String = "/", walletAuthenticator: TransactionAuthenticator) {
        wkProcessPool = WKProcessPool()
        self.bundleName = bundleName
        self.mountPoint = mountPoint
        self.walletAuthenticator = walletAuthenticator
        super.init(nibName: nil, bundle: nil)
        if debugOverBonjour {
            setupBonjour()
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        notificationObservers.values.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        stopServer()
    }
    
    override open func loadView() {
        didLoad = false
        let config = WKWebViewConfiguration()
        config.processPool = wkProcessPool
        config.allowsInlineMediaPlayback = false
        config.allowsAirPlayForMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        config.allowsPictureInPictureMediaPlayback = false

        let request = URLRequest(url: indexUrl)
        
        view = UIView(frame: CGRect.zero)
        view.backgroundColor = .darkBackground
        
        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView?.navigationDelegate = self
        webView?.backgroundColor = .darkBackground
        webView?.isOpaque = false   // prevents white background flash before web content is rendered  
        webView?.alpha = 0.0
        _ = webView?.load(request)
        webView?.autoresizingMask = [UIView.AutoresizingMask.flexibleHeight, UIView.AutoresizingMask.flexibleWidth]
        webView?.scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(webView!)
        
        let center = NotificationCenter.default
        notificationObservers[UIApplication.didBecomeActiveNotification.rawValue] =
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] (_) in
                self?.didAppear = true
                if let info = self?.webViewInfo {
                    self?.sendToAllSockets(data: info)
                }
        }
        notificationObservers[UIApplication.willResignActiveNotification.rawValue] =
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] (_) in
                self?.didAppear = false
                if let info = self?.webViewInfo {
                    self?.sendToAllSockets(data: info)
                }
        }
        self.messageUIPresenter.presenter = self
    }
    
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        edgesForExtendedLayout = .all
        self.beginDidLoadCountdown()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didAppear = true
        sendToAllSockets(data: webViewInfo)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        didAppear = false
        sendToAllSockets(data: webViewInfo)
    }
    
    // this should be called when the webview is expected to load content. if the content has not signaled
    // that is has loaded by didLoadTimeout then an alert will be shown allowing the user to back out
    // of the faulty webview
    fileprivate func beginDidLoadCountdown() {
        let timeout = DispatchTime.now() + .milliseconds(self.didLoadTimeout)
        DispatchQueue.main.asyncAfter(deadline: timeout) { [weak self] in
            guard let myself = self else { return }
            if myself.didAppear && !myself.didLoad {
                // if the webview did not load the first time lets refresh the bundle. occasionally the bundle
                // update can fail, so this update should fetch an entirely new copy
                let activity = BRActivityViewController(message: S.Webview.dismiss)
                myself.present(activity, animated: true, completion: nil)
                Backend.apiClient.updateBundles(completionHandler: { results in
                    results.forEach({ _, err in
                        if err != nil {
                            print("[BRWebViewController] error updating bundle: \(String(describing: err))")
                        }
                        // give the webview another chance to load
                        DispatchQueue.main.async {
                            self?.refresh()
                        }
                        // XXX(sam): log this event so we know how frequently it happens
                        DispatchQueue.main.asyncAfter(deadline: timeout) {
                            Store.trigger(name: .showStatusBar)
                            self?.dismiss(animated: true) {
                                self?.notifyUserOfLoadFailure()
                                if let didClose = self?.didClose {
                                    didClose()
                                }
                            }
                        }
                    })
                })
            }
        }
    }

    fileprivate func notifyUserOfLoadFailure() {
        if self.didAppear && !self.didLoad {
            let alert = UIAlertController.init(
                title: S.Alert.error,
                message: S.Webview.errorMessage,
                preferredStyle: .alert
            )
            let action = UIAlertAction(title: S.Webview.dismiss, style: .default) { [weak self] _ in
                self?.closeNow()
            }
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }

    // signal to the presenter that the webview content successfully loaded
    fileprivate func webviewDidLoad() {
        didLoad = true
        UIView.animate(withDuration: 0.4) {
            self.webView?.alpha = 1.0
        }
        sendToAllSockets(data: webViewInfo)
    }
    
    fileprivate func closeNow() {
        Store.trigger(name: .showStatusBar)
        
        let didClose = self.didClose
        
        dismiss(animated: true, completion: {
            if let didClose = didClose {
                didClose()
            }
        })
    }
    
    open func startServer() {
        do {
            if !server.isStarted {
                try server.start()
                setupIntegrations()
            }
        } catch let e {
            print("\n\n\nSERVER ERROR! \(e)\n\n\n")
        }
    }
    
    open func stopServer() {
        if server.isStarted {
            server.stop()
            server.resetMiddleware()
        }
    }

    func navigate(to: String) {
        let js = "window.location = '\(to)';"
        webView?.evaluateJavaScript(js, completionHandler: { _, error in
            if let error = error {
                print("WEBVIEW navigate to error: \(String(describing: error))")
            }
        })
    }
    
    // this will look on the network for any _http._tcp bonjour services whose name
    // contains th string "webpack" and will set our debugEndpoint to whatever that 
    // resolves to. this allows us to debug bundles over the network without complicated setup
    fileprivate func setupBonjour() {
        _ = bonjourBrowser.findService("_http._tcp") { [weak self] (services) in
            for svc in services {
                if !svc.name.lowercased().contains("webpack") {
                    continue
                }
                self?.debugNetService = svc
                svc.resolve(withTimeout: 1.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                    guard let netService = self?.debugNetService else {
                        return
                    }
                    self?.debugEndpoint = "http://\(netService.hostName ?? ""):\(netService.port)"
                    print("[BRWebViewController] discovered bonjour debugging service \(String(describing: self?.debugEndpoint))")
                    self?.server.resetMiddleware()
                    self?.setupIntegrations()
                    self?.refresh()
                }
                break
            }
        }
    }
    
    fileprivate func setupIntegrations() {
        // proxy api for signing and verification
        let apiProxy = BRAPIProxy(mountAt: "/_api", client: Backend.apiClient)
        server.prependMiddleware(middleware: apiProxy)
        
        // http router for native functionality
        let router = BRHTTPRouter()
        server.prependMiddleware(middleware: router)
        
        if let archive = AssetArchive(name: bundleName, apiClient: Backend.apiClient) {
            // basic file server for static assets
            let fileMw = BRHTTPFileMiddleware(baseURL: archive.extractedUrl, debugURL: UserDefaults.platformDebugURL)
            server.prependMiddleware(middleware: fileMw)
            
            // middleware to always return index.html for any unknown GET request (facilitates window.history style SPAs)
            let indexMw = BRHTTPIndexMiddleware(baseURL: fileMw.baseURL)
            server.prependMiddleware(middleware: indexMw)
            
            // enable debug if it is turned on
            if let debugUrl = debugEndpoint {
                let url = URL(string: debugUrl)
                fileMw.debugURL = url
                indexMw.debugURL = url
            }
        }
        
        // geo plugin provides access to onboard geo location functionality
        router.plugin(BRGeoLocationPlugin())
        
        // camera plugin 
        router.plugin(BRCameraPlugin(fromViewController: self))
        
        // wallet plugin provides access to the wallet
        router.plugin(BRWalletPlugin(walletAuthenticator: walletAuthenticator))
        
        // link plugin which allows opening links to other apps
        router.plugin(BRLinkPlugin(fromViewController: self))
        
        // kvstore plugin provides access to the shared replicated kv store
        router.plugin(BRKVStorePlugin(client: Backend.apiClient))
        
        // GET /_close closes the browser modal
        router.get("/_close") { [weak self] (request, _) -> BRHTTPResponse in
            DispatchQueue.main.async {
                self?.closeNow()
            }
            return BRHTTPResponse(request: request, code: 204)
        }

        //GET /_email opens system email dialog
        // Status codes:
        //   - 200: Presented email UI
        //   - 400: No address param provided
        router.get("_email") { [weak self] (request, _) -> BRHTTPResponse in
            if let email = request.query["address"], email.count == 1 {
                DispatchQueue.main.async {
                    self?.messageUIPresenter.presentMailCompose(emailAddress: email[0])
                }
                return BRHTTPResponse(request: request, code: 200)
            } else {
                return BRHTTPResponse(request: request, code: 400)
            }
        }
        
        // GET /_didload signals to the presenter that the content successfully loaded
        router.get("/_didload") { [weak self] (request, _) -> BRHTTPResponse in
            DispatchQueue.main.async {
                self?.webviewDidLoad()
            }
            return BRHTTPResponse(request: request, code: 204)
        }
        
        // socket /_webviewinfo will send info about the webview state to client
        router.websocket("/_webviewinfo", client: self)
        
        router.printDebug()
    }
    
    open func preload() {
        _ = self.view // force webview loading
    }
    
    open func refresh() {
        let request = URLRequest(url: indexUrl)
        _ = webView?.load(request)
    }
    
    // MARK: - navigation delegate
    
    open func webView(_ webView: WKWebView,
                      decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let host = url.host, let port = (url as NSURL).port {
            if host == server.listenAddress || port.int32Value == Int32(server.port) {
                return decisionHandler(.allow)
            }
        }
        print("[BRWebViewController disallowing navigation: \(navigationAction)")
        decisionHandler(.cancel)
    }
    
    // MARK: - socket delegate
    func sendTo(socket: BRWebSocket, data: [String: Any]) {
        do {
            let j = try JSONSerialization.data(withJSONObject: data, options: [])
            if let s = String(data: j, encoding: .utf8) {
                socket.request.queue.async {
                    socket.send(s)
                }
            }
        } catch let e {
            print("LOCATION SOCKET FAILED ENCODE JSON: \(e)")
        }
    }
    
    func sendToAllSockets(data: [String: Any]) {
        for (_, s) in sockets {
            sendTo(socket: s, data: data)
        }
    }
    
    public func socketDidConnect(_ socket: BRWebSocket) {
        print("WEBVIEW SOCKET CONNECT \(socket.id)")
        sockets[socket.id] = socket
        sendTo(socket: socket, data: webViewInfo)
    }
    
    public func socketDidDisconnect(_ socket: BRWebSocket) {
        print("WEBVIEW SOCKET DISCONNECT \(socket.id)")
        sockets.removeValue(forKey: socket.id)
    }
    
    public func socket(_ socket: BRWebSocket, didReceiveText text: String) {
        print("WEBVIEW SOCKET RECV TEXT \(text)")
    }
    
    public func socket(_ socket: BRWebSocket, didReceiveData data: Data) {
        print("WEBVIEW SOCKET RECV TEXT \(data.hexString)")
    }
}
