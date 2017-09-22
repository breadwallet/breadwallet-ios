//
//  BRBrowserViewController.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 6/23/17.
//  Copyright © 2017 Aaron Voisine. All rights reserved.
//

import Foundation
import UIKit
import WebKit

@available(iOS 8.0, *)
fileprivate class BRBrowserViewControllerInternal: UIViewController, WKNavigationDelegate {
    var didMakePostRequest = false
    var request: URLRequest? {
        didSet {
            didMakePostRequest = false
        }
    }
    var didCallLoadRequest = false
    var closeOnURL: URL?
    var onClose: (() -> Void)?
    
    let webView = WKWebView()
    let toolbarContainerView = UIView()
    let toolbarView = UIToolbar()
    let progressView = UIProgressView()
    let refreshButtonItem = UIBarButtonItem(
        barButtonSystemItem: UIBarButtonSystemItem.refresh, target: self,
        action: #selector(BRBrowserViewControllerInternal.refresh))
    var stopButtonItem = UIBarButtonItem(
        barButtonSystemItem: UIBarButtonSystemItem.stop, target: self,
        action: #selector(BRBrowserViewControllerInternal.stop))
    var flexibleSpace = UIBarButtonItem(
        barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
    var backButtonItem = UIBarButtonItem(
        title: "\u{25C0}\u{FE0E}", style: UIBarButtonItemStyle.plain, target: self,
        action: #selector(BRBrowserViewControllerInternal.goBack))
    var forwardButtonItem = UIBarButtonItem(
        title: "\u{25B6}\u{FE0E}", style: UIBarButtonItemStyle.plain, target: self,
        action: #selector(BRBrowserViewControllerInternal.goForward))
    
    open override var edgesForExtendedLayout: UIRectEdge {
        get {
            return UIRectEdge(rawValue: super.edgesForExtendedLayout.rawValue ^ UIRectEdge.bottom.rawValue)
        }
        set {
            super.edgesForExtendedLayout = newValue
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        // progress view
        progressView.alpha = 0
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "|-0-[progressView]-0-|", options: [], metrics: nil,
            views: ["progressView": progressView]))
        view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|[topGuide]-0-[progressView(2)]", options: [], metrics: nil,
            views: ["progressView": progressView, "topGuide": self.topLayoutGuide]))
        
        // toolbar view
        view.addSubview(toolbarContainerView)
        self.view.addSubview(toolbarContainerView)
        self.view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "|-0-[toolbarContainer]-0-|", options: [], metrics: nil,
            views: ["toolbarContainer": toolbarContainerView]))
        self.view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:[toolbarContainer]-0-|", options: [], metrics: nil,
            views: ["toolbarContainer": toolbarContainerView]))
        toolbarContainerView.addConstraint(NSLayoutConstraint(
            item: toolbarContainerView, attribute: .height, relatedBy: .equal, toItem: nil,
            attribute: .notAnAttribute, multiplier: 1, constant: 44))
        
        toolbarView.isTranslucent = true
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.items = [backButtonItem, forwardButtonItem, flexibleSpace, refreshButtonItem]
        toolbarContainerView.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainerView.addSubview(toolbarView)
        toolbarContainerView.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "|-0-[toolbar]-0-|", options: [], metrics: nil, views: ["toolbar": toolbarView]))
        toolbarContainerView.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|-0-[toolbar]-0-|", options: [], metrics: nil, views: ["toolbar": toolbarView]))
        
        // webview
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "|-0-[webView]-0-|", options: [], metrics: nil,
            views: ["webView": webView as WKWebView]))
        view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|[topGuide]-0-[webView]-0-[toolbarContainer]|", options: [], metrics: nil,
            views: ["webView": webView, "toolbarContainer": toolbarContainerView, "topGuide": self.topLayoutGuide]))
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "loading", options: .new, context: nil)
        print("[BRBrowserViewController viewWillAppear request = \(String(describing: request))")
        if let request = request, !didCallLoadRequest {
            // this is part one of loading a POST request. since WKWebView will loose the POST body upon calling
            // load(request:) we have to instead load a custom HTML file with a javascript function that will allow
            // submit the form on behalf of the browser's request object. this is effectually performing a link 'bounce'
            // step one is to load the html file. step two can be found below in the didNavigate method
            if request.httpMethod?.uppercased() == "POST" {
                guard let path = Bundle.main.path(forResource: "POSTBouncer", ofType: "html") else {
                    print("[BRBrowserViewController] error building path for POSTBouncer resource")
                    return
                }
                guard let htmlString = try? String(contentsOfFile: path) else {
                    print("[BRBrowserViewController] error loading html for POSTBouncer path")
                    return
                }
                webView.loadHTMLString(htmlString, baseURL: Bundle.main.bundleURL)
            } else {
                _ = webView.load(request)
            }
            didCallLoadRequest = true
        }
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        webView.removeObserver(self, forKeyPath: "estimatedProgress")
        webView.removeObserver(self, forKeyPath: "title")
        webView.removeObserver(self, forKeyPath: "loading")
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                    change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        switch keyPath {
        case "estimatedProgress":
            if let newValue = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                progressChanged(newValue)
            }
        case "title":
            print("[BRBrowserViewController] title changed \(String(describing: webView.title))")
            self.navigationItem.title = webView.title
        case "loading":
            if let val = change?[NSKeyValueChangeKey.newKey] as? Bool {
                print("[BRBrowserViewController] loading changed \(val)")
                if !val {
                    showLoading(false)
                    backForwardListsChanged()
                }
            }
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func progressChanged(_ newValue: NSNumber) {
        print("[BRBrowserViewController] progress changed new value = \(newValue)")
        progressView.progress = newValue.floatValue
        if progressView.progress == 1 {
            progressView.progress = 0
            UIView.animate(withDuration: 0.2, animations: {
                self.progressView.alpha = 0
            })
        } else if progressView.alpha == 0 {
            UIView.animate(withDuration: 0.2, animations: {
                self.progressView.alpha = 1
            })
        }
    }
    
    func showLoading(_ isLoading: Bool) {
        print("[BRBrowserViewController] showLoading \(isLoading)")
        if isLoading {
            self.toolbarView.items = [backButtonItem, forwardButtonItem, flexibleSpace, stopButtonItem];
        } else {
            self.toolbarView.items = [backButtonItem, forwardButtonItem, flexibleSpace, refreshButtonItem];
        }
    }
    
    func showError(_ errString: String) {
        let alertView = UIAlertController(title: "Error", message: errString, preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertView, animated: true, completion: nil)
    }
    
    func backForwardListsChanged() {
        // enable forward/back buttons
        backButtonItem.isEnabled = webView.canGoBack
        forwardButtonItem.isEnabled = webView.canGoForward
    }
    
    @objc func goBack() {
        print("[BRBrowserViewController] go back")
        webView.goBack()
    }
    
    @objc func goForward() {
        print("[BRBrowserViewController] go forward")
        webView.goForward()
    }
    
    @objc func refresh() {
        print("[BRBrowserViewController] go refresh")
        webView.reload()
    }
    
    @objc func stop() {
        print("[BRBrowserViewController] stop loading")
        webView.stopLoading()
    }
    
    // MARK: - WKNavigationDelegate
    open func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("[BRBrowserViewController] webView didCommit navigation = \(navigation)")
    }
    
    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[BRBrowserViewController] webView didFinish navigation = \(navigation)")
        // this is part two of executing a POST request when loading the initial request 
        // since WKWebView looses the POST body when calling load(request:) we have to use our
        // custom POST bouncer, an html file with a javascript function called `post(url:,body:)` 
        // which takes the url to POST to and the HTML form body to post as a json object
        // each key will become a hidden form value
        if let request = request, request.httpMethod == "POST" && !didMakePostRequest {
            guard let reqData = request.httpBody?.urlEncodedObject?.flattened else {
                print("[BRBrowserViewController] could not read POST data. are you sure it's a x-www-url-encoded body?")
                return
            }
            let jsCall = "post(\"\(request.url?.description ?? "")\", \(reqData.jsonString))"
            webView.evaluateJavaScript(jsCall, completionHandler: { (ret, err) in
                self.didMakePostRequest = true
                print("[BRBrowserViewController] evaluated javascript POST bouncer. ret=\(String(describing: ret)) err=\(String(describing: err))")
            })
        } else {
            if let onClose = onClose, closeOnURLsMatch(webView.url) {
                onClose()
            }
        }
    }
    
    open func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print("[BRBrowserViewController] webViewContentProcessDidTerminate")
    }
    
    open func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[BRBrowserViewController] webView didFail navigation = \(navigation) error = \(error)")
        showLoading(false)
        showError(error.localizedDescription)
    }
    
    open func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                      withError error: Error) {
        print("[BRBrowserViewController] webView didFailProvisionalNavigation navigation = \(navigation) error = \(error)")
        showLoading(false)
        showError(error.localizedDescription)
    }
    
    func closeOnURLsMatch(_ toURL: URL?) -> Bool {
        print("[BRBrowserViewController] closeOnURLsMatch(toURL:\(String(describing: toURL))")
        guard let closeOnURL = closeOnURL, let toURL = toURL else {
            return false
        }
        if closeOnURL.scheme == toURL.scheme && closeOnURL.host == toURL.host
            && closeOnURL.absoluteString.rtrim(["/"]) == toURL.absoluteString.rtrim(["/"]) {
            return true
        }
        return false
    }
    
    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if closeOnURLsMatch(navigationAction.request.url) {
            if let onClose = onClose { onClose() }
            decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }
    
    open func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("[BRBrowserViewController] webView didStartProfisionalNavigation navigation = \(navigation)")
        showLoading(true)
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if self.presentedViewController == nil { return }
        super.dismiss(animated: flag, completion: completion)
    }
}

@available(iOS 8.0, *)
open class BRBrowserViewController: UINavigationController {
    var onDone: (() -> Void)?
    var isClosing = false
    var closeOnURL: String {
        get {
            return browser.closeOnURL == nil ? "" : "\(browser.closeOnURL!)"
        }
        set {
            browser.closeOnURL = URL(string: newValue)
        }
    }
    
    fileprivate let browser = BRBrowserViewControllerInternal()
    
    init() {
        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
        browser.onClose = { self.done(nil) }
        self.viewControllers = [browser]
        browser.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(BRBrowserViewController.done))
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    func load(_ request: URLRequest) {
        print("[BRBrowserViewController] load request = \(request)")
        browser.request = request
    }
    
    @objc private func done(_ control: UIControl?) {
        print("[BRBrowserViewController] done")
        isClosing = true
        self.dismiss(animated: true) {
            if let onDone = self.onDone {
                onDone()
            }
        }
    }
    
    override open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if self.presentedViewController == nil && !isClosing { return }
        isClosing = false
        super.dismiss(animated: flag, completion: completion)
    }
}

