//
//  ModalPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

class ModalPresenter : Subscriber, Trackable {

    //MARK: - Public
    // TODO:BCH: this is the primary wallet manager (BTC)
    let primaryWalletManager: WalletManager
    let walletManagers: [String: WalletManager]
    var gethManager: GethManager?
    lazy var supportCenter: SupportCenterContainer = {
        return SupportCenterContainer(walletManager: self.primaryWalletManager, apiClient: self.noAuthApiClient)
    }()
    
    init(walletManagers: [String: WalletManager], window: UIWindow, apiClient: BRAPIClient, gethManager: GethManager?) {
        self.window = window
        self.walletManagers = walletManagers
        self.primaryWalletManager = walletManagers[Currencies.btc.code]!
        self.modalTransitionDelegate = ModalTransitionDelegate(type: .regular)
        self.wipeNavigationDelegate = StartNavigationDelegate()
        self.noAuthApiClient = apiClient
        self.gethManager = gethManager
        addSubscriptions()
    }

    //MARK: - Private
    private let window: UIWindow
    private let alertHeight: CGFloat = 260.0
    private let modalTransitionDelegate: ModalTransitionDelegate
    private let messagePresenter = MessageUIPresenter()
    private let securityCenterNavigationDelegate = SecurityCenterNavigationDelegate()
    private let verifyPinTransitionDelegate = PinTransitioningDelegate()
    private let noAuthApiClient: BRAPIClient
    private var currentRequest: PaymentRequest?
    private var reachability = ReachabilityMonitor()
    private var notReachableAlert: InAppAlert?
    private let wipeNavigationDelegate: StartNavigationDelegate

    private func addSubscriptions() {

        Store.subscribe(self,
                        selector: { $0.rootModal != $1.rootModal},
                        callback: { self.presentModal($0.rootModal) })
        
        Store.subscribe(self,
                        selector: { $0.alert != $1.alert && $1.alert != nil },
                        callback: { self.handleAlertChange($0.alert) })
        
        Store.subscribe(self, name: .presentFaq(""), callback: {
            guard let trigger = $0 else { return }
            if case .presentFaq(let articleId) = trigger {
                self.presentFaq(articleId: articleId)
            }
        })

        //Subscribe to prompt actions
        Store.subscribe(self, name: .promptUpgradePin, callback: { _ in
            self.presentUpgradePin()
        })
        Store.subscribe(self, name: .promptPaperKey, callback: { _ in
            self.presentWritePaperKey()
        })
        Store.subscribe(self, name: .promptBiometrics, callback: { _ in
            self.presentBiometricsSetting()
        })
        Store.subscribe(self, name: .promptShareData, callback: { _ in
            self.promptShareData()
        })
        Store.subscribe(self, name: .openFile(Data()), callback: {
            guard let trigger = $0 else { return }
            if case .openFile(let file) = trigger {
                self.handleFile(file)
            }
        })
        
        for walletManager in walletManagers.values {
            Store.subscribe(self, name: .recommendRescan(walletManager.currency), callback: { _ in
                self.presentRescan(currency: walletManager.currency)
            })
        }

        //URLs
        Store.subscribe(self, name: .receivedPaymentRequest(nil), callback: {
            guard let trigger = $0 else { return }
            if case let .receivedPaymentRequest(request) = trigger {
                if let request = request {
                    self.handlePaymentRequest(request: request)
                }
            }
        })
        Store.subscribe(self, name: .scanQr, callback: { _ in
            self.handleScanQrURL()
        })
        Store.subscribe(self, name: .copyWalletAddresses(nil, nil), callback: {
            guard let trigger = $0 else { return }
            if case .copyWalletAddresses(let success, let error) = trigger {
                self.handleCopyAddresses(success: success, error: error)
            }
        })
        Store.subscribe(self, name: .authenticateForBitId("", {_ in}), callback: {
            guard let trigger = $0 else { return }
            if case .authenticateForBitId(let prompt, let callback) = trigger {
                self.authenticateForBitId(prompt: prompt, callback: callback)
            }
        })
        reachability.didChange = { isReachable in
            if isReachable {
                self.hideNotReachable()
            } else {
                self.showNotReachable()
            }
        }
        Store.subscribe(self, name: .lightWeightAlert(""), callback: {
            guard let trigger = $0 else { return }
            if case let .lightWeightAlert(message) = trigger {
                self.showLightWeightAlert(message: message)
            }
        })
        Store.subscribe(self, name: .showAlert(nil), callback: {
            guard let trigger = $0 else { return }
            if case let .showAlert(alert) = trigger {
                if let alert = alert {
                    self.topViewController?.present(alert, animated: true, completion: nil)
                }
            }
        })
        Store.subscribe(self, name: .wipeWalletNoPrompt, callback: { _ in
            self.wipeWalletNoPrompt()
        })
    }

