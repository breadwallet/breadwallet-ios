//
//  LoginViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-19.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import LocalAuthentication
import BRCrypto
import MachO

private let topControlHeight: CGFloat = 32.0

class LoginViewController: UIViewController, Subscriber, Trackable {

    enum Context {
        case initialLaunch(loginHandler: LoginCompletionHandler)
        case automaticLock
        case manualLock

        var shouldAttemptBiometricUnlock: Bool {
            switch self {
            case .manualLock:
                return false
            default:
                return true
            }
        }
    }

    init(for context: Context, keyMaster: KeyMaster) {
        self.context = context
        self.keyMaster = keyMaster
        self.disabledView = WalletDisabledView()
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        Store.unsubscribe(self)
        notificationObservers.values.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Private
    private let keyMaster: KeyMaster
    private let backgroundView = UIView()
    private let pinViewContainer = UIView()
    private lazy var pinPad: PinPadViewController = {
        return PinPadViewController(style: .clear, keyboardType: .pinPad, maxDigits: 0, shouldShowBiometrics: shouldUseBiometrics)
    }()
    private lazy var pinView: PinView = {
        return PinView(style: .login, length: Store.state.pinLength)
    }()
    private let disabledView: WalletDisabledView
    private var logo = UIImageView(image: #imageLiteral(resourceName: "LogoCutout").withRenderingMode(.alwaysTemplate))
    private var pinPadPottom: NSLayoutConstraint?
    private var topControlTop: NSLayoutConstraint?
    private var unlockTimer: Timer?
    private let pinPadBackground = MotionGradientView()
    private let logoBackground = MotionGradientView()
    private var hasAttemptedToShowBiometrics = false
    private let lockedOverlay = UIVisualEffectView()
    private var isResetting = false
    private let context: Context
    private var notificationObservers = [String: NSObjectProtocol]()
    
    var isBiometricsEnabledForUnlocking: Bool {
        return self.keyMaster.isBiometricsEnabledForUnlocking
    }
    
    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        addPinPadCallbacks()
        addPinView()

        disabledView.didTapReset = { [weak self] in
            guard let `self` = self else { return }
            self.isResetting = true
            
            RecoveryKeyFlowController.enterResetPinFlow(from: self,
                                                        keyMaster: self.keyMaster,
                                                        callback: { (phrase, navController) in
                                                            let updatePin = UpdatePinViewController(keyMaster: self.keyMaster,
                                                                                                    type: .creationWithPhrase,
                                                                                                    showsBackButton: false,
                                                                                                    phrase: phrase)
                                                            
                                                            navController.pushViewController(updatePin, animated: true)
                                                            
                                                            updatePin.resetFromDisabledWillSucceed = {
                                                                self.disabledView.isHidden = true
                                                            }
                                                            
                                                            updatePin.resetFromDisabledSuccess = { pin in
                                                                if case .initialLaunch = self.context {
                                                                    guard let account = self.keyMaster.createAccount(withPin: pin) else { return assertionFailure() }
                                                                    self.authenticationSucceded(forLoginWithAccount: account)
                                                                } else {
                                                                    self.authenticationSucceded()
                                                                }
                                                            }
            })            
        }
        logo.tintColor = .darkBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard UIApplication.shared.applicationState != .background else { return }

        if shouldUseBiometrics && !hasAttemptedToShowBiometrics && context.shouldAttemptBiometricUnlock {
            hasAttemptedToShowBiometrics = true
            biometricsTapped()
        }
        if !isResetting {
            lockIfNeeded()
        }
        
        // detect jailbreak so we can throw up an idiot warning, in viewDidLoad so it can't easily be swizzled out
        if !E.isSimulator {
            var s = stat()
            var isJailbroken = (stat("/bin/sh", &s) == 0) ? true : false
            for i in 0..<_dyld_image_count() {
                guard !isJailbroken else { break }
                // some anti-jailbreak detection tools re-sandbox apps, so do a secondary check for any MobileSubstrate dyld images
                if strstr(_dyld_get_image_name(i), "MobileSubstrate") != nil {
                    isJailbroken = true
                }
            }
            notificationObservers[UIApplication.willEnterForegroundNotification.rawValue] =
                NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in
                    self.showJailbreakWarnings(isJailbroken: isJailbroken)
            }
            showJailbreakWarnings(isJailbroken: isJailbroken)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unlockTimer?.invalidate()
    }

    private func addPinView() {
        pinViewContainer.addSubview(pinView)
        pinView.constrain([
            pinView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: E.isIPhone4 ? -C.padding[2] : 0.0),
            pinView.centerXAnchor.constraint(equalTo: pinViewContainer.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
    }

    private func addSubviews() {
        view.addSubview(backgroundView)
        view.addSubview(pinViewContainer)
        view.addSubview(logoBackground)
        logoBackground.addSubview(logo)
        view.addSubview(pinPadBackground)
    }

    private func addConstraints() {
        backgroundView.constrain(toSuperviewEdges: nil)
        backgroundView.backgroundColor = Theme.primaryBackground
        pinViewContainer.constrain(toSuperviewEdges: nil)
        topControlTop = logoBackground.topAnchor.constraint(equalTo: view.topAnchor,
                                                            constant: C.Sizes.brdLogoHeight + C.Sizes.brdLogoTopMargin)
        logoBackground.constrain([
            topControlTop,
            logoBackground.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoBackground.heightAnchor.constraint(equalTo: logoBackground.widthAnchor, multiplier: logo.image!.size.height/logo.image!.size.width),
            logoBackground.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45) ])
        logo.constrain(toSuperviewEdges: nil)

        pinPadPottom = pinPadBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneX ? -C.padding[3] : 0.0)
        pinPadBackground.constrain([
            pinPadBackground.widthAnchor.constraint(equalToConstant: floor(UIScreen.main.safeWidth/3.0)*3.0),
            pinPadBackground.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinPadBackground.heightAnchor.constraint(equalToConstant: pinPad.height),
            pinPadPottom ])
        addChild(pinPad)
        pinPadBackground.addSubview(pinPad.view)
        pinPad.view.constrain(toSuperviewEdges: nil)
        pinPad.didMove(toParent: self)
    }

    private func addPinPadCallbacks() {
        pinPad.didTapBiometrics = { [weak self] in
            self?.biometricsTapped()
        }
        pinPad.ouputDidUpdate = { [weak self] pin in
            guard let pinView = self?.pinView else { return }
            let attemptLength = pin.utf8.count
            pinView.fill(attemptLength)
            self?.pinPad.isAppendingDisabled = attemptLength < Store.state.pinLength ? false : true
            if attemptLength == Store.state.pinLength {
                self?.authenticate(withPin: pin)
            }
        }
    }

    private func authenticate(withPin pin: String) {
        guard !E.isScreenshots else { return authenticationSucceded() }
        if case .initialLaunch = context {
            guard let account = keyMaster.createAccount(withPin: pin) else { return authenticationFailed() }
            authenticationSucceded(forLoginWithAccount: account)
        } else {
            guard keyMaster.authenticate(withPin: pin) else { return authenticationFailed() }
            authenticationSucceded()
        }
    }

    private func authenticationSucceded(forLoginWithAccount account: Account? = nil) {
        saveEvent("login.success")
        let label = UILabel(font: .customBody(size: 16.0))
        label.textColor = .white
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
            self.pinView.alpha = 0.0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.dismiss(animated: true, completion: {
                Store.perform(action: LoginSuccess())
                if case .initialLaunch(let loginHandler) = self.context {
                    guard let account = account else { return assertionFailure() }
                    loginHandler(account)
                }
            })
            Store.trigger(name: .showStatusBar)
        })
    }

    private func authenticationFailed() {
        saveEvent("login.failed")
        pinPad.view.isUserInteractionEnabled = false
        pinView.shake { [weak self] in
            self?.pinPad.view.isUserInteractionEnabled = true
        }
        pinPad.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + pinView.shakeDuration) {
            self.pinView.fill(0)
            self.lockIfNeeded()
        }
    }

    private var shouldUseBiometrics: Bool {
        return LAContext.canUseBiometrics && !keyMaster.pinLoginRequired && isBiometricsEnabledForUnlocking
    }

    @objc func biometricsTapped() {
        guard !isWalletDisabled else { return }
        if case .initialLaunch = context {
            keyMaster.createAccount(withBiometricsPrompt: S.UnlockScreen.touchIdPrompt, completion: { account in
                if let account = account {
                    self.authenticationSucceded(forLoginWithAccount: account)
                }
            })
        } else {
            keyMaster.authenticate(withBiometricsPrompt: S.UnlockScreen.touchIdPrompt, completion: { result in
                if result == .success {
                    self.authenticationSucceded()
                }
            })
        }
    }

    private func lockIfNeeded() {
        guard keyMaster.walletIsDisabled else {
            pinPad.view.isUserInteractionEnabled = true
            disabledView.hide { [weak self] in
                self?.disabledView.removeFromSuperview()
                self?.setNeedsStatusBarAppearanceUpdate()
            }
            return
        }
        saveEvent("login.locked")
        let disabledUntil = keyMaster.walletDisabledUntil
        let disabledUntilDate = Date(timeIntervalSince1970: disabledUntil)
        let unlockInterval = disabledUntil - Date().timeIntervalSince1970
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate(unlockInterval > C.secondsInDay ? "h:mm:ss a MMM d, yyy" : "h:mm:ss a")

        disabledView.setTimeLabel(string: String(format: S.UnlockScreen.disabled, df.string(from: disabledUntilDate)))

        pinPad.view.isUserInteractionEnabled = false
        unlockTimer?.invalidate()
        unlockTimer =  Timer.scheduledTimer(withTimeInterval: unlockInterval, repeats: false) { _ in
            self.saveEvent("login.unlocked")
            self.pinPad.view.isUserInteractionEnabled = true
            self.unlockTimer = nil
            self.disabledView.hide { [unowned self] in
                self.disabledView.removeFromSuperview()
                self.setNeedsStatusBarAppearanceUpdate()
            }
        }

        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.walletDisabled)
        faqButton.tintColor = Theme.primaryText
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: faqButton)

        if disabledView.superview == nil {
            view.addSubview(disabledView)
            setNeedsStatusBarAppearanceUpdate()
            disabledView.constrain(toSuperviewEdges: .zero)
            disabledView.show()
        }
    }

    private var isWalletDisabled: Bool {
        let now = Date().timeIntervalSince1970
        return keyMaster.walletDisabledUntil > now
    }
    
    private func showJailbreakWarnings(isJailbroken: Bool) {
        guard isJailbroken else { return }
        let alert = UIAlertController(title: S.JailbreakWarnings.title, message: S.JailbreakWarnings.messageWithBalance, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.JailbreakWarnings.ignore, style: .default, handler: { _ in
            self.saveEvent(self.makeEventName([EventContext.jailbreak.name, Event.ignore.name]))
        }))
        alert.addAction(UIAlertAction(title: S.JailbreakWarnings.close, style: .default, handler: { _ in
            self.saveEvent(self.makeEventName([EventContext.jailbreak.name, Event.close.name]))
            exit(0)
        }))
        present(alert, animated: true, completion: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
