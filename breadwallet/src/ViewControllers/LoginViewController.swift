//
//  LoginViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-19.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

private let touchIdSize: CGFloat = 32.0
private let topControlHeight: CGFloat = 32.0

class LoginViewController : UIViewController, Subscriber, Trackable {

    //MARK: - Public
    var walletManager: WalletManager? {
        didSet {
            guard walletManager != nil else { return }
            pinView = PinView(style: .login, length: store.state.pinLength)
        }
    }
    var shouldSelfDismiss = false
    init(store: Store, isPresentedForLock: Bool, walletManager: WalletManager? = nil) {
        self.store = store
        self.walletManager = walletManager
        self.isPresentedForLock = isPresentedForLock
        self.disabledView = WalletDisabledView(store: store)
        if walletManager != nil {
            self.pinView = PinView(style: .login, length: store.state.pinLength)
        }
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        store.unsubscribe(self)
    }

    //MARK: - Private
    private let store: Store
    private let backgroundView = LoginBackgroundView()
    private let pinPad = PinPadViewController(style: .clear, keyboardType: .pinPad, maxDigits: 0)
    private let pinViewContainer = UIView()
    private var pinView: PinView?
    private let addressButton = SegmentedButton(title: S.UnlockScreen.myAddress, type: .left)
    private let scanButton = SegmentedButton(title: S.UnlockScreen.scan, type: .right)
    private let isPresentedForLock: Bool
    private let disabledView: WalletDisabledView
    private let activityView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)

    private var logo: UIImageView = {
        let image = UIImageView(image: #imageLiteral(resourceName: "Logo"))
        image.contentMode = .scaleAspectFit
        return image
    }()

    private let touchId: UIButton = {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.setImage(#imageLiteral(resourceName: "TouchId"), for: .normal)
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = touchIdSize/2.0
        button.layer.masksToBounds = true
        button.accessibilityLabel = S.UnlockScreen.touchIdText
        return button
    }()
    private let subheader = UILabel(font: .customBody(size: 16.0), color: .darkText)
    private var pinPadPottom: NSLayoutConstraint?
    private var topControlTop: NSLayoutConstraint?
    private var unlockTimer: Timer?
    private let pinPadBackground = GradientView()
    private let topControlContainer: UIView = {
        let view = UIView()
        view.layer.borderColor = UIColor.white.cgColor
        view.layer.borderWidth = 1.0
        view.layer.cornerRadius = 5.0
        view.layer.masksToBounds = true
        let separator = UIView()
        view.addSubview(separator)
        separator.backgroundColor = .white
        separator.constrain([
            separator.topAnchor.constraint(equalTo: view.topAnchor),
            separator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            separator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1.0) ])
        return view
    }()
    private var hasAttemptedToShowTouchId = false
    private let lockedOverlay = UIVisualEffectView()
    private var isResetting = false

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        addTouchIdButton()
        addPinPadCallback()
        if pinView != nil {
            addPinView()
        }
        disabledView.didTapReset = { [weak self] in
            guard let store = self?.store else { return }
            guard let walletManager = self?.walletManager else { return }
            self?.isResetting = true
            let nc = UINavigationController()
            let recover = EnterPhraseViewController(store: store, walletManager: walletManager, reason: .validateForResettingPin({ phrase in
                let updatePin = UpdatePinViewController(store: store, walletManager: walletManager, type: .creationWithPhrase, showsBackButton: false, phrase: phrase)
                nc.pushViewController(updatePin, animated: true)
                updatePin.resetFromDisabledWillSucceed = {
                    self?.disabledView.isHidden = true
                }
                updatePin.resetFromDisabledSuccess = {
                    self?.authenticationSucceded()
                }
            }))
            recover.addCloseNavigationItem()
            nc.viewControllers = [recover]
            nc.navigationBar.tintColor = .darkText
            nc.navigationBar.titleTextAttributes = [
                NSAttributedStringKey.foregroundColor: UIColor.darkText,
                NSAttributedStringKey.font: UIFont.customBold(size: 17.0)
            ]
            nc.setClearNavbar()
            nc.navigationBar.isTranslucent = false
            nc.navigationBar.barTintColor = .whiteTint
            nc.viewControllers = [recover]
            self?.present(nc, animated: true, completion: nil)
        }
        store.subscribe(self, name: .loginFromSend, callback: {_ in 
            self.authenticationSucceded()
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard UIApplication.shared.applicationState != .background else { return }
        if shouldUseTouchId && !hasAttemptedToShowTouchId && !isPresentedForLock && UserDefaults.hasShownWelcome {
            hasAttemptedToShowTouchId = true
            touchIdTapped()
        }
        if !isResetting {
            lockIfNeeded()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unlockTimer?.invalidate()
    }

    private func addPinView() {
        guard let pinView = pinView else { return }
        pinViewContainer.addSubview(pinView)
        view.addSubview(subheader)
        pinView.constrain([
            pinView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: E.isIPhone4 ? -C.padding[2] : 0.0),
            pinView.centerXAnchor.constraint(equalTo: pinViewContainer.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
        subheader.constrain([
            subheader.bottomAnchor.constraint(equalTo: pinView.topAnchor, constant: -C.padding[1]),
            subheader.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
    }

    private func addSubviews() {
        view.addSubview(backgroundView)
        view.addSubview(pinViewContainer)
        view.addSubview(topControlContainer)
        topControlContainer.addSubview(addressButton)
        topControlContainer.addSubview(scanButton)
        view.addSubview(logo)
        if walletManager != nil {
            view.addSubview(pinPadBackground)
        } else {
            view.addSubview(activityView)
        }
    }

    private func addConstraints() {
        backgroundView.constrain(toSuperviewEdges: nil)
        if walletManager != nil {
            addChildViewController(pinPad, layout: {
                pinPadPottom = pinPad.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                pinPad.view.constrain([
                    pinPad.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    pinPad.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    pinPadPottom,
                    pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height) ])
            })
        }
        pinViewContainer.constrain(toSuperviewEdges: nil)

        topControlTop = topControlContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[1] + 20.0)
        topControlContainer.constrain([
            topControlTop,
            topControlContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            topControlContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            topControlContainer.heightAnchor.constraint(equalToConstant: topControlHeight) ])
        addressButton.constrain([
            addressButton.leadingAnchor.constraint(equalTo: topControlContainer.leadingAnchor),
            addressButton.topAnchor.constraint(equalTo: topControlContainer.topAnchor),
            addressButton.trailingAnchor.constraint(equalTo: topControlContainer.centerXAnchor),
            addressButton.bottomAnchor.constraint(equalTo: topControlContainer.bottomAnchor) ])
        scanButton.constrain([
            scanButton.leadingAnchor.constraint(equalTo: topControlContainer.centerXAnchor),
            scanButton.topAnchor.constraint(equalTo: topControlContainer.topAnchor),
            scanButton.trailingAnchor.constraint(equalTo: topControlContainer.trailingAnchor),
            scanButton.bottomAnchor.constraint(equalTo: topControlContainer.bottomAnchor) ])

        logo.constrain([
            logo.topAnchor.constraint(equalTo: topControlContainer.bottomAnchor, constant: C.padding[8]),
            logo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logo.heightAnchor.constraint(equalTo: logo.widthAnchor, multiplier: C.Sizes.logoAspectRatio),
            logo.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.35) ])
        if walletManager != nil {
            pinPadBackground.constrain([
                pinPadBackground.leadingAnchor.constraint(equalTo: pinPad.view.leadingAnchor),
                pinPadBackground.trailingAnchor.constraint(equalTo: pinPad.view.trailingAnchor),
                pinPadBackground.topAnchor.constraint(equalTo: pinPad.view.topAnchor),
                pinPadBackground.bottomAnchor.constraint(equalTo: pinPad.view.bottomAnchor) ])
        } else {
            activityView.constrain([
                activityView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                activityView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20.0) ])
            activityView.startAnimating()
        }
        subheader.text = S.UnlockScreen.subheader

        addressButton.addTarget(self, action: #selector(addressTapped), for: .touchUpInside)
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
    }

    private func addTouchIdButton() {
        guard shouldUseTouchId else { return }
        view.addSubview(touchId)
        touchId.addTarget(self, action: #selector(touchIdTapped), for: .touchUpInside)
        touchId.constrain([
            touchId.widthAnchor.constraint(equalToConstant: touchIdSize),
            touchId.heightAnchor.constraint(equalToConstant: touchIdSize),
            touchId.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            touchId.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[2]) ])
    }

    private func addPinPadCallback() {
        pinPad.ouputDidUpdate = { [weak self] pin in
            guard let myself = self else { return }
            guard let pinView = self?.pinView else { return }
            let attemptLength = pin.utf8.count
            pinView.fill(attemptLength)
            self?.pinPad.isAppendingDisabled = attemptLength < myself.store.state.pinLength ? false : true
            if attemptLength == myself.store.state.pinLength {
                self?.authenticate(pin: pin)
            }
        }
    }

    private func authenticate(pin: String) {
        guard let walletManager = walletManager else { return }
        guard !E.isScreenshots else { return authenticationSucceded() }
        guard walletManager.authenticate(pin: pin) else { return authenticationFailed() }
        authenticationSucceded()
    }

    private func authenticationSucceded() {
        saveEvent("login.success")
        let label = UILabel(font: subheader.font)
        label.textColor = .white
        label.text = S.UnlockScreen.unlocked
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
            self.logo.alpha = 0.0
            self.subheader.alpha = 0.0
            self.pinView?.alpha = 0.0
            self.view.layoutIfNeeded()
        }) { completion in
            if self.shouldSelfDismiss {
                self.dismiss(animated: true, completion: nil)
            }
            self.store.perform(action: LoginSuccess())
            self.store.trigger(name: .showStatusBar)
        }
    }

    private func authenticationFailed() {
        saveEvent("login.failed")
        guard let pinView = pinView else { return }
        pinPad.view.isUserInteractionEnabled = false
        pinView.shake { [weak self] in
            self?.pinPad.view.isUserInteractionEnabled = true
        }
        pinPad.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + pinView.shakeDuration) { [weak self] in
            pinView.fill(0)
            self?.lockIfNeeded()
        }
    }

    private var shouldUseTouchId: Bool {
        guard let walletManager = self.walletManager else { return false }
        return LAContext.canUseTouchID && !walletManager.pinLoginRequired && store.state.isTouchIdEnabled
    }

    @objc func touchIdTapped() {
        guard !isWalletDisabled else { return }
        walletManager?.authenticate(touchIDPrompt: S.UnlockScreen.touchIdPrompt, completion: { result in
            if result == .success {
                self.authenticationSucceded()
            }
        })
    }

    @objc func addressTapped() {
        store.perform(action: RootModalActions.Present(modal: .loginAddress))
    }

    @objc func scanTapped() {
        store.perform(action: RootModalActions.Present(modal: .loginScan))
    }

    private func lockIfNeeded() {
        if let disabledUntil = walletManager?.walletDisabledUntil {
            let now = Date.timeIntervalSinceReferenceDate
            if disabledUntil > now {
                saveEvent("login.locked")
                let disabledUntilDate = Date(timeIntervalSinceReferenceDate: disabledUntil)
                let unlockInterval = disabledUntil - Date.timeIntervalSinceReferenceDate
                let df = DateFormatter()
                df.setLocalizedDateFormatFromTemplate(unlockInterval > C.secondsInDay ? "h:mm:ss a MMM d, yyy" : "h:mm:ss a")

                disabledView.setTimeLabel(string: String(format: S.UnlockScreen.disabled, df.string(from: disabledUntilDate)))

                pinPad.view.isUserInteractionEnabled = false
                unlockTimer?.invalidate()
                unlockTimer = Timer.scheduledTimer(timeInterval: unlockInterval, target: self, selector: #selector(LoginViewController.unlock), userInfo: nil, repeats: false)

                if disabledView.superview == nil {
                    view.addSubview(disabledView)
                    setNeedsStatusBarAppearanceUpdate()
                    disabledView.constrain(toSuperviewEdges: nil)
                    disabledView.show()
                }
            } else {
                pinPad.view.isUserInteractionEnabled = true
                disabledView.hide { [weak self] in
                    self?.disabledView.removeFromSuperview()
                    self?.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }

    private var isWalletDisabled: Bool {
        guard let walletManager = walletManager else { return false }
        let now = Date.timeIntervalSinceReferenceDate
        return walletManager.walletDisabledUntil > now
    }

    @objc private func unlock() {
        saveEvent("login.unlocked")
        subheader.pushNewText(S.UnlockScreen.subheader)
        pinPad.view.isUserInteractionEnabled = true
        unlockTimer = nil
        disabledView.hide { [weak self] in
            self?.disabledView.removeFromSuperview()
            self?.setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if disabledView.superview == nil {
            return .lightContent
        } else {
            return .default
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