    private func presentModal(_ type: RootModal, configuration: ((UIViewController) -> Void)? = nil) {
        guard type != .loginScan else { return presentLoginScan() }
        guard let vc = rootModalViewController(type) else {
            Store.perform(action: RootModalActions.Present(modal: .none))
            return
        }
        vc.transitioningDelegate = modalTransitionDelegate
        vc.modalPresentationStyle = .overFullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        configuration?(vc)
        topViewController?.present(vc, animated: true) {
            Store.perform(action: RootModalActions.Present(modal: .none))
            Store.trigger(name: .hideStatusBar)
        }
    }

    private func handleAlertChange(_ type: AlertType?) {
        guard let type = type else { return }
        presentAlert(type, completion: {
            Store.perform(action: Alert.Hide())
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

    func presentFaq(articleId: String? = nil) {
        supportCenter.modalPresentationStyle = .overFullScreen
        supportCenter.modalPresentationCapturesStatusBarAppearance = true
        supportCenter.transitioningDelegate = supportCenter
        //TODO:AC - add currency
        let url = articleId == nil ? "/support?" : "/support/article?slug=\(articleId!)"
        supportCenter.navigate(to: url)
        topViewController?.present(supportCenter, animated: true, completion: {})
    }

    private func rootModalViewController(_ type: RootModal) -> UIViewController? {
        switch type {
        case .none:
            return nil
        case .send(let currency):
            return makeSendView(currency: currency)
        case .receive:
            return receiveView(isRequestAmountVisible: true)
        case .loginScan:
            return nil //The scan view needs a custom presentation
        case .loginAddress:
            return receiveView(isRequestAmountVisible: false)
        case .requestAmount:
            guard let wallet = primaryWalletManager.wallet else { return nil } // TODO:BCH
            let requestVc = RequestAmountViewController(wallet: wallet)
            requestVc.presentEmail = { [weak self] bitcoinURL, image in
                self?.messagePresenter.presenter = self?.topViewController
                self?.messagePresenter.presentMailCompose(bitcoinURL: bitcoinURL, image: image)
            }
            requestVc.presentText = { [weak self] bitcoinURL, image in
                self?.messagePresenter.presenter = self?.topViewController
                self?.messagePresenter.presentMessageCompose(bitcoinURL: bitcoinURL, image: image)
            }
            return ModalViewController(childViewController: requestVc)
        case .buy:
            presentBuyController("/buy")
            return nil
        }
        
    }

    private func makeSendView(currency: CurrencyDef) -> UIViewController? {
        guard !currency.state.isRescanning else {
            let alert = UIAlertController(title: S.Alert.error, message: S.Send.isRescanning, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
            topViewController?.present(alert, animated: true, completion: nil)
            return nil
        }
        guard let walletManager = walletManagers[currency.code] else { return nil }
        guard let kvStore = walletManager.apiClient?.kv else { return nil }
        let sendVC = SendViewController(sender: Sender(walletManager: walletManager, kvStore: kvStore, currency: currency),
                                        walletManager: walletManager,
                                        initialRequest: currentRequest,
                                        gethManager: nil,
                                        currency: currency)
        currentRequest = nil

        if Store.state.isLoginRequired {
            sendVC.isPresentedFromLock = true
        }

        let root = ModalViewController(childViewController: sendVC)
        sendVC.presentScan = presentScan(parent: root)
        sendVC.presentVerifyPin = { [weak self, weak root] bodyText, success in
            guard let myself = self else { return }
            let walletManager = myself.primaryWalletManager
            let vc = VerifyPinViewController(bodyText: bodyText, pinLength: Store.state.pinLength, walletManager: walletManager, success: success)
            vc.transitioningDelegate = self?.verifyPinTransitionDelegate
            vc.modalPresentationStyle = .overFullScreen
            vc.modalPresentationCapturesStatusBarAppearance = true
            root?.view.isFrameChangeBlocked = true
            root?.present(vc, animated: true, completion: nil)
        }
        sendVC.onPublishSuccess = { [weak self] in
            self?.presentAlert(.sendSuccess, completion: {})
        }
        return root
    }

    private func receiveView(isRequestAmountVisible: Bool) -> UIViewController? {
        let receiveVC = ReceiveViewController(isRequestAmountVisible: isRequestAmountVisible)
        let root = ModalViewController(childViewController: receiveVC)
        receiveVC.presentEmail = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMailCompose(bitcoinAddress: address, image: image)
        }
        receiveVC.presentText = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMessageCompose(address: address, image: image)
        }
        return root
    }

    private func presentLoginScan() {
        guard let top = topViewController else { return }
        let present = presentScan(parent: top)
        Store.perform(action: RootModalActions.Present(modal: .none))
        present({ paymentRequest in
            guard let request = paymentRequest else { return }
            self.currentRequest = request
            //TODO:BCH
            //self.presentModal(.send)
        })
    }
    
    func presentSettings() {
        guard let top = topViewController else { return }
        let walletManager = primaryWalletManager // TODO:BCH
        let settingsNav = UINavigationController()
        settingsNav.setGrayStyle()
        let sections: [SettingsSections] = [.wallet, .preferences, .currencies, .other]
        
        let currencySettings: [Setting]  = Store.state.currencies.flatMap { (currency) -> Setting? in
            guard let walletManager = walletManagers[currency.code] else { return nil }
            return Setting(title: currency.name, callback: { [weak self] in
                guard let `self` = self else { return }
                let sections = [SettingsSections.currency]
                let currencySettings = [
                    SettingsSections.currency: [
                        Setting(title: S.Settings.importTile, callback: {
                            settingsNav.dismiss(animated: true, completion: {
                                self.presentKeyImport(walletManager: walletManager)
                            })
                        }),
                        Setting(title: S.Settings.sync, callback: {
                            settingsNav.pushViewController(ReScanViewController(currency: currency), animated: true)
                        }),
                    ]
                ]
                
                let pageTitle = String(format: S.Settings.currencyPageTitle, currency.name)
                let currencySettingsVC = SettingsViewController(sections: sections, rows: currencySettings, optionalTitle: pageTitle)
                settingsNav.pushViewController(currencySettingsVC, animated: true)
            })
        }
        
        let rows = [
            SettingsSections.wallet: [
                Setting(title: S.Settings.wipe, callback: { [weak self] in
                    guard let `self` = self else { return }
                    let nc = ModalNavigationController()
                    nc.setClearNavbar()
                    nc.setWhiteStyle()
                    nc.delegate = self.wipeNavigationDelegate
                    let start = StartWipeWalletViewController {
                        let recover = EnterPhraseViewController(walletManager: walletManager, reason: .validateForWipingWallet( {
                            self.wipeWallet()
                        }))
                        nc.pushViewController(recover, animated: true)
                    }
                    start.addCloseNavigationItem(tintColor: .white)
                    start.navigationItem.title = S.WipeWallet.title
                    let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.wipeWallet)
                    faqButton.tintColor = .white
                    start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
                    nc.viewControllers = [start]
                    settingsNav.dismiss(animated: true, completion: {
                        self.topViewController?.present(nc, animated: true, completion: nil)
                    })
                })
            ],
            SettingsSections.preferences: [
                //                Setting(title: S.Settings.notifications, accessoryText: {
                //                    return Store.state.isPushNotificationsEnabled ? S.PushNotifications.on : S.PushNotifications.off
                //                }, callback: {
                //                    settingsNav.pushViewController(PushNotificationsViewController(), animated: true)
                //                }),
                Setting(title: LAContext.biometricType() == .face ? S.Settings.faceIdLimit : S.Settings.touchIdLimit, accessoryText: {
                    guard let rate = Currencies.btc.state.currentRate else { return "" }
                    let amount = Amount(amount: walletManager.spendingLimit, rate: rate, maxDigits: Currencies.btc.state.maxDigits, currency: Currencies.btc)
                    return amount.localCurrency
                }, callback: {
                    self.pushBiometricsSpendingLimit(onNc: settingsNav)
                }),
                Setting(title: S.UpdatePin.updateTitle, callback: strongify(self) { myself in
                    let updatePin = UpdatePinViewController(walletManager: walletManager, type: .update)
                    settingsNav.pushViewController(updatePin, animated: true)
                }),
                Setting(title: S.Settings.currency, accessoryText: {
                    let code = Store.state.defaultCurrencyCode
                    let components: [String : String] = [NSLocale.Key.currencyCode.rawValue : code]
                    let identifier = Locale.identifier(fromComponents: components)
                    return Locale(identifier: identifier).currencyCode ?? ""
                }, callback: {
                    settingsNav.pushViewController(DefaultCurrencyViewController(walletManager: walletManager), animated: true)
                }),
            ],
            SettingsSections.currencies: currencySettings,
            SettingsSections.other: [
                Setting(title: S.Settings.shareData, callback: {
                    settingsNav.pushViewController(ShareDataViewController(), animated: true)
                }),
                Setting(title: S.Settings.review, callback: { [weak self] in
                    guard let `self` = self else { return }
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
                }),
                Setting(title: S.Settings.about, callback: {
                    settingsNav.pushViewController(AboutViewController(), animated: true)
                }),
                Setting(title: S.Settings.advanced, callback: {
                    let sections = [SettingsSections.network]
                    let advancedSettings = [
                        SettingsSections.network: [
                            Setting(title: S.NodeSelector.title, callback: {
                                let nodeSelector = NodeSelectorViewController(walletManager: walletManager)
                                settingsNav.pushViewController(nodeSelector, animated: true)
                            }),
                        ]
                    ]
                    
                    let advancedSettingsVC = SettingsViewController(sections: sections, rows: advancedSettings, optionalTitle: S.Settings.advancedTitle)
                    settingsNav.pushViewController(advancedSettingsVC, animated: true)
                })
            ]
        ]
        
        //        if BRAPIClient.featureEnabled(.earlyAccess) {
        //            rows["Bread"]?.insert(Setting(title: S.Settings.earlyAccess, callback: {
        //                settingsNav.dismiss(animated: true, completion: {
        //                    self.presentBuyController("/ea")
        //                })
        //            }), at: 1)
        //        }
        
        let settings = SettingsViewController(sections: sections, rows: rows)
        settings.addCloseNavigationItem(tintColor: .mediumGray)
        settingsNav.viewControllers = [settings]
        top.present(settingsNav, animated: true, completion: nil)
    }
        
    private func presentScan(parent: UIViewController) -> PresentScan {
        return { [weak parent] scanCompletion in
            guard ScanViewController.isCameraAllowed else {
                self.saveEvent("scan.cameraDenied")
                if let parent = parent {
                    ScanViewController.presentCameraUnavailableAlert(fromRoot: parent)
                }
                return
            }
            let vc = ScanViewController(completion: { paymentRequest in
                scanCompletion(paymentRequest)
                parent?.view.isFrameChangeBlocked = false
            }, isValidURI: { address in
                //TODO:AC - add isValidAddress
                return true
                //return Store.state.currency.isValidAddress(address)
            })
            parent?.view.isFrameChangeBlocked = true
            parent?.present(vc, animated: true, completion: {})
        }
    }

    func presentSecurityCenter() {
        let securityCenter = SecurityCenterViewController(walletManager: primaryWalletManager)
        let nc = ModalNavigationController(rootViewController: securityCenter)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        securityCenter.didTapPin = {
            let updatePin = UpdatePinViewController(walletManager: self.primaryWalletManager, type: .update)
            nc.pushViewController(updatePin, animated: true)
        }
        securityCenter.didTapBiometrics = strongify(self) { myself in
            let biometricsSettings = BiometricsSettingsViewController(walletManager: self.primaryWalletManager)
            biometricsSettings.presentSpendingLimit = {
                myself.pushBiometricsSpendingLimit(onNc: nc)
            }
            nc.pushViewController(biometricsSettings, animated: true)
        }
        securityCenter.didTapPaperKey = { [weak self] in
            self?.presentWritePaperKey(fromViewController: nc)
        }

        window.rootViewController?.present(nc, animated: true, completion: nil)
    }

    private func pushBiometricsSpendingLimit(onNc: UINavigationController) {
        let verify = VerifyPinViewController(bodyText: S.VerifyPin.continueBody, pinLength: Store.state.pinLength, walletManager: primaryWalletManager, success: { pin in
            let spendingLimit = BiometricsSpendingLimitViewController(walletManager: self.primaryWalletManager)
            onNc.pushViewController(spendingLimit, animated: true)
        })
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        onNc.present(verify, animated: true, completion: nil)
    }

    private func presentWritePaperKey(fromViewController vc: UIViewController) {
        let paperPhraseNavigationController = UINavigationController()
        paperPhraseNavigationController.setClearNavbar()
        paperPhraseNavigationController.setWhiteStyle()
        paperPhraseNavigationController.modalPresentationStyle = .overFullScreen
        let start = StartPaperPhraseViewController(callback: { [weak self] in
            guard let `self` = self else { return }
            let verify = VerifyPinViewController(bodyText: S.VerifyPin.continueBody, pinLength: Store.state.pinLength, walletManager: self.primaryWalletManager, success: { pin in
                self.pushWritePaperPhrase(navigationController: paperPhraseNavigationController, pin: pin)
            })
            verify.transitioningDelegate = self.verifyPinTransitionDelegate
            verify.modalPresentationStyle = .overFullScreen
            verify.modalPresentationCapturesStatusBarAppearance = true
            paperPhraseNavigationController.present(verify, animated: true, completion: nil)
        })
        start.addCloseNavigationItem(tintColor: .white)
        start.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.paperKey)
        faqButton.tintColor = .white
        start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
        paperPhraseNavigationController.viewControllers = [start]
        vc.present(paperPhraseNavigationController, animated: true, completion: nil)
    }

