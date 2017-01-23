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
    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let store: Store
    private let backgroundView = LoginBackgroundView()
    private let textField = UITextField()
    private let pinPad = PinPadViewController()
    private let pinView = PinView()

    override func viewDidLoad() {
        view.addSubview(backgroundView)
        backgroundView.constrain(toSuperviewEdges: nil)

        addChildViewController(pinPad, layout: {
            pinPad.view.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
            pinPad.view.constrain([
                pinPad.view.heightAnchor.constraint(equalToConstant: 216.0) ])
        })

        view.addSubview(pinView)
        pinView.constrain([
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.defaultWidth),
            pinView.heightAnchor.constraint(equalToConstant: pinView.defaultPinSize) ])

        pinPad.ouputDidUpdate = { pin in
            let length = pin.lengthOfBytes(using: .utf8)
            self.pinView.fill(length)
            self.pinPad.isAppendingDisabled = length < 6 ? false : true
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
