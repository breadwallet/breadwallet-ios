//
//  ModalPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication
import BRCore

// swiftlint:disable type_body_length
// swiftlint:disable cyclomatic_complexity

class ModalPresenter: Subscriber, Trackable {

    // MARK: - Public
    let keyStore: KeyStore
    var walletManagers: [String: WalletManager]
    lazy var supportCenter: SupportCenterContainer = {
        return SupportCenterContainer(walletAuthenticator: keyStore, walletManagers: self.walletManagers)
    }()
    
    init(keyStore: KeyStore, walletManagers: [String: WalletManager], window: UIWindow) {
        self.window = window
        self.walletManagers = walletManagers
        self.keyStore = keyStore
        self.modalTransitionDelegate = ModalTransitionDelegate(type: .regular)
        self.wipeNavigationDelegate = StartNavigationDelegate()
        addSubscriptions()
        if !Reachability.isReachable {
            showNotReachable()
        }
    }
    
    deinit {
        Store.unsubscribe(self)
    }

    // MARK: - Private
    private let window: UIWindow
    private let alertHeight: CGFloat = 260.0
    private let modalTransitionDelegate: ModalTransitionDelegate
    private let messagePresenter = MessageUIPresenter()
    private let securityCenterNavigationDelegate = SecurityCenterNavigationDelegate()
    private let verifyPinTransitionDelegate = PinTransitioningDelegate()
    private var currentRequest: PaymentRequest?
    private var notReachableAlert: InAppAlert?
    private let wipeNavigationDelegate: StartNavigationDelegate