    private func pushWritePaperPhrase(navigationController: UINavigationController, pin: String) {
        let walletManager = primaryWalletManager
        var writeViewController: WritePaperPhraseViewController?
        writeViewController = WritePaperPhraseViewController(walletManager: walletManager, pin: pin, callback: {
            var confirm: ConfirmPaperPhraseViewController?
            confirm = ConfirmPaperPhraseViewController(walletManager: walletManager, pin: pin, callback: {
                confirm?.dismiss(animated: true, completion: {
                    Store.perform(action: Alert.Show(.paperKeySet(callback: {
                        Store.perform(action: HideStartFlow())
                    })))
                })
            })
            writeViewController?.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
            if let confirm = confirm {
                navigationController.pushViewController(confirm, animated: true)
            }
        })
        writeViewController?.addCloseNavigationItem(tintColor: .white)
        writeViewController?.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
        guard let writeVC = writeViewController else { return }
        navigationController.pushViewController(writeVC, animated: true)
    }

    private func presentBuyController(_ mountPoint: String) {
        let walletManager = primaryWalletManager
        let vc: BRWebViewController
        #if Debug || Testflight
            vc = BRWebViewController(bundleName: "bread-frontend-staging", mountPoint: mountPoint, walletManager: walletManager)
        #else
            vc = BRWebViewController(bundleName: "bread-frontend", mountPoint: mountPoint, walletManager: walletManager, store: store)
        #endif
        vc.startServer()
        vc.preload()
        self.topViewController?.present(vc, animated: true, completion: nil)
    }

