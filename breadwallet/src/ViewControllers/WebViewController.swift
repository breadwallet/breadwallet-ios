//
//  WebViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import WebKit

enum WebViewStyle {
    case legal
    case regular
}

class WebViewController : UIViewController {

    var didComplete: (() -> Void)?
    private var webView: WKWebView
    private var url: URL
    private var style: WebViewStyle

    init(url: URL, style: WebViewStyle) {
        self.url = url
        self.style = style
        let webConfiguration = WKWebViewConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: webConfiguration)
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        webView.navigationDelegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let myRequest = URLRequest(url: url)
        webView.load(myRequest)
        if style == .regular {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: S.Crowdsale.decline, style: .plain, target: self, action: #selector(cancel))
        }
    }

    @objc private func cancel() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func agree() {
        self.didComplete?()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension WebViewController : WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if style == .legal {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: S.Crowdsale.agree, style: .plain, target: self, action: #selector(agree))
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.description {
            if url.contains("kyc-success") {
                didComplete?()
                return dismiss(animated: true, completion: {
                    decisionHandler(.cancel)
                })
            }
        }
        decisionHandler(.allow)
    }

}
