//
//  BRWebViewController.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 12/10/15.
//  Copyright (c) 2016 breadwallet LLC
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import UIKit
import WebKit


@available(iOS 8.0, *)
@objc open class BRWebViewController : UIViewController, WKNavigationDelegate, BRWebSocketClient {
    var wkProcessPool: WKProcessPool
    var webView: WKWebView?
    var server = BRHTTPServer()
    var debugEndpoint: String?
    var mountPoint: String
    var walletManager: WalletManager
    let store: Store
    let noAuthApiClient: BRAPIClient?
    let partner : String?

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
            "loaded": didLoad,
        ]
    }
    
    var indexUrl: URL {
        switch mountPoint {
            case "/buy":
                ///new string concatenation needed for Simplex buy feature (v2.1.5+)
                var appInstallDate: Date {
                    if let documentsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
                        if let installDate = try! FileManager.default.attributesOfItem(atPath: documentsFolder.path)[.creationDate] as? Date {
                            return installDate
                        }
                    }
                    return Date()
                }
                let walletAddress = walletManager.wallet?.receiveAddress
                let currencyCode = Locale.current.currencyCode
                let uuid = UIDevice.current.identifierForVendor!.uuidString
          
                return URL(string: getSimplexParams(appInstallDate: appInstallDate,  walletAddress: walletAddress, currencyCode: currencyCode, uuid: uuid))!
            case "/support":
                return URL(string: "https://api.loafwallet.org/support")!
            case "/ea":
                return URL(string: "https://api.loafwallet.org/ea")!
            default:
                return URL(string: "http://127.0.0.1:\(server.port)\(mountPoint)")!
        }
    }
    
    private func getSimplexParams(appInstallDate: Date?, walletAddress: String?, currencyCode: String?, uuid: String?) -> String {
        guard let appInstallDate = appInstallDate else { return "" }
        guard let walletAddress = walletAddress else { return "" }
        guard let currencyCode = currencyCode else { return "" }
        guard let uuid = uuid else { return "" }
        
        let timestamp = Int(appInstallDate.timeIntervalSince1970)
      
        return "https://buy.loafwallet.org/?address=\(walletAddress)&code=\(currencyCode)&idate=\(timestamp)&uid=\(uuid)"
    }
    
    private let messageUIPresenter = MessageUIPresenter()
    
  init(partner: String?, bundleName: String, mountPoint: String = "/", walletManager: WalletManager, store: Store, noAuthApiClient: BRAPIClient? = nil) {
        wkProcessPool = WKProcessPool()
        self.mountPoint = mountPoint
        self.walletManager = walletManager
        self.store = store
        self.noAuthApiClient = noAuthApiClient
        self.partner = partner ?? ""
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadView() {
        didLoad = false
        let config = WKWebViewConfiguration()
        config.processPool = wkProcessPool
        config.allowsInlineMediaPlayback = false
        config.allowsAirPlayForMediaPlayback = false
        config.requiresUserActionForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = false

        let request = URLRequest(url: indexUrl)
        
        view = UIView(frame: CGRect.zero)
        view.backgroundColor = UIColor(red:0.98, green:0.98, blue:0.98, alpha:1.0)
      
        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView?.navigationDelegate = self
        webView?.backgroundColor = UIColor(red:0.98, green:0.98, blue:0.98, alpha:1.0)
        _ = webView?.load(request)
        webView?.autoresizingMask = [UIViewAutoresizing.flexibleHeight, UIViewAutoresizing.flexibleWidth]
        if #available(iOS 11, *) {
            webView?.scrollView.contentInsetAdjustmentBehavior = .never
        }
        view.addSubview(webView!)
      
        let center = NotificationCenter.default
        center.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: .main) { [weak self] (_) in
            self?.didAppear = true
            if let info = self?.webViewInfo {
                self?.sendToAllSockets(data: info)
            }
        }
        center.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: .main) { [weak self] (_) in
            self?.didAppear = false
            if let info = self?.webViewInfo {
                self?.sendToAllSockets(data: info)
            }
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        didAppear = true
        sendToAllSockets(data: webViewInfo)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        didAppear = false
        sendToAllSockets(data: webViewInfo)
    }

    // signal to the presenter that the webview content successfully loaded
    fileprivate func webviewDidLoad() {
        didLoad = true
        sendToAllSockets(data: webViewInfo)
    }
    
    fileprivate func closeNow() {
        store.trigger(name: .showStatusBar)
        dismiss(animated: true, completion: nil)
    }
    
    open func preload() {
        _ = self.view // force webview loading
    }
    
    open func refresh() {
        let request = URLRequest(url: indexUrl)
        _ = webView?.load(request)
    }
    
    // MARK: - navigation delegate
    
    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        //MARK (losh11): - improve code which closes webView
        if let url = navigationAction.request.url?.absoluteString{
            let mutableurl = url
            if mutableurl.contains("/close") {
                DispatchQueue.main.async {
                    let request = URLRequest(url: URL(string: "https://api.loafwallet.org/support")!)
                    _ = webView.load(request)
                    self.closeNow()
                }
            }
        }
        
        return decisionHandler(.allow)
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
