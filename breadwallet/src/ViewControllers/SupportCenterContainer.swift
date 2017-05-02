//
//  SupportCenterContainer.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class SupportCenterContainer : UIViewController {

    func navigate(to: String) {
        webView.navigate(to: to)
    }

    init(walletManager: WalletManager) {
        let mountPoint = "/support"
        #if Debug || Testflight
            webView = BRWebViewController(bundleName: "bread-support-staging", mountPoint: mountPoint, walletManager: walletManager)
        #else
            webView = BRWebViewController(bundleName: "bread-support", mountPoint: mountPoint, walletManager: walletManager)
        #endif
        webView.startServer()
        webView.preload()
        super.init(nibName: nil, bundle: nil)
    }

    private let webView: BRWebViewController
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .light))

    override func viewDidLoad() {
        view.backgroundColor = .clear
        view.addSubview(blur)
        blur.constrain(toSuperviewEdges: nil)
        addChildViewController(webView, layout: {
            webView.view.constrain([
                webView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.view.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
                webView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webView.view.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor) ])
        })
        addTopCorners()
    }

    private func addTopCorners() {
        let path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 6.0, height: 6.0)).cgPath
        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        webView.view.layer.mask = maskLayer
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
