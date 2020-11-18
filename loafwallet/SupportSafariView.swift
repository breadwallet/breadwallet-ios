//
//  SupportSafariView.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/13/20.
//  Copyright © 2020 Litecoin Foundation. All rights reserved.
//

import SwiftUI
import WebKit

/// Customized version of Embedded WKWebView
struct SupportSafariView: UIViewRepresentable {
     
    //MARK: - Combine Variables
    @ObservedObject
    var viewModel: SupportSafariViewModel
    
    //MARK: - Public Variables
    let url: URL
    var wkWebView = WKWebView()
     
    init(url: URL, viewModel: SupportSafariViewModel) {
        self.viewModel = viewModel
        self.url = url
    }
    
    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: SupportSafariView
        private var wkWebView: WKWebView
        
        init(_ parent: SupportSafariView) {
             self.parent = parent
             self.wkWebView = self.parent.wkWebView
         }
        
        /// WKNavigationDelegate Method
        /// - Parameters:
        ///   - webView: Embedded webView
        ///   - navigation: nil
        func webView(_ webView: WKWebView,
                     didFinish navigation: WKNavigation!) {
            
            // MARK: - Parse LF LTC Address
            webView.evaluateJavaScript("document.documentElement.outerHTML.toString()",
                                       completionHandler: { ( htmlString: Any, error: Error?) in
                                            if let string = htmlString as? String,
                                               let suffix = string.components(separatedBy:"<a href=").last {
                                               let content = suffix.components(separatedBy:">")
                                               let element = content.filter{ $0.contains("</a")}.first
                                                
                                                if ((element?.contains(FoundationSupport.supportLTCAddress)) != nil) {
                                                    UIPasteboard.general.string = FoundationSupport.supportLTCAddress
                                                    self.parent.viewModel.supportLTCAddress = FoundationSupport.supportLTCAddress
                                                } else {
                                                    print("ERROR: Incorrect LTC Address")
                                                }
                                            }
            })
        }
    }
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView(frame: .zero)
    }
    
    func updateUIView(_ view: WKWebView, context: Context) {
        
        /// Sets the delegates and lets coordinator fire delegate actions
        view.uiDelegate = context.coordinator
        view.navigationDelegate = context.coordinator
        
        view.load(URLRequest(url: self.url))
    }
     
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func reload(){
        wkWebView.reload()
    }

}

struct GenericSafariView_Previews: PreviewProvider {
    static let viewModel = SupportSafariViewModel()
    static var previews: some View {
        SupportSafariView(url: FoundationSupport.url, viewModel: viewModel)
    }
}
