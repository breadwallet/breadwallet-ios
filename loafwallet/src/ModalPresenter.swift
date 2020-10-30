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
    var walletManager: WalletManager?
    init(store: Store, walletManager: WalletManager, window: UIWindow, apiClient: BRAPIClient) {
        self.store = store
        self.window = window
        self.walletManager = walletManager
        self.modalTransitionDelegate = ModalTransitionDelegate(type: .regular, store: store)
        self.wipeNavigationDelegate = StartNavigationDelegate(store: store)
        self.noAuthApiClient = apiClient        
        addSubscriptions()
    }

    //MARK: - Private
    private let store: Store
    private let window: UIWindow
    private let alertHeight: CGFloat = 260.0
    private let modalTransitionDelegate: ModalTransitionDelegate
    private let messagePresenter = MessageUIPresenter()
    private let securityCenterNavigationDelegate = SecurityCenterNavigationDelegate()
    private let verifyPinTransitionDelegate = TransitioningDelegate()
    private let noAuthApiClient: BRAPIClient

    private var currentRequest: PaymentRequest?
    private var reachability = ReachabilityMonitor()
    private var notReachableAlert: InAppAlert?
    private let wipeNavigationDelegate: StartNavigationDelegate

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.rootModal != $1.rootModal},
                        callback: { self.presentModal($0.rootModal) })
        store.subscribe(self,
                        selector: { $0.alert != $1.alert && $1.alert != nil },
                        callback: { self.handleAlertChange($0.alert) })
        
        store.subscribe(self, name: .openFile(Data()), callback: {
            guard let trigger = $0 else { return }
            if case .openFile(let file) = trigger {
                self.handleFile(file)
            }
        })
        
        //Subscribe to prompt actions
        store.subscribe(self, name: .promptUpgradePin, callback: { _ in
            self.presentUpgradePin()
        })
        store.subscribe(self, name: .promptPaperKey, callback: { _ in
            self.presentWritePaperKey()
        })
        store.subscribe(self, name: .promptBiometrics, callback: { _ in
            self.presentBiometricsSetting()
        })
        store.subscribe(self, name: .promptShareData, callback: { _ in
            self.promptShareData()
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
            } else {
                self.showNotReachable()
            }
        }
        store.subscribe(self, name: .lightWeightAlert(""), callback: {
            guard let trigger = $0 else { return }
            if case let .lightWeightAlert(message) = trigger {
                self.showLightWeightAlert(message: message)
            }
        })
        store.subscribe(self, name: .showAlert(nil), callback: {
            guard let trigger = $0 else { return }
            if case let .showAlert(alert) = trigger {
                if let alert = alert {
                    self.topViewController?.present(alert, animated: true, completion: nil)
                }
            }
        })
    }
    
    //MARK: - Prompts
    private func presentRescan() {
        let vc = ReScanViewController(store: self.store)
        let nc = UINavigationController(rootViewController: vc)
        nc.setClearNavbar()
        vc.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }
    
    func presentBiometricsSetting() {
        guard let walletManager = walletManager else { return }
        let biometricsSettings = BiometricsSettingsViewController(walletManager: walletManager, store: store)
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
        let shareData = ShareDataViewController(store: store)
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
        guard let walletManager = walletManager else { return }
        let updatePin = UpdatePinViewController(store: store, walletManager: walletManager, type: .update)
        let nc = ModalNavigationController(rootViewController: updatePin)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        updatePin.addCloseNavigationItem()
        topViewController?.present(nc, animated: true, completion: nil)
    }
     
    private func presentModal(_ type: RootModal, configuration: ((UIViewController) -> Void)? = nil) {
        guard type != .loginScan else { return presentLoginScan() }
        guard let vc = rootModalViewController(type) else {
            self.store.perform(action: RootModalActions.Present(modal: .none))
            return
        }
        vc.transitioningDelegate = modalTransitionDelegate
        vc.modalPresentationStyle = .overFullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        configuration?(vc)
        topViewController?.present(vc, animated: true, completion: {
            self.store.perform(action: RootModalActions.Present(modal: .none))
            self.store.trigger(name: .hideStatusBar)
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

    private func presentWebView(_ mountPoint: String) {
        guard let walletManager = self.walletManager else { return }
        let vc = WebViewContainer(mountPoint: mountPoint, walletManager: walletManager, store: store, apiClient: self.noAuthApiClient)
        
        vc.modalPresentationStyle = .overFullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        vc.transitioningDelegate = vc 
        topViewController?.present(vc, animated: true, completion: {})
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
        case .wipeEmptyWallet:
            return wipeEmptyView()
        case .requestAmount:
            guard let wallet = walletManager?.wallet else { return nil }
            let requestVc = RequestAmountViewController(wallet: wallet, store: store)
            requestVc.presentEmail = { [weak self] bitcoinURL, image in
                self?.messagePresenter.presenter = self?.topViewController
                self?.messagePresenter.presentMailCompose(bitcoinURL: bitcoinURL, image: image)
            }
            requestVc.presentText = { [weak self] bitcoinURL, image in
                self?.messagePresenter.presenter = self?.topViewController
                self?.messagePresenter.presentMessageCompose(bitcoinURL: bitcoinURL, image: image)
            }
            return ModalViewController(childViewController: requestVc, store: store)
        }
      
    }
    private func wipeEmptyView() -> UIViewController? {
      
      guard let walletManager = walletManager else { return nil }

      let wipeEmptyvc = WipeEmptyWalletViewController(walletManager: walletManager, store: store, didTapNext: ({ [weak self] in
        guard let myself = self else { return }
        myself.wipeWallet()
      }))
      return ModalViewController(childViewController: wipeEmptyvc, store: store)
    }

    private func makeSendView() -> UIViewController? {
        guard !store.state.walletState.isRescanning else {
            let alert = UIAlertController(title: S.Alert.error, message: S.Send.isRescanning, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
            topViewController?.present(alert, animated: true, completion: nil)
            return nil
        }
        guard let walletManager = walletManager else { return nil }
        guard let kvStore = walletManager.apiClient?.kv else { return nil }
 
        let sendVC = SendViewController(store: store, sender: Sender(walletManager: walletManager, kvStore: kvStore, store: store),  walletManager: walletManager, initialRequest: currentRequest)
        currentRequest = nil

        if store.state.isLoginRequired {
            sendVC.isPresentedFromLock = true
        }

        let root = ModalViewController(childViewController: sendVC, store: store)
        sendVC.presentScan = presentScan(parent: root)
        sendVC.presentVerifyPin = { [weak self, weak root] bodyText, callback in
            guard let myself = self else { return }
            let vc = VerifyPinViewController(bodyText: bodyText, pinLength: myself.store.state.pinLength, callback: callback)
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
        guard let wallet = walletManager?.wallet else { return nil }
        let receiveVC = ReceiveViewController(wallet: wallet, store: store, isRequestAmountVisible: isRequestAmountVisible)
        let root = ModalViewController(childViewController: receiveVC, store: store)
        receiveVC.presentEmail = { [weak self, weak root] address, image in
            guard let root = root else { return }
            self?.messagePresenter.presenter = root
            self?.messagePresenter.presentMailCompose(litecoinAddress: address, image: image)
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
                self?.messagePresenter.presenter = self?.topViewController
                self?.messagePresenter.presentSupportCompose()
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
        let sections = ["About", "Wallet", "Manage", "Support", "Blockchain"]
        let rows = [
            "About": [Setting(title: S.Settings.litewalletVersion, accessoryText: { [weak self] in
                        return AppVersion.string
                        }, callback: {}),
                      Setting(title: S.Settings.litewalletEnvironment, accessoryText: { [weak self] in
                        var envName = "Release"
                        #if Debug || Testflight
                            envName = "Debug" 
                        #endif
                        return envName
                      }, callback: {}),
                      Setting(title: S.Settings.socialLinks, callback: {
                          settingsNav.pushViewController(AboutViewController(), animated: true)
                      })
            ],
            "Wallet": [Setting(title: S.Settings.importTile, callback: { [weak self] in
                    guard let myself = self else { return }
                    guard let walletManager = myself.walletManager else { return }
                    let importNav = ModalNavigationController()
                    importNav.setClearNavbar()
                    importNav.setWhiteStyle()
                    let start = StartImportViewController(walletManager: walletManager, store: myself.store)
                    start.addCloseNavigationItem(tintColor: .white)
                    start.navigationItem.title = S.Import.title
                    importNav.viewControllers = [start]
                    settingsNav.dismiss(animated: true, completion: {
                        myself.topViewController?.present(importNav, animated: true, completion: nil)
                    })
                }),
               Setting(title: S.Settings.wipe, callback: { [weak self] in
                    guard let myself = self else { return }
                    guard let walletManager = myself.walletManager else { return }
                    let nc = ModalNavigationController()
                    nc.setClearNavbar()
                    nc.setWhiteStyle()
                    nc.delegate = myself.wipeNavigationDelegate
                    let start = StartWipeWalletViewController {
                        let recover = EnterPhraseViewController(store: myself.store, walletManager: walletManager, reason: .validateForWipingWallet( {
                            myself.wipeWallet()
                        }))
                        nc.pushViewController(recover, animated: true)
                    }
                    start.addCloseNavigationItem(tintColor: .white)
                    start.navigationItem.title = S.WipeWallet.title
                    nc.viewControllers = [start]
                    settingsNav.dismiss(animated: true, completion: {
                        myself.topViewController?.present(nc, animated: true, completion: nil)
                    })
               }),
            ],
            "Manage": [
                Setting(title: S.Settings.languages, callback: strongify(self) { _ in
                    UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!)
                }),
                Setting(title: LAContext.biometricType() == .face ? S.Settings.faceIdLimit : S.Settings.touchIdLimit, accessoryText: { [weak self] in
                    guard let myself = self else { return "" }
                    guard let rate = myself.store.state.currentRate else { return "" }
                    let amount = Amount(amount: walletManager.spendingLimit, rate: rate, maxDigits: myself.store.state.maxDigits)
                    return amount.localCurrency
                }, callback: {
                    self.pushBiometricsSpendingLimit(onNc: settingsNav)
                }),
                Setting(title: S.Settings.currency, accessoryText: {
                    let code = self.store.state.defaultCurrencyCode
                    let components: [String : String] = [NSLocale.Key.currencyCode.rawValue : code]
                    let identifier = Locale.identifier(fromComponents: components)
                    return Locale(identifier: identifier).currencyCode ?? ""
                }, callback: {
                    guard let wm = self.walletManager else { print("NO WALLET MANAGER!"); return }
                    settingsNav.pushViewController(DefaultCurrencyViewController(walletManager: wm, store: self.store), animated: true)
                }),
                Setting(title: S.Settings.sync, callback: {
                    settingsNav.pushViewController(ReScanViewController(store: self.store), animated: true)
                }),
                Setting(title: S.UpdatePin.updateTitle, callback: strongify(self) { myself in
                    let updatePin = UpdatePinViewController(store: myself.store, walletManager: walletManager, type: .update)
                    settingsNav.pushViewController(updatePin, animated: true)
                })
            ],
            "Support": [
                Setting(title: S.Settings.shareData, callback: {
                    settingsNav.pushViewController(ShareDataViewController(store: self.store), animated: true)
                })
            ],
            "Blockchain": [
                Setting(title:S.Settings.advancedTitle, callback: { [weak self] in
                    guard let myself = self else { return }
                    guard let walletManager = myself.walletManager else { return }
                    let sections = ["Network"]
                    var networkRows = [Setting]()
                    networkRows = [Setting(title: "Litecoin Nodes", callback: {
                        let nodeSelector = NodeSelectorViewController(walletManager: walletManager)
                        settingsNav.pushViewController(nodeSelector, animated: true)
                    })]
                    
// TODO: Develop this feature for issues with the TXID
//                    if UserDefaults.didSeeCorruption {
//                        networkRows.append(
//                            Setting(title: S.WipeWallet.deleteDatabase, callback: {
//                                self?.deleteDatabase()
//                            })
//                        )
//                    }

                    let advancedSettings = ["Network": networkRows]
                    let advancedSettingsVC = SettingsViewController(sections: sections, rows: advancedSettings, optionalTitle: S.Settings.advancedTitle)
                    settingsNav.pushViewController(advancedSettingsVC, animated: true)
                })
            ]
        ]
    
        let settings = SettingsViewController(sections: sections, rows: rows)
        settings.addCloseNavigationItem()
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
        securityCenter.didTapBiometrics = strongify(self) { myself in
            let biometricsSettings = BiometricsSettingsViewController(walletManager: walletManager, store: myself.store)
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
        guard let walletManager = walletManager else { return }

        let verify = VerifyPinViewController(bodyText: S.VerifyPin.continueBody, pinLength: store.state.pinLength, callback: { [weak self] pin, vc in
            guard let myself = self else { return false }
            if walletManager.authenticate(pin: pin) {
                vc.dismiss(animated: true, completion: {
                    let spendingLimit = BiometricsSpendingLimitViewController(walletManager: walletManager, store: myself.store)
                    onNc.pushViewController(spendingLimit, animated: true)
                })
                return true
            } else {
                return false
            }
        })
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        onNc.present(verify, animated: true, completion: nil)
    }

    private func presentWritePaperKey(fromViewController vc: UIViewController) {
        guard let walletManager = walletManager else { return }
        let paperPhraseNavigationController = UINavigationController()
        paperPhraseNavigationController.setClearNavbar()
        paperPhraseNavigationController.setWhiteStyle()
        paperPhraseNavigationController.modalPresentationStyle = .overFullScreen
        let start = StartPaperPhraseViewController(store: store, callback: { [weak self] in
            guard let myself = self else { return }
            let verify = VerifyPinViewController(bodyText: S.VerifyPin.continueBody, pinLength: myself.store.state.pinLength, callback: { pin, vc in
                if walletManager.authenticate(pin: pin) {
                    var write: WritePaperPhraseViewController?
                    write = WritePaperPhraseViewController(store: myself.store, walletManager: walletManager, pin: pin, callback: { [weak self] in
                        guard let myself = self else { return }
                        let confirmVC = UIStoryboard.init(name: "Phrase", bundle: nil).instantiateViewController(withIdentifier: "ConfirmPaperPhraseViewController") as? ConfirmPaperPhraseViewController
                        confirmVC?.store = myself.store
                        confirmVC?.walletManager = myself.walletManager
                        confirmVC?.pin = pin
                        confirmVC?.didCompleteConfirmation = {
                            confirmVC?.dismiss(animated: true, completion: {
                                myself.store.perform(action: Alert.Show(.paperKeySet(callback: {
                                    myself.store.perform(action: HideStartFlow())
                                    
                                })))
                            })
                        }
                        //write?.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
                        if let confirm = confirmVC {
                            paperPhraseNavigationController.pushViewController(confirm, animated: true)
                        }
                    })
                    write?.hideCloseNavigationItem()
                   /// write?.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle

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
        start.navigationItem.title = S.SecurityCenter.Cells.paperKeyTitle
        
        
        var staticColor = UIColor()
        
        if #available(iOS 11.0, *),
            let tempStaticColor = UIColor(named: "staticWhiteColor") {
            staticColor = tempStaticColor
        } else {
            staticColor = .whiteTint
        }
        
        if UserDefaults.writePaperPhraseDate != nil {
            start.addCloseNavigationItem(tintColor: staticColor)
        } else {
            start.hideCloseNavigationItem()
        }
        
        paperPhraseNavigationController.viewControllers = [start]
        vc.present(paperPhraseNavigationController, animated: true, completion: nil)
    }
 

    private func wipeWallet() {
        let group = DispatchGroup()
        let alert = UIAlertController(title: S.WipeWallet.alertTitle, message: S.WipeWallet.alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: S.WipeWallet.wipe, style: .default, handler: { _ in
            self.topViewController?.dismiss(animated: true, completion: {
                let activity = BRActivityViewController(message: S.WipeWallet.wiping)
                self.topViewController?.present(activity, animated: true, completion: nil)
                
                group.enter()
                DispatchQueue.walletQueue.async {
                    self.walletManager?.peerManager?.disconnect()
                    group.leave()
                }
                
                group.enter()
                DispatchQueue.walletQueue.asyncAfter(deadline: .now() + 2.0) {
                    print("Pausing to show 'Wiping' Dialog")
                    group.leave()
                }
               
                group.notify(queue: .main) {
                    if let canForceWipeWallet = (self.walletManager?.wipeWallet(pin: "forceWipe")),
                        canForceWipeWallet {
                       self.store.trigger(name: .reinitWalletManager({
                         activity.dismiss(animated: true, completion: {})
                       }))
                    } else {
                       let failure = UIAlertController(title: S.WipeWallet.failedTitle, message: S.WipeWallet.failedMessage, preferredStyle: .alert)
                       failure.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
                       self.topViewController?.present(failure, animated: true, completion: nil)
                    }
                }
            })
        }))
        topViewController?.present(alert, animated: true, completion: nil)
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

        if topViewController is MainViewController {
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

        if topViewController is MainViewController || topViewController is LoginViewController {
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
            guard let myself = self else { return }
            let verify = VerifyPinViewController(bodyText: S.URLHandling.addressListVerifyPrompt, pinLength: myself.store.state.pinLength, callback: { [weak self] pin, view in
                if walletManager.authenticate(pin: pin) {
                    self?.copyAllAddressesToClipboard()
                    view.dismiss(animated: true, completion: {
                        self?.store.perform(action: Alert.Show(.addressesCopied))
                        if let success = success, let url = URL(string: success) {
                          UIApplication.shared.open(url, options: [:], completionHandler: nil)
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

    private func authenticateForBitId(prompt: String, callback: @escaping (BitIdAuthResult) -> Void) {
        if UserDefaults.isBiometricsEnabled {
            walletManager?.authenticate(biometricsPrompt: prompt, completion: { result in
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
        guard let walletManager = walletManager else { return }
        let verify = VerifyPinViewController(bodyText: prompt, pinLength: store.state.pinLength, callback: { pin, view in
            if walletManager.authenticate(pin: pin) {
                view.dismiss(animated: true, completion: {
                    callback(.success)
                })
                return true
            } else {
                return false
            }
        })
        verify.didCancel = { callback(.cancelled) }
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
