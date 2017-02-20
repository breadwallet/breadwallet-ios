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
    private let pinPad = PinPadViewController(style: .clear, keyboardType: .pinPad)
    private let pinViewContainer = UIView()
    private let pinView = PinView(style: .login)
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
    private var pinPadPottom: NSLayoutConstraint?
    private var topControlTop: NSLayoutConstraint?
    private var unlockTimer: Timer?

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        addTouchIdButton()
        addPinPadCallback()
        topControl.addTarget(self, action: #selector(topControlChanged(control:)), for: .valueChanged)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if walletManager.canUseTouchID && !walletManager.pinLoginRequired {
            touchIdTapped()
        }
        lockIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unlockTimer?.invalidate()
    }

    private func addSubviews() {
        view.addSubview(backgroundView)
        view.addSubview(pinViewContainer)
        pinViewContainer.addSubview(pinView)
        view.addSubview(topControl)
        view.addSubview(header)
        view.addSubview(subheader)
    }

    private func addConstraints() {
        backgroundView.constrain(toSuperviewEdges: nil)
        addChildViewController(pinPad, layout: {
            pinPadPottom = pinPad.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            pinPad.view.constrain([
                pinPad.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                pinPad.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                pinPadPottom,
                pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height) ])
        })
        pinViewContainer.constrain(toSuperviewEdges: nil)
        pinView.constrain([
            pinView.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -95.0),
            pinView.centerXAnchor.constraint(equalTo: pinViewContainer.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
        topControlTop = topControl.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[1])
        topControl.constrain([
            topControlTop,
            topControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            topControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            topControl.heightAnchor.constraint(equalToConstant: topControlHeight) ])
        subheader.constrain([
            subheader.bottomAnchor.constraint(equalTo: pinView.topAnchor, constant: -C.padding[1]),
            subheader.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        header.constrain([
            header.topAnchor.constraint(equalTo: topControl.bottomAnchor, constant: C.padding[6]),
            header.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        subheader.text = S.LoginScreen.subheader
        header.text = S.LoginScreen.header
        header.textColor = .white
    }

    private func addTouchIdButton() {
        guard walletManager.canUseTouchID && !walletManager.pinLoginRequired else { return }
        view.addSubview(touchId)
        touchId.addTarget(self, action: #selector(touchIdTapped), for: .touchUpInside)
        touchId.constrain([
            touchId.widthAnchor.constraint(equalToConstant: touchIdSize),
            touchId.heightAnchor.constraint(equalToConstant: touchIdSize),
            touchId.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            touchId.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[2]) ])
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
        guard walletManager.authenticate(pin: pin) else { return authenticationFailed() }
        authenticationSucceded()
    }

    private func authenticationSucceded() {
        let label = UILabel(font: subheader.font)
        label.textColor = .white
        label.text = S.LoginScreen.unlocked
        label.alpha = 0.0
        let lock = UIImageView(image: #imageLiteral(resourceName: "unlock"))
        lock.alpha = 0.0

        view.addSubview(label)
        view.addSubview(lock)

        label.constrain([
            label.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -C.padding[1]),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        lock.constrain([
            lock.topAnchor.constraint(equalTo: label.bottomAnchor, constant: C.padding[1]),
            lock.centerXAnchor.constraint(equalTo: label.centerXAnchor) ])
        view.layoutIfNeeded()

        UIView.spring(0.6, animations: {
            self.pinPadPottom?.constant = self.pinPad.height
            self.topControlTop?.constant = -100.0
            lock.alpha = 1.0
            label.alpha = 1.0
            self.header.alpha = 0.0
            self.subheader.alpha = 0.0
            self.pinView.alpha = 0.0
            self.view.layoutIfNeeded()
        }) { completion in
            self.store.perform(action: LoginSuccess())
        }
    }

    private func authenticationFailed() {
        pinView.shake()
        pinPad.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + pinView.shakeDuration) { [weak self] in
            self?.pinView.fill(0)
            self?.lockIfNeeded()
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

    private func lockIfNeeded() {
        let disabledUntil = walletManager.walletDisabledUntil
        if disabledUntil > Date.timeIntervalSinceReferenceDate {
            let disabledUntilDate = Date(timeIntervalSinceReferenceDate: disabledUntil)
            let df = DateFormatter()
            df.dateFormat = "h:mm a 'on' MMM d, yyy"
            subheader.text = "Disabled until: \(df.string(from: disabledUntilDate))"
            pinPad.view.isUserInteractionEnabled = false

            let unlockInterval = disabledUntil - Date.timeIntervalSinceReferenceDate
            unlockTimer?.invalidate()
            unlockTimer = Timer.scheduledTimer(timeInterval: unlockInterval, target: self, selector: #selector(LoginViewController.unlock), userInfo: nil, repeats: false)
        } else {
            subheader.text = S.LoginScreen.subheader
            pinPad.view.isUserInteractionEnabled = true
        }
    }

    @objc private func unlock() {
        subheader.pushNewText(S.LoginScreen.subheader)
        pinPad.view.isUserInteractionEnabled = true
        unlockTimer = nil
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
