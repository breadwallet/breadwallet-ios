//
//  BuyCenterWebViewController.swift
//  breadwallet
//
//  Created by Kerry Washington on 10/1/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import WebKit

class BuyCenterWebViewController : UIViewController {
  
  var webView: WKWebView!
  
  
  override func loadView() {
    let webConfiguration = WKWebViewConfiguration()
    webView = WKWebView(frame: .zero, configuration: webConfiguration)
    webView.navigationDelegate = self
    view = webView
    
    self.navigationController?.setNavigationBarHidden(false, animated: true)
    let backButton = UIBarButtonItem(image: #imageLiteral(resourceName: "Close"), style: .plain, target: self, action:#selector(BuyCenterWebViewController.dismissWebView))
    navigationController?.navigationItem.leftBarButtonItem = backButton
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    localHtml(resource: "bitrefill_index")
  }
  
  private func localHtml(resource: String) {
    if let filepath = Bundle.main.path(forResource: resource, ofType: "html") {
      do {
        let contents = try String(contentsOfFile: filepath)
        let url = URL(fileURLWithPath: contents)
        let request = URLRequest(url: url)
        print("FILE ++++++++++++%@",request)
        webView.load(request)
        
      } catch {
        // contents could not be loaded
      }
    } else {
      // example.txt not found!
    }
  }
  
  @objc func dismissWebView() {
    dismiss(animated: true) {
      //
    }
  }
  
  
}

extension BuyCenterWebViewController : WKNavigationDelegate {
  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    
  }
  
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // Refreshing the content in case of editing...
  }
  
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
  }
}
