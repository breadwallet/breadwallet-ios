//
//  LoginViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-19.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

private let touchIdSize: CGFloat = 32.0
private let topControlHeight: CGFloat = 32.0

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
    private let pinPad = PinPadViewController(style: .clear, keyboardType: .pinPad)
    private let pinView = PinView(style: .white)
    private let topControl: UISegmentedControl = {
        let control = UISegmentedControl(items: [S.LoginScreen.myAddress, S.LoginScreen.scan])
        control.tintColor = .white
        control.isMomentary = true
        control.setTitleTextAttributes([NSFontAttributeName: UIFont.customMedium(size: 13.0)], for: .normal)
        return control
    }()
    private let touchId: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.setImage(#imageLiteral(resourceName: "TouchId"), for: .normal)
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = touchIdSize/2.0
        button.layer.masksToBounds = true
        button.accessibilityLabel = S.LoginScreen.touchIdText
        return button
    }()
    private let header = UILabel(font: .systemFont(ofSize: 40.0))
    private let subheader = UILabel(font: .customBody(size: 16.0))

    override func viewDidLoad() {
        view.addSubview(backgroundView)
        backgroundView.constrain(toSuperviewEdges: nil)

        addChildViewController(pinPad, layout: {
            pinPad.view.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
            pinPad.view.constrain([
                pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height) ])
        })

        backgroundView.addSubview(pinView)
        pinView.constrain([
            pinView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            pinView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.defaultWidth + C.padding[1]*6),
            pinView.heightAnchor.constraint(equalToConstant: pinView.defaultPinSize) ])

        view.addSubview(topControl)
        topControl.addTarget(self, action: #selector(topControlChanged(control:)), for: .valueChanged)
        topControl.constrainTopCorners(sidePadding: C.padding[2], topPadding: C.padding[2], topLayoutGuide: topLayoutGuide)
        topControl.constrain([
            topControl.heightAnchor.constraint(equalToConstant: topControlHeight) ])

        view.addSubview(header)
        view.addSubview(subheader)
        subheader.constrain([
            subheader.bottomAnchor.constraint(equalTo: pinView.topAnchor, constant: -C.padding[2]),
            subheader.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        header.constrain([
            header.bottomAnchor.constraint(equalTo: subheader.topAnchor, constant: -C.padding[4]),
            header.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        subheader.text = S.LoginScreen.subheader
        header.text = S.LoginScreen.header
        header.textColor = .white

        addTouchIdButton()
        addPinPadCallback()
    }

    private func addTouchIdButton() {
        if walletManager.canUseTouchID() {
            view.addSubview(touchId)
            touchId.addTarget(self, action: #selector(touchIdTapped), for: .touchUpInside)
            touchId.constrain([
                touchId.widthAnchor.constraint(equalToConstant: touchIdSize),
                touchId.heightAnchor.constraint(equalToConstant: touchIdSize),
                touchId.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
                touchId.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[2]) ])
        }
    }

    private func addPinPadCallback() {
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

    @objc private func topControlChanged(control: UISegmentedControl) {
        if control.selectedSegmentIndex == 0 {
            addressTapped()
        } else if control.selectedSegmentIndex == 1 {
            scanTapped()
        }
    }

    private func addressTapped() {

    }

    private func scanTapped() {

    }

    @objc func touchIdTapped() {
        walletManager.authenticate(touchIDPrompt: S.LoginScreen.touchIdPrompt, completion: { success in
            if success {
                self.store.perform(action: LoginSuccess())
            }
        })
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