    private func addSubscriptions() {

        Store.lazySubscribe(self,
                        selector: { $0.rootModal != $1.rootModal},
                        callback: { [weak self] in self?.presentModal($0.rootModal) })
        
        Store.lazySubscribe(self,
                        selector: { $0.alert != $1.alert && $1.alert != .none },
                        callback: { [weak self] in self?.handleAlertChange($0.alert) })
        
        Store.subscribe(self, name: .presentFaq("", nil), callback: { [weak self] in
            guard let trigger = $0 else { return }
            if case .presentFaq(let articleId, let currency) = trigger {
                self?.presentFaq(articleId: articleId, currency: currency)
            }
        })

        //Subscribe to prompt actions
        Store.subscribe(self, name: .promptUpgradePin, callback: { [weak self] _ in
            self?.presentUpgradePin()
        })
        Store.subscribe(self, name: .promptPaperKey, callback: { [weak self] _ in
            self?.presentWritePaperKey()
        })
        Store.subscribe(self, name: .promptBiometrics, callback: { [weak self] _ in
            self?.presentBiometricsMenuItem()
        })
        Store.subscribe(self, name: .promptShareData, callback: { [weak self] _ in
            self?.promptShareData()
        })
        Store.subscribe(self, name: .openFile(Data()), callback: { [weak self] in
            guard let trigger = $0 else { return }
            if case .openFile(let file) = trigger {
                self?.handleFile(file)
            }
        })

        //URLs
        Store.subscribe(self, name: .receivedPaymentRequest(nil), callback: { [weak self] in
            guard let trigger = $0 else { return }
            if case let .receivedPaymentRequest(request) = trigger {
                if let request = request {
                    self?.handlePaymentRequest(request: request)
                }
            }
        })
        Store.subscribe(self, name: .scanQr, callback: { [weak self] _ in
            self?.handleScanQrURL()
        })
        Store.subscribe(self, name: .copyWalletAddresses(nil, nil), callback: { [weak self] in
            guard let trigger = $0 else { return }
            if case .copyWalletAddresses(let success, let error) = trigger {
                self?.handleCopyAddresses(success: success, error: error)
            }
        })
        Store.subscribe(self, name: .authenticateForPlatform("", true, {_ in}), callback: { [unowned self] in
            guard let trigger = $0 else { return }
            if case .authenticateForPlatform(let prompt, let allowBiometricAuth, let callback) = trigger {
                self.authenticateForPlatform(prompt: prompt, allowBiometricAuth: allowBiometricAuth, callback: callback)
            }
        })
        Store.subscribe(self, name: .confirmTransaction(Currencies.btc, Amount.empty, Amount.empty, "", {_ in}), callback: { [unowned self] in
            guard let trigger = $0 else { return }
            if case .confirmTransaction(let currency, let amount, let fee, let address, let callback) = trigger {
                self.confirmTransaction(currency: currency, amount: amount, fee: fee, address: address, callback: callback)
            }
        })
        Reachability.addDidChangeCallback({ [weak self] isReachable in
            if isReachable {
                self?.hideNotReachable()
            } else {
                self?.showNotReachable()
            }
        })
        Store.subscribe(self, name: .lightWeightAlert(""), callback: { [weak self] in
            guard let trigger = $0 else { return }
            if case let .lightWeightAlert(message) = trigger {
                self?.showLightWeightAlert(message: message)
            }
        })
        Store.subscribe(self, name: .showAlert(nil), callback: { [weak self] in
            guard let trigger = $0 else { return }
            if case let .showAlert(alert) = trigger {
                if let alert = alert {
                    self?.topViewController?.present(alert, animated: true, completion: nil)
                }
            }
        })
        Store.subscribe(self, name: .wipeWalletNoPrompt, callback: { [weak self] _ in
            self?.wipeWalletNoPrompt()
        })
        Store.subscribe(self, name: .showCurrency(Currencies.btc), callback: { [unowned self] in
            guard let trigger = $0 else { return }
            if case .showCurrency(let currency) = trigger {
                self.showAccountView(currency: currency, animated: true, completion: nil)
            }
        })
        Store.subscribe(self, name: .promptLinkWallet(WalletPairingRequest.empty)) { [unowned self] in
            guard case .promptLinkWallet(let pairingRequest)? = $0 else { return }
            self.linkWallet(pairingRequest: pairingRequest)
        }
        
        // Push Notifications Permission Request
        Store.subscribe(self, name: .registerForPushNotificationToken) { [weak self]  _ in
            guard let top = self?.topViewController else { return }
            NotificationAuthorizer().requestAuthorization(fromViewController: top, completion: { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("[PUSH] notification authorization granted")
                    } else {
                        // TODO: log event
                        print("[PUSH] notification authorization denied")
                    }
                }
            })
        }
        
        Store.subscribe(self, name: .openPlatformUrl("")) { [unowned self] in
            guard let trigger = $0 else { return }
            if case let .openPlatformUrl(url) = trigger {
                self.presentPlatformWebViewController(url)
            }
        }
    }

    private func presentModal(_ type: RootModal, configuration: ((UIViewController) -> Void)? = nil) {
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

    private func handleAlertChange(_ type: AlertType) {
        guard type != .none else { return }
        presentAlert(type, completion: {
            Store.perform(action: Alert.Hide())
        })
    }

    private func presentAlert(_ type: AlertType, completion: @escaping () -> Void) {
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

    func preloadSupportCenter() {
        supportCenter.loadWebView() // pre-load contents for faster access
    }

    func presentFaq(articleId: String? = nil, currency: Currency? = nil) {
        supportCenter.modalPresentationStyle = .overFullScreen
        supportCenter.modalPresentationCapturesStatusBarAppearance = true
        supportCenter.transitioningDelegate = supportCenter
        var url: String
        if let articleId = articleId {
            url = "/support/article?slug=\(articleId)"
            if let currency = currency {
                url += "&currency=\(currency.supportCurrencyCode)"
            }
        } else {
            url = "/support?"
        }
        supportCenter.navigate(to: url)
        topViewController?.present(supportCenter, animated: true, completion: {})
    }

    private func rootModalViewController(_ type: RootModal) -> UIViewController? {
        switch type {
        case .none:
            return nil
        case .send(let currency):
            return makeSendView(currency: currency)
        case .sendForRequest(let request):
            return makeSendView(forRequest: request)
        case .receive(let currency):
            return makeReceiveView(currency: currency, isRequestAmountVisible: (currency.urlSchemes != nil))
        case .loginScan:
            presentLoginScan()
            return nil
        case .loginAddress:
            return makeReceiveView(currency: Currencies.btc, isRequestAmountVisible: false)
        case .requestAmount(let currency, let address):
            let requestVc = RequestAmountViewController(currency: currency, receiveAddress: address)
            
            requestVc.shareAddress = { [weak self] uri, qrCode in
                self?.messagePresenter.presenter = self?.topViewController
                self?.messagePresenter.presentShareSheet(text: uri, image: qrCode)
            }
                        
            return ModalViewController(childViewController: requestVc)
        case .buy(let currency):
            var url = "/buy"
            if let currency = currency {
                url += "?currency=\(currency.code)"
            }
            presentPlatformWebViewController(url)
            return nil
        case .sell(let currency):
            var url = "/sell"
            if let currency = currency {
                url += "?currency=\(currency.code)"
            }
            presentPlatformWebViewController(url)
            return nil
        case .trade:
            presentPlatformWebViewController("/trade")
            return nil
        case .receiveLegacy:
            return makeReceiveView(currency: Currencies.btc, isRequestAmountVisible: false, isBTCLegacy: true)
        }
    }

    private func makeSendView(forRequest request: PigeonRequest) -> UIViewController? {
        guard let walletManager = walletManagers[request.currency.code] else { return nil }
        guard let kvStore = Backend.kvStore else { return nil }
        guard let sender = request.currency.createSender(authenticator: keyStore, walletManager: walletManager, kvStore: kvStore) else { return nil }
        if let ethSender = sender as? EthereumSender {
            ethSender.checkoutCustomGasPrice = request.txFee?.rawValue
            ethSender.checkoutCustomGasLimit = request.txSize
        }
        let checkoutVC = CheckoutConfirmationViewController(request: request, sender: sender)
        checkoutVC.presentVerifyPin = { [weak self, weak checkoutVC] bodyText, success in
            guard let `self` = self else { return }
            let vc = VerifyPinViewController(bodyText: bodyText,
                                             pinLength: Store.state.pinLength,
                                             walletAuthenticator: self.keyStore,
                                             success: success)
            vc.transitioningDelegate = self.verifyPinTransitionDelegate
            vc.modalPresentationStyle = .overFullScreen
            vc.modalPresentationCapturesStatusBarAppearance = true
            checkoutVC?.present(vc, animated: true, completion: nil)
        }
        checkoutVC.onPublishSuccess = { [weak self] in
            self?.presentAlert(.sendSuccess, completion: {})
        }
        return checkoutVC
    }

    private func makeSendView(currency: Currency) -> UIViewController? {
        guard !(currency.state?.isRescanning ?? false) else {
            let alert = UIAlertController(title: S.Alert.error, message: S.Send.isRescanning, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
            topViewController?.present(alert, animated: true, completion: nil)
            return nil
        }
        guard let walletManager = walletManagers[currency.code] else { return nil }
        guard let kvStore = Backend.kvStore else { return nil }
        guard let sender = currency.createSender(authenticator: keyStore, walletManager: walletManager, kvStore: kvStore) else { return nil }
        let sendVC = SendViewController(sender: sender,
                                        currency: currency,
                                        initialRequest: currentRequest)
        currentRequest = nil

        if Store.state.isLoginRequired {
            sendVC.isPresentedFromLock = true
        }

        let root = ModalViewController(childViewController: sendVC)
        sendVC.presentScan = presentScan(parent: root, currency: currency)
        sendVC.presentVerifyPin = { [weak self, weak root] bodyText, success in
            guard let `self` = self else { return }
            let vc = VerifyPinViewController(bodyText: bodyText,
                                             pinLength: Store.state.pinLength,
                                             walletAuthenticator: self.keyStore,
                                             success: success)
            vc.transitioningDelegate = self.verifyPinTransitionDelegate
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

    private func makeReceiveView(currency: Currency, isRequestAmountVisible: Bool, isBTCLegacy: Bool = false) -> UIViewController? {
        let receiveVC = ReceiveViewController(currency: currency, isRequestAmountVisible: isRequestAmountVisible, isBTCLegacy: isBTCLegacy)
        let root = ModalViewController(childViewController: receiveVC)
        
        receiveVC.shareAddress = { [weak self, weak root] address, qrCode in
            guard let `self` = self, let root = root else { return }
            self.messagePresenter.presenter = root
            self.messagePresenter.presentShareSheet(text: address, image: qrCode)
        }
        
        return root
    }

    private func presentLoginScan() {
        guard let top = topViewController else { return }
        let present = presentScan(parent: top, currency: nil)
        present { [unowned self] scanResult in
            guard let scanResult = scanResult else { return }
            switch scanResult {
            case .paymentRequest(let request):
                let message = String(format: S.Scanner.paymentPromptMessage, request.currency.name)
                let alert = UIAlertController.confirmationAlert(title: S.Scanner.paymentPrompTitle, message: message) {
                    self.currentRequest = request
                    self.presentModal(.send(currency: request.currency))
                }
                top.present(alert, animated: true, completion: nil)
                
            case .privateKey:
                if let walletManager = self.walletManagers[Currencies.btc.code] as? BTCWalletManager {
                    self.presentKeyImport(walletManager: walletManager, scanResult: scanResult)
                }
                
            case .deepLink(let url):
                if let params = url.queryParameters,
                    let pubKey = params["publicKey"],
                    let identifier = params["id"],
                    let service = params["service"] {
                    print("[EME] PAIRING REQUEST | pubKey: \(pubKey) | identifier: \(identifier) | service: \(service)")
                    Store.trigger(name: .promptLinkWallet(WalletPairingRequest(publicKey: pubKey, identifier: identifier, service: service, returnToURL: nil)))
                }
            case .invalid:
                break
            }
        }
    }
        
    // MARK: Settings
    func presentMenu() {
        guard let top = topViewController else { return }
        let menuNav = UINavigationController()
        menuNav.setDarkStyle()
        
        var enableSegwit = MenuItem(title: S.Settings.enableSegwit, callback: {
            let segwitView = SegwitViewController()
            menuNav.pushViewController(segwitView, animated: true)
        })
        enableSegwit.shouldShow = { return !UserDefaults.hasOptedInSegwit }
        var viewLegacyAddress = MenuItem(title: S.Settings.viewLegacyAddress, callback: {
            Backend.apiClient.sendViewLegacyAddress()
            Store.perform(action: RootModalActions.Present(modal: .receiveLegacy))
        })
        viewLegacyAddress.shouldShow = { return UserDefaults.hasOptedInSegwit }
        
        var btcItems: [MenuItem] = [
            // Rescan
            MenuItem(title: S.Settings.sync, callback: {
                menuNav.pushViewController(ReScanViewController(currency: Currencies.btc), animated: true)
            }),
            // Nodes
            MenuItem(title: S.NodeSelector.title, callback: {
                guard let btcWalletManager = self.walletManagers[Currencies.btc.code] as? BTCWalletManager else { return }
                let nodeSelector = NodeSelectorViewController(walletManager: btcWalletManager)
                menuNav.pushViewController(nodeSelector, animated: true)
            }),
            //TODO: universal scan -- remove
            MenuItem(title: S.Settings.importTile, callback: {
                guard let btcWalletManager = self.walletManagers[Currencies.btc.code] as? BTCWalletManager else { return }
                menuNav.dismiss(animated: true, completion: { [unowned self] in
                    self.presentKeyImport(walletManager: btcWalletManager)
                })
            }),
            enableSegwit,
            viewLegacyAddress
        ]
        
        if UserDefaults.isBiometricsEnabled {
            let biometricSpendingLimitItem = MenuItem(title: LAContext.biometricType() == .face ? S.Settings.faceIdLimit : S.Settings.touchIdLimit, accessoryText: {
                guard let btcWalletManager = self.walletManagers[Currencies.btc.code] as? BTCWalletManager,
                    let rate = Currencies.btc.state?.currentRate else { return "" }
                let amount = Amount(amount: UInt256(btcWalletManager.spendingLimit), currency: Currencies.btc, rate: rate)
                return amount.fiatDescription
            }, callback: { [weak self] in
                self?.pushBiometricsSpendingLimit(onNc: menuNav)
            })
            btcItems.insert(biometricSpendingLimitItem, at: 0)
        }
        
        let bchItems: [MenuItem] = [
            // Rescan
            MenuItem(title: S.Settings.sync, callback: {
                menuNav.pushViewController(ReScanViewController(currency: Currencies.bch), animated: true)
            }),
            //TODO: universal scan -- remove
            MenuItem(title: S.Settings.importTile, callback: {
                guard let bchWalletManager = self.walletManagers[Currencies.bch.code] as? BTCWalletManager else { return }
                menuNav.dismiss(animated: true, completion: { [unowned self] in
                    self.presentKeyImport(walletManager: bchWalletManager)
                })
            })
        ]
        
        let preferencesItems: [MenuItem] = [
            // Display Currency
            MenuItem(title: S.Settings.currency, accessoryText: {
                let code = Store.state.defaultCurrencyCode
                let components: [String : String] = [NSLocale.Key.currencyCode.rawValue: code]
                let identifier = Locale.identifier(fromComponents: components)
                return Locale(identifier: identifier).currencyCode ?? ""
            }, callback: {
                menuNav.pushViewController(DefaultCurrencyViewController(), animated: true)
            }),
            
            // Bitcoin Settings
            MenuItem(title: String(format: S.Settings.currencyPageTitle, Currencies.btc.name), subMenu: btcItems, rootNav: menuNav),
            
            // Bitcoin Cash Settings
            MenuItem(title: String(format: S.Settings.currencyPageTitle, Currencies.bch.name), subMenu: bchItems, rootNav: menuNav),
            
            // Share Anonymous Data
            MenuItem(title: S.Settings.shareData, callback: {
                menuNav.pushViewController(ShareDataViewController(), animated: true)
            }),
            
            // Reset Wallets
            MenuItem(title: S.Settings.resetCurrencies, callback: {
                menuNav.dismiss(animated: true, completion: {
                    Store.trigger(name: .resetDisplayCurrencies)
                })
            })
        ]
        
        let securityItems: [MenuItem] = [
            // Unlink
            MenuItem(title: S.Settings.wipe) { [unowned self] in
                guard let vc = self.topViewController else { return }

                RecoveryKeyFlowController.enterUnlinkWalletFlow(from: vc,
                                                                keyMaster: self.keyStore,
                                                                phraseEntryReason: .validateForWipingWallet({
                                                                    self.wipeWallet()
                                                                }))
            },
            
            // Update PIN
            MenuItem(title: S.UpdatePin.updateTitle) { [unowned self] in
                let updatePin = UpdatePinViewController(keyMaster: self.keyStore, type: .update)
                menuNav.pushViewController(updatePin, animated: true)
            },
            
            // Biometrics
            MenuItem(title: LAContext.biometricType() == .face ? S.SecurityCenter.Cells.faceIdTitle : S.SecurityCenter.Cells.touchIdTitle) { [unowned self] in
                guard let btcWalletManager = self.walletManagers[Currencies.btc.code] as? BTCWalletManager else { return }
                let biometricsSettings = BiometricsSettingsViewController(walletManager: btcWalletManager)
                biometricsSettings.presentSpendingLimit = {
                    self.pushBiometricsSpendingLimit(onNc: menuNav)
                }
                menuNav.pushViewController(biometricsSettings, animated: true)
            },
            
            // Paper key
            MenuItem(title: S.SecurityCenter.Cells.paperKeyTitle) { [unowned self] in
                self.presentWritePaperKey(fromViewController: menuNav)
            }
        ]
        
        var rootItems: [MenuItem] = [
            // Scan QR Code
            MenuItem(title: S.MenuButton.scan, icon: #imageLiteral(resourceName: "scan")) { [unowned self] in
                self.presentLoginScan()
            },
            
            // Manage Wallets
            MenuItem(title: S.MenuButton.manageWallets, icon: #imageLiteral(resourceName: "wallet")) {
                guard let kvStore = Backend.kvStore else { return }
                let vc = EditWalletsViewController(type: .manage, kvStore: kvStore)
                menuNav.pushViewController(vc, animated: true)
            },
            
            // Preferences
            MenuItem(title: S.Settings.preferences, icon: #imageLiteral(resourceName: "prefs"), subMenu: preferencesItems, rootNav: menuNav),
            
            // Security
            MenuItem(title: S.MenuButton.security,
                     icon: #imageLiteral(resourceName: "security"),
                     subMenu: securityItems,
                     rootNav: menuNav,
                     faqButton: UIButton.buildFaqButton(articleId: ArticleIds.securityCenter)),
            
            // Support
            MenuItem(title: S.MenuButton.support, icon: #imageLiteral(resourceName: "support")) { [unowned self] in
                self.presentFaq()
            },
                        
            // Rewards
            MenuItem(title: S.Settings.rewards, icon: #imageLiteral(resourceName: "Star")) {
                self.presentPlatformWebViewController("/rewards")
            },
            
            // About
            MenuItem(title: S.Settings.about, icon: #imageLiteral(resourceName: "about")) {
                menuNav.pushViewController(AboutViewController(), animated: true)
            }
        ]

        // MARK: Developer/QA Menu
        if E.isSimulator || E.isDebug || E.isTestFlight {
            var developerItems = [MenuItem]()
            
            developerItems.append(MenuItem(title: S.Settings.sendLogs) { [unowned self] in
                self.showEmailLogsModal()
            })
            
            developerItems.append(MenuItem(title: "Unlink Wallet (no prompt)") { [unowned self] in
                self.wipeWalletNoPrompt()
            })
            
            if E.isDebug { // for dev/debugging use only
                // For test wallets with a PIN of 111111, the PIN is auto entered on startup.
                developerItems.append(MenuItem(title: "Auto-enter PIN",
                                               accessoryText: { UserDefaults.debugShouldAutoEnterPIN ? "ON" : "OFF" },
                                               callback: {
                                                _ = UserDefaults.toggleAutoEnterPIN()
                                                (menuNav.topViewController as? MenuViewController)?.reloadMenu()
                }))
            }
            
            // For test wallets, suppresses the paper key prompt on the home screen.
            developerItems.append(MenuItem(title: "Suppress paper key prompt",
                                           accessoryText: { UserDefaults.debugShouldSuppressPaperKeyPrompt ? "ON" : "OFF" },
                                           callback: {
                                            _ = UserDefaults.toggleSuppressPaperKeyPrompt()
                                            (menuNav.topViewController as? MenuViewController)?.reloadMenu()
            }))
            
            // always show the app rating when viewing transactions if 'ON' AND Suppress is 'OFF' (see below)
            developerItems.append(MenuItem(title: "App rating on enter wallet",
                                           accessoryText: { UserDefaults.debugShowAppRatingOnEnterWallet ? "ON" : "OFF" },
                                           callback: {
                                            _ = UserDefaults.toggleShowAppRatingPromptOnEnterWallet()
                                            (menuNav.topViewController as? MenuViewController)?.reloadMenu()
            }))

            developerItems.append(MenuItem(title: "Suppress app rating prompt",
                                           accessoryText: { UserDefaults.debugSuppressAppRatingPrompt ? "ON" : "OFF" },
                                           callback: {
                                            _ = UserDefaults.toggleSuppressAppRatingPrompt()
                                            (menuNav.topViewController as? MenuViewController)?.reloadMenu()
            }))

            // Shows a preview of the paper key.
            if let paperKey = self.keyStore.seedPhrase(pin: "111111") {
                let words = paperKey.components(separatedBy: " ")
                let preview = "\(words[0]) \(words[1])..."
                developerItems.append(MenuItem(title: "Paper key preview",
                                               accessoryText: { UserDefaults.debugShouldShowPaperKeyPreview ? preview : "" },
                                               callback: {
                                                _ = UserDefaults.togglePaperKeyPreview()
                                                (menuNav.topViewController as? MenuViewController)?.reloadMenu()
                }))
            }
                        
            developerItems.append(MenuItem(title: "Reset User Defaults",
                                           callback: {
                                            UserDefaults.resetAll()
                                            menuNav.showAlert(title: "", message: "User defaults reset")
                                            (menuNav.topViewController as? MenuViewController)?.reloadMenu()
            }))

            developerItems.append(MenuItem(title: "Reset EME Paired Wallets",
                                           accessoryText: { "\(Backend.pigeonExchange?.pairedWallets?.pubKeys.count ?? 0)" },
                                           callback: {
                                            Backend.pigeonExchange?.resetPairedWallets()
                                            menuNav.showAlert(title: "", message: "Paired wallets reset")
            }))
            
            developerItems.append(
                MenuItem(title: "API Host",
                         accessoryText: { Backend.apiClient.host }, callback: {
                            let alert = UIAlertController(title: "Set API Host", message: "Clear and save to reset", preferredStyle: .alert)
                            alert.addTextField(configurationHandler: { textField in
                                textField.text = Backend.apiClient.host
                                textField.keyboardType = .URL
                                textField.clearButtonMode = .always
                            })

                            alert.addAction(UIAlertAction(title: "Save", style: .default) { (_) in
                                guard let newHost = alert.textFields?.first?.text, !newHost.isEmpty else {
                                    UserDefaults.debugBackendHost = nil
                                    Backend.apiClient.host = C.backendHost
                                    (menuNav.topViewController as? MenuViewController)?.reloadMenu()
                                    return
                                }
                                let originalHost = Backend.apiClient.host
                                Backend.apiClient.host = newHost
                                Backend.apiClient.me { (success, _, _) in
                                    if success {
                                        UserDefaults.debugBackendHost = newHost
                                        (menuNav.topViewController as? MenuViewController)?.reloadMenu()
                                    } else {
                                        Backend.apiClient.host = originalHost
                                    }
                                }
                            })

                            alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))

                            menuNav.present(alert, animated: true, completion: nil)
                }))

            developerItems.append(
                MenuItem(title: "Web Platform Bundle",
                         accessoryText: { C.webBundle }, callback: {
                            let alert = UIAlertController(title: "Set bundle name", message: "Clear and save to reset", preferredStyle: .alert)
                            alert.addTextField(configurationHandler: { textField in
                                textField.text = C.webBundle
                                textField.keyboardType = .URL
                                textField.clearButtonMode = .always
                            })

                            alert.addAction(UIAlertAction(title: "Save", style: .default) { (_) in
                                guard let newBundleName = alert.textFields?.first?.text, !newBundleName.isEmpty else {
                                    UserDefaults.debugWebBundleName = nil
                                    (menuNav.topViewController as? MenuViewController)?.reloadMenu()
                                    return
                                }

                                guard let bundle = AssetArchive(name: newBundleName, apiClient: Backend.apiClient) else { return assertionFailure() }
                                bundle.update { error in
                                    DispatchQueue.main.async {
                                        guard error == nil else {
                                            let alert = UIAlertController(title: S.Alert.error,
                                                                          message: "Unable to fetch bundle named \(newBundleName)",
                                                preferredStyle: .alert)
                                            alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
                                            menuNav.present(alert, animated: true, completion: nil)
                                            return
                                        }
                                        UserDefaults.debugWebBundleName = newBundleName
                                        (menuNav.topViewController as? MenuViewController)?.reloadMenu()
                                    }
                                }
                            })

                            alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))

                            menuNav.present(alert, animated: true, completion: nil)
                }))

            developerItems.append(
                MenuItem(title: "Web Platform Debug URL",
                         accessoryText: { UserDefaults.platformDebugURL?.absoluteString ?? "<not set>" }, callback: {
                            let alert = UIAlertController(title: "Set debug URL", message: "Clear and save to reset", preferredStyle: .alert)
                            alert.addTextField(configurationHandler: { textField in
                                textField.text = UserDefaults.platformDebugURL?.absoluteString ?? ""
                                textField.keyboardType = .URL
                                textField.clearButtonMode = .always
                            })

                            alert.addAction(UIAlertAction(title: "Save", style: .default) { (_) in
                                guard let input = alert.textFields?.first?.text,
                                    !input.isEmpty,
                                    let debugURL = URL(string: input) else {
                                    UserDefaults.platformDebugURL = nil
                                    (menuNav.topViewController as? MenuViewController)?.reloadMenu()
                                    return
                                }
                                UserDefaults.platformDebugURL = debugURL
                                (menuNav.topViewController as? MenuViewController)?.reloadMenu()
                            })

                            alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))

                            menuNav.present(alert, animated: true, completion: nil)
                }))

            rootItems.append(MenuItem(title: "Developer Options", icon: nil, subMenu: developerItems, rootNav: menuNav, faqButton: nil))
        }
        
        let rootMenu = MenuViewController(items: rootItems,
                                          title: S.Settings.title)
        rootMenu.addCloseNavigationItem(side: .right)
        menuNav.viewControllers = [rootMenu]
        top.present(menuNav, animated: true, completion: nil)
    }
    
    private func presentScan(parent: UIViewController, currency: Currency?) -> PresentScan {
        return { [weak parent] scanCompletion in
            guard ScanViewController.isCameraAllowed else {
                self.saveEvent("scan.cameraDenied")
                if let parent = parent {
                    ScanViewController.presentCameraUnavailableAlert(fromRoot: parent)
                }
                return
            }
            let scanCurrency = (currency is ERC20Token) ? Currencies.eth : currency
            let vc = ScanViewController(forPaymentRequestForCurrency: scanCurrency, completion: { scanResult in
                scanCompletion(scanResult)
                parent?.view.isFrameChangeBlocked = false
            })
            parent?.view.isFrameChangeBlocked = true
            parent?.present(vc, animated: true, completion: {})
        }
    }

    private func pushBiometricsSpendingLimit(onNc: UINavigationController) {
        guard let btcWalletManager = self.walletManagers[Currencies.btc.code] as? BTCWalletManager else { return }
        let verify = VerifyPinViewController(bodyText: S.VerifyPin.continueBody,
                                             pinLength: Store.state.pinLength,
                                             walletAuthenticator: keyStore,
                                             success: { _ in
                                                let spendingLimit = BiometricsSpendingLimitViewController(walletManager: btcWalletManager)
                                                onNc.pushViewController(spendingLimit, animated: true)
        })
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        onNc.present(verify, animated: true, completion: nil)
    }
    
    private func presentWritePaperKey(fromViewController vc: UIViewController) {
        RecoveryKeyFlowController.enterRecoveryKeyFlow(pin: nil,
                                                       keyMaster: self.keyStore,
                                                       from: vc,
                                                       context: .none,
                                                       dismissAction: nil)
    }

    private func presentPlatformWebViewController(_ mountPoint: String) {
        let vc = BRWebViewController(bundleName: C.webBundle,
                                     mountPoint: mountPoint,
                                     walletAuthenticator: keyStore,
                                     walletManagers: walletManagers)
        vc.startServer()
        vc.preload()
        vc.modalPresentationStyle = .overFullScreen
        self.topViewController?.present(vc, animated: true, completion: nil)
    }

    private func presentRescan(currency: Currency) {
        let vc = ReScanViewController(currency: currency)
        let nc = UINavigationController(rootViewController: vc)
        nc.setClearNavbar()
        vc.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }

    private func wipeWallet() {
        let alert = UIAlertController.confirmationAlert(title: S.WipeWallet.alertTitle,
                                                        message: S.WipeWallet.alertMessage,
                                                        okButtonTitle: S.WipeWallet.wipe,
                                                        cancelButtonTitle: S.Button.cancel,
                                                        isDestructiveAction: true) {
                                                            self.topViewController?.dismiss(animated: true, completion: {
                                                                self.wipeWalletNoPrompt()
                                                            })
        }
        topViewController?.present(alert, animated: true, completion: nil)
    }

    private func wipeWalletNoPrompt() {
        let activity = BRActivityViewController(message: S.WipeWallet.wiping)
        self.topViewController?.present(activity, animated: true, completion: nil)
        DispatchQueue.walletQueue.async {
            self.walletManagers.values.forEach({
                $0.resetForWipe()
            })
            DispatchQueue.walletQueue.asyncAfter(deadline: .now() + 2.0, execute: {
                let success = self.keyStore.wipeWallet()
                Backend.disconnectWallet()
                DispatchQueue.main.async {
                    activity.dismiss(animated: true) {
                        if success {
                            Store.trigger(name: .reinitWalletManager({
                                Store.trigger(name: .resetDisplayCurrencies)
                            }))
                        } else {
                            let failure = UIAlertController(title: S.WipeWallet.failedTitle, message: S.WipeWallet.failedMessage, preferredStyle: .alert)
                            failure.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
                            self.topViewController?.present(failure, animated: true, completion: nil)
                        }
                    }
                }
            })
        }
    }
    
    private func presentKeyImport(walletManager: BTCWalletManager, scanResult: QRCode? = nil) {
        // TODO: auto-import to both BTC and BCH wallet managers
        let nc = ModalNavigationController()
        nc.setClearNavbar()
        nc.setWhiteStyle()
        let start = StartImportViewController(walletManager: walletManager, initialQRCode: scanResult)
        start.addCloseNavigationItem(tintColor: .white)
        start.navigationItem.title = S.Import.title
        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.importWallet, currency: walletManager.currency)
        faqButton.tintColor = .white
        start.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
        nc.viewControllers = [start]
        topViewController?.present(nc, animated: true, completion: nil)
    }

    // MARK: - Prompts
    func presentBiometricsMenuItem() {
        guard let btcWalletManager = self.walletManagers[Currencies.btc.code] as? BTCWalletManager else { return assertionFailure() }
        let biometricsSettings = BiometricsSettingsViewController(walletManager: btcWalletManager)
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
        let updatePin = UpdatePinViewController(keyMaster: keyStore, type: .update)
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
                        send.confirmProtocolRequest(request)
                        return true
                    }
                    return false
                }
                if !attemptConfirmRequest() {
                    modalTransitionDelegate.reset()
                    topVC.dismiss(animated: true, completion: {
                        //TODO:BCH
                        Store.perform(action: RootModalActions.Present(modal: .send(currency: Currencies.btc)))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { //This is a hack because present has no callback
                            _ = attemptConfirmRequest()
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
        guard !Store.state.isLoginRequired else { presentModal(.send(currency: request.currency)); return }

        showAccountView(currency: request.currency, animated: false) {
            self.presentModal(.send(currency: request.currency))
        }
    }
    
    private func showAccountView(currency: Currency, animated: Bool, completion: (() -> Void)?) {
        let pushAccountView = {
            guard let nc = self.topViewController?.navigationController as? RootNavigationController,
                nc.viewControllers.count == 1 else { return }
            guard let walletManager = self.walletManagers[currency.code] else { return }
            let accountViewController = AccountViewController(currency: currency, walletManager: walletManager)
            nc.pushViewController(accountViewController, animated: animated)
            completion?()
        }
        
        if let accountVC = topViewController as? AccountViewController {
            if accountVC.currency.matches(currency) {
                completion?()
            } else {
                accountVC.navigationController?.popToRootViewController(animated: false)
                pushAccountView()
            }
        } else if topViewController is HomeScreenViewController {
            pushAccountView()
        } else if let presented = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController {
            if let nc = presented.presentingViewController as? RootNavigationController, nc.viewControllers.count > 1 {
                // modal on top of another account screen
                presented.dismiss(animated: false) {
                    self.showAccountView(currency: currency, animated: animated, completion: completion)
                }
            } else {
                presented.dismiss(animated: true) {
                    pushAccountView()
                }
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
        let alert = UIAlertController(title: S.URLHandling.addressListAlertTitle, message: S.URLHandling.addressListAlertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.URLHandling.copy, style: .default, handler: { [unowned self] _ in
            let verify = VerifyPinViewController(
                bodyText: S.URLHandling.addressListVerifyPrompt,
                pinLength: Store.state.pinLength,
                walletAuthenticator: self.keyStore) { [weak self] _ in
                    self?.copyAllAddressesToClipboard()
                    Store.perform(action: Alert.Show(.addressesCopied))
                    if let success = success, let url = URL(string: success) {
                        UIApplication.shared.open(url)
                    }
            }
            verify.transitioningDelegate = self.verifyPinTransitionDelegate
            verify.modalPresentationStyle = .overFullScreen
            verify.modalPresentationCapturesStatusBarAppearance = true
            self.topViewController?.present(verify, animated: true, completion: nil)
        }))
        topViewController?.present(alert, animated: true, completion: nil)
    }

    private func authenticateForPlatform(prompt: String, allowBiometricAuth: Bool, callback: @escaping (PlatformAuthResult) -> Void) {
        if UserDefaults.isBiometricsEnabled && allowBiometricAuth {
            keyStore.authenticate(withBiometricsPrompt: prompt, completion: { result in
                switch result {
                case .success:
                    return callback(.success(nil))
                case .cancel:
                    return callback(.cancelled)
                case .failure:
                    self.verifyPinForPlatform(prompt: prompt, callback: callback)
                case .fallback:
                    self.verifyPinForPlatform(prompt: prompt, callback: callback)
                }
            })
        } else {
            self.verifyPinForPlatform(prompt: prompt, callback: callback)
        }
    }

    private func verifyPinForPlatform(prompt: String, callback: @escaping (PlatformAuthResult) -> Void) {
        let verify = VerifyPinViewController(bodyText: prompt,
                                             pinLength: Store.state.pinLength,
                                             walletAuthenticator: keyStore,
                                             success: { pin in
                                                callback(.success(pin))
        })
        verify.didCancel = { callback(.cancelled) }
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        topViewController?.present(verify, animated: true, completion: nil)
    }
    
    private func confirmTransaction(currency: Currency, amount: Amount, fee: Amount, address: String, callback: @escaping (Bool) -> Void) {
        let confirm = ConfirmationViewController(amount: amount,
                                                 fee: fee,
                                                 feeType: .regular,
                                                 address: address,
                                                 isUsingBiometrics: false,
                                                 currency: currency)
        let transitionDelegate = PinTransitioningDelegate()
        transitionDelegate.shouldShowMaskView = true
        confirm.transitioningDelegate = transitionDelegate
        confirm.modalPresentationStyle = .overFullScreen
        confirm.modalPresentationCapturesStatusBarAppearance = true
        confirm.successCallback = {
            callback(true)
        }
        confirm.cancelCallback = {
            callback(false)
        }
        topViewController?.present(confirm, animated: true, completion: nil)
    }

    private func copyAllAddressesToClipboard() {
        guard let btcWalletManager = self.walletManagers[Currencies.btc.code] as? BTCWalletManager else { return }
        guard let wallet = btcWalletManager.wallet else { return } // TODO:BCH
        let addresses = wallet.allAddresses.filter({wallet.addressIsUsed($0)})
        UIPasteboard.general.string = addresses.joined(separator: "\n")
    }

    private var topViewController: UIViewController? {
        var viewController = window.rootViewController
        if let nc = viewController as? UINavigationController {
            viewController = nc.topViewController
        }
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

    private func showEmailLogsModal() {
        self.messagePresenter.presenter = self.topViewController
        self.messagePresenter.presentEmailLogs()
    }
    
    private func linkWallet(pairingRequest: WalletPairingRequest) {
        guard let top = topViewController else { return }
        Backend.apiClient.fetchServiceInfo(serviceID: pairingRequest.service, callback: { serviceDefinition in
            guard let serviceDefinition = serviceDefinition else { return self.showLightWeightAlert(message: "Could not retreive service definition"); }
            DispatchQueue.main.async {
                let alert = LinkWalletViewController(pairingRequest: pairingRequest, serviceDefinition: serviceDefinition)
                top.present(alert, animated: true, completion: nil)
            }
        })
    }
}

class SecurityCenterNavigationDelegate: NSObject, UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        guard let coordinator = navigationController.topViewController?.transitionCoordinator else { return }

        if coordinator.isInteractive {
            coordinator.notifyWhenInteractionChanges { context in
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
        navigationController.isNavigationBarHidden = false

        if viewController is BiometricsSettingsViewController {
            navigationController.setWhiteStyle()
        } else {
            navigationController.setDefaultStyle()
        }
    }
}
