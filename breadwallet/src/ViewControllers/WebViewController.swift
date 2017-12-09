//
//  WebViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import WebKit

class WebViewController : UIViewController {

    var didComplete: (() -> Void)?
    private var webView: WKWebView
    private var url: URL

    init(url: URL) {
        self.url = url
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    }

    @objc private func cancel() {
        dismiss(animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension WebViewController : WKNavigationDelegate {

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
