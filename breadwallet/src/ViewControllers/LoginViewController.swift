//
//  LoginViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-19.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class LoginViewController : UIViewController {

    //MARK: - Public
    init(store: Store, walletManager: WalletManager) {
        self.store = store
        self.walletManager = walletManager
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let store: Store
    private let walletManager: WalletManager
    private let backgroundView = LoginBackgroundView()
    private let textField = UITextField()
    private let pinPad = PinPadViewController(style: .clear)
    private let pinView = PinView()

    override func viewDidLoad() {
        view.addSubview(backgroundView)
        backgroundView.constrain(toSuperviewEdges: nil)

        addChildViewController(pinPad, layout: {
            pinPad.view.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
            pinPad.view.constrain([
                pinPad.view.heightAnchor.constraint(equalToConstant: PinPadViewController.height) ])
        })

        backgroundView.addSubview(pinView)
        pinView.constrain([
            pinView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            pinView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.defaultWidth + C.padding[1]*6),
            pinView.heightAnchor.constraint(equalToConstant: pinView.defaultPinSize) ])

        pinPad.ouputDidUpdate = { pin in
            let length = pin.lengthOfBytes(using: .utf8)
            self.pinView.fill(length)
            self.pinPad.isAppendingDisabled = length < 6 ? false : true
            if length == 6 {
                self.authenticate(pin: pin)
            }
        }
    }

    private func authenticate(pin: String) {
        let isAuthenticated = self.walletManager.authenticate(pin: pin)
        if isAuthenticated {
            store.perform(action: LoginSuccess())
        } else {
            self.pinView.shake()
            self.pinPad.clear()
            DispatchQueue.main.asyncAfter(deadline: .now() + pinView.shakeDuration) { [weak self] in
                self?.pinView.fill(0)
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
