//
//  ModalPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ModalPresenter : Subscriber {

    //MARK: - Public
    var walletManager: WalletManager? {
        didSet {
            guard let walletManager = walletManager else { return }
            initializeSupportCenter(walletManager: walletManager)
        }
    }
    init(store: Store, apiClient: BRAPIClient, window: UIWindow) {
        self.store = store
        self.window = window
        self.apiClient = apiClient
        self.modalTransitionDelegate = ModalTransitionDelegate(type: .regular)
        addSubscriptions()
    }

    //MARK: - Private
    private let store: Store
    private let apiClient: BRAPIClient
    private let window: UIWindow
    private let alertHeight: CGFloat = 260.0
    private let modalTransitionDelegate: ModalTransitionDelegate
    private let messagePresenter = MessageUIPresenter()
    private let securityCenterNavigationDelegate = SecurityCenterNavigationDelegate()
    private let verifyPinTransitionDelegate = PinTransitioningDelegate()
    private var supportCenter: SupportCenterContainer?
    private var currentRequest: PaymentRequest?
    private var reachability = ReachabilityManager(host: "google.com")
    private var notReachableAlert: InAppAlert?
    
    private func initializeSupportCenter(walletManager: WalletManager) {
        supportCenter = SupportCenterContainer(walletManager: walletManager, store: store, apiClient: apiClient)
    }

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.rootModal != $1.rootModal},
                        callback: { self.presentModal($0.rootModal) })
        store.subscribe(self,
                        selector: { $0.alert != $1.alert && $1.alert != nil },
                        callback: { self.handleAlertChange($0.alert) })
        store.subscribe(self, name: .presentFaq(""), callback: {
            guard let trigger = $0 else { return }
            if case .presentFaq(let articleId) = trigger {
                self.presentFaq(articleId: articleId)
            }
        })

        //Subscribe to prompt actions
        store.subscribe(self, name: .promptUpgradePin, callback: { _ in
            self.presentUpgradePin()
        })
        store.subscribe(self, name: .promptPaperKey, callback: { _ in
            self.presentWritePaperKey()
        })
        store.subscribe(self, name: .promptTouchId, callback: { _ in
            self.presentTouchIdSetting()
        })
        store.subscribe(self, name: .openFile(Data()), callback: {
            guard let trigger = $0 else { return }
            if case .openFile(let file) = trigger {
                self.handleFile(file)
            }
        })
        store.subscribe(self, name: .recommendRescan, callback: { _ in
            self.presentRescan()
        })

        //URLs
        store.subscribe(self, name: .receivedPaymentRequest(nil), callback: {
            guard let trigger = $0 else { return }
            if case let .receivedPaymentRequest(request) = trigger {
                if let request = request {
                    self.handlePaymentRequest(request: request)
                }
            }
        })
        store.subscribe(self, name: .scanQr, callback: { _ in
            self.handleScanQrURL()
        })
        store.subscribe(self, name: .copyWalletAddresses(nil, nil), callback: {
            guard let trigger = $0 else { return }
            if case .copyWalletAddresses(let success, let error) = trigger {
                self.handleCopyAddresses(success: success, error: error)
            }
        })
        store.subscribe(self, name: .authenticateForBitId("", {_ in}), callback: {
            guard let trigger = $0 else { return }
            if case .authenticateForBitId(let prompt, let callback) = trigger {
                self.authenticateForBitId(prompt: prompt, callback: callback)
            }
        })
        reachability.didChange = { isReachable in
            if isReachable {
                self.hideNotReachable()
                DispatchQueue.walletQueue.async {
                    self.walletManager?.peerManager?.connect()
                }
            } else {
                self.showNotReachable()
            }
        }
    }

    private func presentModal(_ type: RootModal, configuration: ((UIViewController) -> Void)? = nil) {
        guard type != .loginScan else { return presentLoginScan() }
        guard let vc = rootModalViewController(type) else { return }
        vc.transitioningDelegate = modalTransitionDelegate
        vc.modalPresentationStyle = .overFullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        configuration?(vc)
        topViewController?.present(vc, animated: true, completion: {
            self.store.perform(action: RootModalActions.Present(modal: .none))
        })
    }

    private func handleAlertChange(_ type: AlertType?) {
        guard let type = type else { return }
        presentAlert(type, completion: {
            self.store.perform(action: Alert.Hide())
        })
    }

    private func presentAlert(_ type: AlertType, completion: @escaping ()->Void) {
        let alertView = AlertView(type: type)
        let window = UIApplication.shared.keyWindow!
        let size = window.bounds.size
        window.addSubview(alertView)

        let topConstraint = alertView.constraint(.top, toView: window, constant: size.height)
        alertView.constrain([
            alertView.constraint(.width, constant: size.width),
            alertView.constraint(.height, constant: alertHeight + 25.0),
            alertView.constraint(.leading, toView: window, constant: nil),
            topConstraint ])
        window.layoutIfNeeded()

        UIView.spring(0.6, animations: {
            topConstraint?.constant = size.height - self.alertHeight
            window.layoutIfNeeded()
        }, completion: { _ in
            alertView.animate()
            UIView.spring(0.6, delay: 2.0, animations: {
                topConstraint?.constant = size.height
                window.layoutIfNeeded()
            }, completion: { _ in
                //TODO - Make these callbacks generic
                if case .paperKeySet(let callback) = type {
                    callback()
                }
                if case .pinSet(let callback) = type {
                    callback()
                }
                if case .sweepSuccess(let callback) = type {
                    callback()
                }
                completion()
                alertView.removeFromSuperview()
            })
        })
    }

    private func presentFaq(articleId: String? = nil) {
        guard let supportCenter = supportCenter else { return }
        supportCenter.modalPresentationStyle = .overFullScreen
        supportCenter.modalPresentationCapturesStatusBarAppearance = true
        supportCenter.transitioningDelegate = supportCenter
        let url = articleId == nil ? "/support" : "/staticarticle/\(articleId!)"
        supportCenter.navigate(to: url)
        topViewController?.present(supportCenter, animated: true, completion: {})
    }

    private func rootModalViewController(_ type: RootModal) -> UIViewController? {
        switch type {
        case .none:
            return nil
        case .send:
            return makeSendView()
        case .receive:
            return receiveView(isRequestAmountVisible: true)
        case .menu:
            return menuViewController()
        case .loginScan:
            return nil //The scan view needs a custom presentation
        case .loginAddress:
            return receiveView(isRequestAmountVisible: false)
        case .manageWallet:
            return ModalViewController(childViewController: ManageWalletViewController(store: store), store: store)
        case .requestAmount:
            guard let wallet = walletManager?.wallet else { return nil }
            return ModalViewController(childViewController: RequestAmountViewController(wallet: wallet, store: store), store: store)
        }
    }

    private func makeSendView() -> UIViewController? {
        guard let walletManager = walletManager else { return nil }
        guard let kvStore = apiClient.kv else { return nil }
        let sendVC = SendViewController(store: store, sender: Sender(walletManager: walletManager, kvStore: kvStore), walletManager: walletManager, initialRequest: currentRequest)
        currentRequest = nil

        if store.state.isLoginRequired {
            sendVC.isPresentedFromLock = true
        }

        let root = ModalViewController(childViewController: sendVC, store: store)
        sendVC.presentScan = presentScan(parent: root)
        sendVC.presentVerifyPin = { [weak self, weak root] bodyText, callback in
            let vc = VerifyPinViewController(bodyText: bodyText, pinLength: walletManager.pinLength, callback: callback)
            vc.transitioningDelegate = self?.verifyPinTransitionDelegate
            vc.modalPresentationStyle = .overFullScreen
            vc.modalPresentationCapturesStatusBarAppearance = true
            root?.view.isFrameChangeBlocked = true
            root?.present(vc, animated: true, completion: nil)
        }
        sendVC.onPublishSuccess = { [weak self] in
            self?.presentAlert(.sendSuccess, completion: {})
        }
        sendVC.onPublishFailure = { [weak self] in
            self?.presentAlert(.sendFailure, completion: {})
        }
        return root
    }

    private func receiveView(isRequestAmountVisible: Bool) -> UIViewController? {
        guard let wallet = walletManager?.wallet else { return nil }
        let receiveVC = ReceiveViewController(wallet: wallet, store: store, isRequestAmountVisible: isRequestAmountVisible)
        let root = ModalViewController(childViewController: receiveVC, store: store)
        receiveVC.presentEmail = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMailCompose(address: address, image: image)
        }
        receiveVC.presentText = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMessageCompose(address: address, image: image)
        }
        return root
    }

    private func menuViewController() -> UIViewController? {
        let menu = MenuViewController()
        let root = ModalViewController(childViewController: menu, store: store)
        menu.didTapSecurity = { [weak self, weak menu] in
            self?.modalTransitionDelegate.reset()
            menu?.dismiss(animated: true) {
                self?.presentSecurityCenter()
            }
        }
        menu.didTapSupport = { [weak self, weak menu] in
            menu?.dismiss(animated: true, completion: {
                self?.presentFaq()
            })
        }
        menu.didTapLock = { [weak self, weak menu] in
            menu?.dismiss(animated: true) {
                self?.store.trigger(name: .lock)
            }
        }
        menu.didTapSettings = { [weak self, weak menu] in
            menu?.dismiss(animated: true) {
                self?.presentSettings()
            }
        }
        menu.didTapBuy = { [weak self, weak menu] in
            menu?.dismiss(animated: true, completion: {
                self?.presentBuyController("/buy")
            })
        }
        return root
    }

    private func presentLoginScan() {
        guard let top = topViewController else { return }
        let present = presentScan(parent: top)
        store.perform(action: RootModalActions.Present(modal: .none))
        present({ paymentRequest in
            guard let request = paymentRequest else { return }
            self.currentRequest = request
            self.presentModal(.send)
        })
    }

    private func presentSettings() {
        guard let top = topViewController else { return }
        guard let walletManager = self.walletManager else { return }

        let settingsNav = UINavigationController()
        let sections = ["Wallet", "Manage", "Bread"]
        var rows = [
            "Wallet": [Setting(title: S.Settings.importTile, callback: { [weak self] in
                    guard let myself = self else { return }
                    guard let walletManager = myself.walletManager else { return }
                    let importNav = ModalNavigationController()
                    importNav.setClearNavbar()
                    importNav.setWhiteStyle()
                    let start = StartImportViewController(walletManager: walletManager, store: myself.store)
                    start.addCloseNavigationItem(tintColor: .white)
                    start.navigationItem.title = S.Import.title
                    let faqButton = UIButton.buildFaqButton(store: myself.store, articleId: ArticleIds.importWallet)
                    faqButton.tintColor = .white
                    start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
                    importNav.viewControllers = [start]
                    settingsNav.dismiss(animated: true, completion: {
                        myself.topViewController?.present(importNav, animated: true, completion: nil)
                    })
                })],
            "Manage": [
                Setting(title: S.Settings.notifications, accessoryText: {
                    return "Off"
                }, callback: {
                    settingsNav.pushViewController(PushNotificationsViewController(store: self.store), animated: true)
                }),
                Setting(title: S.Settings.touchIdLimit, accessoryText: { [weak self] in
                    guard let myself = self else { return "" }
                    guard let rate = myself.store.state.currentRate else { return "" }
                    let amount = Amount(amount: walletManager.spendingLimit, rate: rate, maxDigits: myself.store.state.maxDigits)
                    return amount.localCurrency
                }, callback: {
                    settingsNav.pushViewController(TouchIdSpendingLimitViewController(walletManager: walletManager, store: self.store), animated: true)
                }),
                Setting(title: S.Settings.currency, accessoryText: {
                    let code = self.store.state.defaultCurrencyCode
                    let components: [String : String] = [NSLocale.Key.currencyCode.rawValue : code]
                    let identifier = Locale.identifier(fromComponents: components)
                    return Locale(identifier: identifier).currencyCode ?? ""
                }, callback: {
                    settingsNav.pushViewController(DefaultCurrencyViewController(apiClient: self.apiClient, store: self.store), animated: true)
                }),
                Setting(title: S.Settings.sync, callback: {
                    settingsNav.pushViewController(ReScanViewController(store: self.store), animated: true)
                })
            ],
            "Bread": [
                Setting(title: S.Settings.shareData, callback: {
                    settingsNav.pushViewController(ShareDataViewController(store: self.store), animated: true)
                }),
                Setting(title: S.Settings.about, callback: {
                    settingsNav.pushViewController(AboutViewController(), animated: true)
                }),
            ]
        ]

        if Environment.isTestFlight || Environment.isDebug {
            rows["Manage"]?.append(
                Setting(title: "Wipe Wallet", callback: {
                    self.wipeWallet()
                })
            )
        }

        if BRAPIClient.featureEnabled(.earlyAccess) {
            rows["Bread"]?.insert(Setting(title: S.Settings.earlyAccess, callback: {
                settingsNav.dismiss(animated: true, completion: {
                    self.presentBuyController("/ea")
                })
            }), at: 1)
        }

        rows["Bread"]?.append( Setting(title: S.Settings.review, callback: {
                let alert = UIAlertController(title: S.Settings.review, message: S.Settings.enjoying, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: S.Button.no, style: .default, handler: { _ in
                    self.messagePresenter.presenter = self.topViewController
                    self.messagePresenter.presentFeedbackCompose()
                }))
                alert.addAction(UIAlertAction(title: S.Button.yes, style: .default, handler: { _ in
                    if let url = URL(string: C.reviewLink) {
                        UIApplication.shared.openURL(url)
                    }
                }))
                self.topViewController?.present(alert, animated: true, completion: nil)
            })
        )

        let settings = SettingsViewController(sections: sections, rows: rows)
        settingsNav.viewControllers = [settings]
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.backgroundColor = .whiteTint
        settingsNav.navigationBar.setBackgroundImage(view.imageRepresentation, for: .default)
        settingsNav.navigationBar.shadowImage = UIImage()
        settingsNav.navigationBar.isTranslucent = false
        settingsNav.setBlackBackArrow()
        top.present(settingsNav, animated: true, completion: nil)
    }

    private func presentScan(parent: UIViewController) -> PresentScan {
        return { [weak parent] scanCompletion in
            guard ScanViewController.isCameraAllowed else {
                let alertController = UIAlertController(title: S.Send.cameraUnavailableTitle, message: S.Send.cameraUnavailableMessage, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
                alertController.addAction(UIAlertAction(title: S.Button.settings, style: .`default`, handler: { _ in
                    if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
                        UIApplication.shared.openURL(appSettings)
                    }
                }))
                parent?.present(alertController, animated: true, completion: nil)
                return
            }
            let vc = ScanViewController(completion: { address in
                scanCompletion(address)
                parent?.view.isFrameChangeBlocked = false
            }, isValidURI: { address in
                return address.isValidAddress
            })
            parent?.view.isFrameChangeBlocked = true
            parent?.present(vc, animated: true, completion: {})
        }
    }

    private func presentSecurityCenter() {
        guard let walletManager = walletManager else { return }
        let securityCenter = SecurityCenterViewController(store: store, walletManager: walletManager)
        let nc = ModalNavigationController(rootViewController: securityCenter)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        securityCenter.didTapPin = { [weak self] in
            guard let myself = self else { return }
            let updatePin = UpdatePinViewController(store: myself.store, walletManager: walletManager, type: .update)
            nc.pushViewController(updatePin, animated: true)
        }
        securityCenter.didTapTouchId = { [weak self] in
            guard let myself = self else { return }
            let touchIdSettings = TouchIdSettingsViewController(walletManager: walletManager, store: myself.store)
            touchIdSettings.presentSpendingLimit = {
                let spendingLimit = TouchIdSpendingLimitViewController(walletManager: walletManager, store: myself.store)
                nc.pushViewController(spendingLimit, animated: true)
            }
            nc.pushViewController(touchIdSettings, animated: true)
        }
        securityCenter.didTapPaperKey = { [weak self] in
            self?.presentWritePaperKey(fromViewController: nc)
        }

        window.rootViewController?.present(nc, animated: true, completion: nil)
    }

    private func presentWritePaperKey(fromViewController vc: UIViewController) {
        guard let walletManager = walletManager else { return }
        let paperPhraseNavigationController = UINavigationController()
        paperPhraseNavigationController.setClearNavbar()
        paperPhraseNavigationController.setWhiteStyle()
        paperPhraseNavigationController.modalPresentationStyle = .overFullScreen
        let start = StartPaperPhraseViewController(store: store, callback: { [weak self] in
            guard let myself = self else { return }
            let verify = VerifyPinViewController(bodyText: S.VerifyPin.continueBody, pinLength: walletManager.pinLength, callback: { pin, vc in
                if walletManager.authenticate(pin: pin) {
                    var write: WritePaperPhraseViewController?
                    write = WritePaperPhraseViewController(store: myself.store, walletManager: walletManager, pin: pin, callback: { [weak self] in
                        guard let myself = self else { return }
                        var confirm: ConfirmPaperPhraseViewController?
                        confirm = ConfirmPaperPhraseViewController(store: myself.store, walletManager: walletManager, pin: pin, callback: {
                                confirm?.dismiss(animated: true, completion: {
                                    self?.presentAlert(.paperKeySet(callback: {})) {
                                        self?.store.perform(action: HideStartFlow())
                                    }
                            })
                        })
                        write?.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
                        if let confirm = confirm {
                            paperPhraseNavigationController.pushViewController(confirm, animated: true)
                        }
                    })
                    write?.addCloseNavigationItem(tintColor: .white)
                    write?.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle

                    vc.dismiss(animated: true, completion: {
                        guard let write = write else { return }
                        paperPhraseNavigationController.pushViewController(write, animated: true)
                    })
                    return true
                } else {
                    return false
                }
            })
            verify.transitioningDelegate = self?.verifyPinTransitionDelegate
            verify.modalPresentationStyle = .overFullScreen
            verify.modalPresentationCapturesStatusBarAppearance = true
            paperPhraseNavigationController.present(verify, animated: true, completion: nil)
        })
        start.addCloseNavigationItem(tintColor: .white)
        start.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
        let faqButton = UIButton.buildFaqButton(store: store, articleId: ArticleIds.paperPhrase)
        faqButton.tintColor = .white
        start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
        paperPhraseNavigationController.viewControllers = [start]
        vc.present(paperPhraseNavigationController, animated: true, completion: nil)
    }

    private func presentBuyController(_ mountPoint: String) {
        guard let walletManager = self.walletManager else { return }
        let vc: BRWebViewController
        #if Debug || Testflight
            vc = BRWebViewController(bundleName: "bread-buy-staging", mountPoint: mountPoint, walletManager: walletManager, store: store, apiClient: apiClient)
        #else
            vc = BRWebViewController(bundleName: "bread-buy", mountPoint: mountPoint, walletManager: walletManager, store: store, apiClient: apiClient)
        #endif
        vc.startServer()
        vc.preload()
        self.topViewController?.present(vc, animated: true, completion: nil)
    }

    private func presentRescan() {
        let vc = ReScanViewController(store: self.store)
        let nc = UINavigationController(rootViewController: vc)
        nc.setClearNavbar()
        vc.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }

    func wipeWallet() {
        let alert = UIAlertController(title: "Wipe", message: "Wipe wallet?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "Wipe", style: .default, handler: { _ in
            self.topViewController?.dismiss(animated: true, completion: {
                let activity = BRActivityViewController(message: "wiping...")
                self.topViewController?.present(activity, animated: true, completion: nil)
                DispatchQueue.walletQueue.sync {
                    self.walletManager?.peerManager?.disconnect()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                        activity.dismiss(animated: true, completion: {
                            if (self.walletManager?.wipeWallet(pin: "forceWipe"))! {
                                let success = UIAlertController(title: "Success", message: "Successfully wiped wallet....shutting down", preferredStyle: .alert)
                                success.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                                    abort()
                                }))
                                self.topViewController?.present(success, animated: true, completion: nil)
                            } else {
                                let failure = UIAlertController(title: "Failed", message: "Failed to wipe wallet.", preferredStyle: .alert)
                                failure.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                self.topViewController?.present(failure, animated: true, completion: nil)
                            }
                        })
                    })
                }
            })
        }))
        topViewController?.present(alert, animated: true, completion: nil)
    }

    //MARK: - Prompts
    func presentTouchIdSetting() {
        guard let walletManager = walletManager else { return }
        let touchIdSettings = TouchIdSettingsViewController(walletManager: walletManager, store: store)
        touchIdSettings.addCloseNavigationItem(tintColor: .white)
        let nc = ModalNavigationController(rootViewController: touchIdSettings)

        touchIdSettings.presentSpendingLimit = { [weak self] in
            guard let myself = self else { return }
            let spendingLimit = TouchIdSpendingLimitViewController(walletManager: walletManager, store: myself.store)
            nc.pushViewController(spendingLimit, animated: true)
        }

        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        topViewController?.present(nc, animated: true, completion: nil)
    }

    func presentWritePaperKey() {
        guard let vc = topViewController else { return }
        presentWritePaperKey(fromViewController: vc)
    }

    func presentUpgradePin() {
        guard let walletManager = walletManager else { return }
        let updatePin = UpdatePinViewController(store: store, walletManager: walletManager, type: .update)
        let nc = ModalNavigationController(rootViewController: updatePin)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        updatePin.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }

    private func handleFile(_ file: Data) {
        if let request = PaymentProtocolRequest(data: file) {
            if let topVC = topViewController as? ModalViewController {
                let attemptConfirmRequest: () -> Bool = {
                    if let send = topVC.childViewController as? SendViewController {
                        send.confirmProtocolRequest(protoReq: request)
                        return true
                    }
                    return false
                }
                if !attemptConfirmRequest() {
                    modalTransitionDelegate.reset()
                    topVC.dismiss(animated: true, completion: {
                        self.store.perform(action: RootModalActions.Present(modal: .send))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { //This is a hack because present has no callback
                            let _ = attemptConfirmRequest()
                        })
                    })
                }
            }
        } else if let ack = PaymentProtocolACK(data: file) {
            if let memo = ack.memo {
                let alert = UIAlertController(title: "", message: memo, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
                topViewController?.present(alert, animated: true, completion: nil)
            }
        //TODO - handle payment type
        } else {
            let alert = UIAlertController(title: S.Alert.error, message: S.PaymentProtocol.Errors.corruptedDocument, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
            topViewController?.present(alert, animated: true, completion: nil)
        }
    }

    private func handlePaymentRequest(request: PaymentRequest) {
        self.currentRequest = request
        guard !store.state.isLoginRequired else { presentModal(.send); return }

        if topViewController is AccountViewController {
            presentModal(.send)
        } else {
            if let presented = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController {
                presented.dismiss(animated: true, completion: {
                    self.presentModal(.send)
                })
            }
        }
    }

    private func handleScanQrURL() {
        guard !store.state.isLoginRequired else { presentLoginScan(); return }

        if topViewController is AccountViewController {
            presentLoginScan()
        } else {
            if let presented = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController {
                presented.dismiss(animated: true, completion: {
                    self.presentLoginScan()
                })
            }
        }
    }

    private func handleCopyAddresses(success: String?, error: String?) {
        guard let walletManager = walletManager else { return }
        let alert = UIAlertController(title: S.URLHandling.addressListAlertTitle, message: S.URLHandling.addressListAlertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.URLHandling.copy, style: .default, handler: { [weak self] _ in
            let verify = VerifyPinViewController(bodyText: S.URLHandling.addressListVerifyPrompt, pinLength: walletManager.pinLength, callback: { [weak self] pin, view in
                if walletManager.authenticate(pin: pin) {
                    self?.copyAllAddressesToClipboard()
                    view.dismiss(animated: true, completion: {
                        self?.store.perform(action: Alert.Show(.addressesCopied))
                        if let success = success, let url = URL(string: success) {
                            UIApplication.shared.openURL(url)
                        }
                    })
                    return true
                } else {
                    return false
                }
            })
            verify.transitioningDelegate = self?.verifyPinTransitionDelegate
            verify.modalPresentationStyle = .overFullScreen
            verify.modalPresentationCapturesStatusBarAppearance = true
            self?.topViewController?.present(verify, animated: true, completion: nil)
        }))
        topViewController?.present(alert, animated: true, completion: nil)
    }

    private func authenticateForBitId(prompt: String, callback: @escaping () -> Void) {
        if UserDefaults.isTouchIdEnabled {
            walletManager?.authenticate(touchIDPrompt: prompt, completion: { success in
                guard success else { self.verifyPinForBitId(prompt: prompt, callback: callback); return }
                callback()
            })
        } else {
            self.verifyPinForBitId(prompt: prompt, callback: callback)
        }
    }

    private func verifyPinForBitId(prompt: String, callback: @escaping () -> Void) {
        guard let walletManager = walletManager else { return }
        let verify = VerifyPinViewController(bodyText: prompt, pinLength: walletManager.pinLength, callback: { pin, view in
            if walletManager.authenticate(pin: pin) {
                view.dismiss(animated: true, completion: {
                    callback()
                })
                return true
            } else {
                return false
            }
        })
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        topViewController?.present(verify, animated: true, completion: nil)
    }

    private func copyAllAddressesToClipboard() {
        guard let wallet = walletManager?.wallet else { return }
        let addresses = wallet.allAddresses.filter({wallet.addressIsUsed($0)})
        UIPasteboard.general.string = addresses.joined(separator: "\n")
    }

    private var topViewController: UIViewController? {
        var viewController = window.rootViewController
        while viewController?.presentedViewController != nil {
            viewController = viewController?.presentedViewController
        }
        return viewController
    }

    private func showNotReachable() {
        guard notReachableAlert == nil else { return }
        let alert = InAppAlert(message: S.Alert.noInternet, image: #imageLiteral(resourceName: "BrokenCloud"))
        notReachableAlert = alert
        let window = UIApplication.shared.keyWindow!
        let size = window.bounds.size
        window.addSubview(alert)
        let bottomConstraint = alert.bottomAnchor.constraint(equalTo: window.topAnchor, constant: 0.0)
        alert.constrain([
            alert.constraint(.width, constant: size.width),
            alert.constraint(.height, constant: InAppAlert.height),
            alert.constraint(.leading, toView: window, constant: nil),
            bottomConstraint ])
        window.layoutIfNeeded()
        alert.bottomConstraint = bottomConstraint
        alert.hide = {
            self.hideNotReachable()
        }
        UIView.spring(C.animationDuration, animations: {
            alert.bottomConstraint?.constant = InAppAlert.height
            window.layoutIfNeeded()
        }, completion: {_ in})
    }

    private func hideNotReachable() {
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.notReachableAlert?.bottomConstraint?.constant = 0.0
            self.notReachableAlert?.superview?.layoutIfNeeded()
        }, completion: { _ in
            self.notReachableAlert?.removeFromSuperview()
            self.notReachableAlert = nil
        })
    }
}

class SecurityCenterNavigationDelegate : NSObject, UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        guard let coordinator = navigationController.topViewController?.transitionCoordinator else { return }

        if coordinator.isInteractive {
            coordinator.notifyWhenInteractionEnds { context in
                //We only want to style the view controller if the
                //pop animation wasn't cancelled
                if !context.isCancelled {
                    self.setStyle(navigationController: navigationController, viewController: viewController)
                }
            }
        } else {
            setStyle(navigationController: navigationController, viewController: viewController)
        }
    }

    func setStyle(navigationController: UINavigationController, viewController: UIViewController) {
        if viewController is SecurityCenterViewController {
            navigationController.isNavigationBarHidden = true
        } else {
            navigationController.isNavigationBarHidden = false
        }

        if viewController is TouchIdSettingsViewController {
            navigationController.setWhiteStyle()
        } else {
            navigationController.setDefaultStyle()
        }
    }
}