    private func presentRescan(currency: CurrencyDef) {
        let vc = ReScanViewController(currency: currency)
        let nc = UINavigationController(rootViewController: vc)
        nc.setClearNavbar()
        vc.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }

    private func wipeWallet() {
        let alert = UIAlertController(title: S.WipeWallet.alertTitle, message: S.WipeWallet.alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: S.WipeWallet.wipe, style: .default, handler: { _ in
            self.topViewController?.dismiss(animated: true, completion: {
                self.wipeWalletNoPrompt()
            })
        }))
        topViewController?.present(alert, animated: true, completion: nil)
    }

    private func wipeWalletNoPrompt() {
        let activity = BRActivityViewController(message: S.WipeWallet.wiping)
        self.topViewController?.present(activity, animated: true, completion: nil)
        //TODO:BCH
        DispatchQueue.walletQueue.async {
            self.walletManagers.values.forEach({ $0.peerManager?.disconnect() })
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                activity.dismiss(animated: true, completion: {
                    if self.primaryWalletManager.wipeWallet(pin: "forceWipe") {
                        Store.trigger(name: .reinitWalletManager({}))
                    } else {
                        let failure = UIAlertController(title: S.WipeWallet.failedTitle, message: S.WipeWallet.failedMessage, preferredStyle: .alert)
                        failure.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
                        self.topViewController?.present(failure, animated: true, completion: nil)
                    }
                })
            })
        }
    }
    
    private func presentKeyImport(walletManager: WalletManager) {
        let nc = ModalNavigationController()
        nc.setClearNavbar()
        nc.setWhiteStyle()
        let start = StartImportViewController(walletManager: walletManager)
        start.addCloseNavigationItem(tintColor: .white)
        start.navigationItem.title = S.Import.title
        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.importWallet)
        faqButton.tintColor = .white
        start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
        nc.viewControllers = [start]
        topViewController?.present(nc, animated: true, completion: nil)
    }

    //MARK: - Prompts
    func presentBiometricsSetting() {
        let walletManager = primaryWalletManager
        let biometricsSettings = BiometricsSettingsViewController(walletManager: walletManager)
        biometricsSettings.addCloseNavigationItem(tintColor: .white)
        let nc = ModalNavigationController(rootViewController: biometricsSettings)
        biometricsSettings.presentSpendingLimit = strongify(self) { myself in
            myself.pushBiometricsSpendingLimit(onNc: nc)
        }
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        topViewController?.present(nc, animated: true, completion: nil)
    }

    private func promptShareData() {
        let shareData = ShareDataViewController()
        let nc = ModalNavigationController(rootViewController: shareData)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        shareData.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }

    func presentWritePaperKey() {
        guard let vc = topViewController else { return }
        presentWritePaperKey(fromViewController: vc)
    }

    func presentUpgradePin() {
        let walletManager = primaryWalletManager
        let updatePin = UpdatePinViewController(walletManager: walletManager, type: .update)
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
                        //TODO:BCH
                        //Store.perform(action: RootModalActions.Present(modal: .send))
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
        //TODO:BCH
        //guard !Store.state.isLoginRequired else { presentModal(.send); return }

        if topViewController is AccountViewController {
            //TODO:BCH
            //presentModal(.send)
        } else {
            if let presented = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController {
                presented.dismiss(animated: true, completion: {
                    //TODO:BCH
                    //self.presentModal(.send)
                })
            }
        }
    }

    private func handleScanQrURL() {
        guard !Store.state.isLoginRequired else { presentLoginScan(); return }
        if topViewController is AccountViewController || topViewController is LoginViewController {
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
        let walletManager = primaryWalletManager // TODO:BCH
        let alert = UIAlertController(title: S.URLHandling.addressListAlertTitle, message: S.URLHandling.addressListAlertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.URLHandling.copy, style: .default, handler: { [weak self] _ in
            let verify = VerifyPinViewController(bodyText: S.URLHandling.addressListVerifyPrompt, pinLength: Store.state.pinLength, walletManager: walletManager, success: { [weak self] pin in
                self?.copyAllAddressesToClipboard()
                Store.perform(action: Alert.Show(.addressesCopied))
                if let success = success, let url = URL(string: success) {
                    UIApplication.shared.openURL(url)
                }
            })
            verify.transitioningDelegate = self?.verifyPinTransitionDelegate
            verify.modalPresentationStyle = .overFullScreen
            verify.modalPresentationCapturesStatusBarAppearance = true
            self?.topViewController?.present(verify, animated: true, completion: nil)
        }))
        topViewController?.present(alert, animated: true, completion: nil)
    }

    private func authenticateForBitId(prompt: String, callback: @escaping (BitIdAuthResult) -> Void) {
        if UserDefaults.isBiometricsEnabled {
            primaryWalletManager.authenticate(biometricsPrompt: prompt, completion: { result in
                switch result {
                case .success:
                    return callback(.success)
                case .cancel:
                    return callback(.cancelled)
                case .failure:
                    self.verifyPinForBitId(prompt: prompt, callback: callback)
                case .fallback:
                    self.verifyPinForBitId(prompt: prompt, callback: callback)
                }
            })
        } else {
            self.verifyPinForBitId(prompt: prompt, callback: callback)
        }
    }

    private func verifyPinForBitId(prompt: String, callback: @escaping (BitIdAuthResult) -> Void) {
        let verify = VerifyPinViewController(bodyText: prompt, pinLength: Store.state.pinLength, walletManager: primaryWalletManager, success: { pin in
                callback(.success)
        })
        verify.didCancel = { callback(.cancelled) }
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        topViewController?.present(verify, animated: true, completion: nil)
    }

    private func copyAllAddressesToClipboard() {
        guard let wallet = primaryWalletManager.wallet else { return } // TODO:BCH
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

    private func showLightWeightAlert(message: String) {
        let alert = LightWeightAlert(message: message)
        let view = UIApplication.shared.keyWindow!
        view.addSubview(alert)
        alert.constrain([
            alert.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alert.centerYAnchor.constraint(equalTo: view.centerYAnchor) ])
        alert.background.effect = nil
        UIView.animate(withDuration: 0.6, animations: {
            alert.background.effect = alert.effect
        }, completion: { _ in
            UIView.animate(withDuration: 0.6, delay: 1.0, options: [], animations: {
                alert.background.effect = nil
            }, completion: { _ in
                alert.removeFromSuperview()
            })
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

        if viewController is BiometricsSettingsViewController {
            navigationController.setWhiteStyle()
        } else {
            navigationController.setDefaultStyle()
        }
    }
}
