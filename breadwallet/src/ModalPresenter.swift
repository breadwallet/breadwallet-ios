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
    var walletManager: WalletManager?
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

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.pinCreationStep != $1.pinCreationStep },
                        callback: { self.handlePinCreationStateChange($0) })
        store.subscribe(self,
                        selector: { $0.paperPhraseStep != $1.paperPhraseStep },
                        callback: { self.handlePaperPhraseStateChange($0) })
        store.subscribe(self,
                        selector: { $0.rootModal != $1.rootModal},
                        callback: { self.presentModal($0.rootModal) })
        store.subscribe(self,
                        selector: { $0.alert != $1.alert && $1.alert != nil },
                        callback: { self.handleAlertChange($0.alert) })
        store.subscribe(self, name: .presentFaq, callback: {
            self.presentFaq()
        })
    }

    private func handlePinCreationStateChange(_ state: State) {
        if case .saveSuccess = state.pinCreationStep {
            self.presentAlert(.pinSet) {
                self.store.perform(action: PaperPhrase.Start())
            }
        }
    }

    private func handlePaperPhraseStateChange(_ state: State) {
        if case .confirmed = state.paperPhraseStep {
            self.presentAlert(.paperKeySet) {
                self.store.perform(action: HideStartFlow())
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
        presentingViewController?.present(vc, animated: true, completion: {
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
        let window = type == .sendSuccess ? UIApplication.shared.keyWindow! : activeWindow
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
                completion()
                alertView.removeFromSuperview()
            })
        })
    }

    private func presentFaq() {
        guard let walletManager = walletManager else { return }
        let webView = BRWebViewController(bundleName: "test", walletManager: walletManager)
        presentingViewController?.present(webView, animated: true, completion: {})
    }

    private func rootModalViewController(_ type: RootModal) -> UIViewController? {
        switch type {
        case .none:
            return nil
        case .send:
            guard let walletManager = walletManager else { return nil }
            let sendVC = SendViewController(store: store, sender: Sender(walletManager: walletManager))
            let root = ModalViewController(childViewController: sendVC, store: store)
            sendVC.presentScan = presentScan(parent: root)
            sendVC.presentVerifyPin = { callback in
                let vc = VerifyPinViewController(callback: callback)
                vc.modalPresentationStyle = .overFullScreen
                root.view.isFrameChangeBlocked = true
                root.present(vc, animated: true, completion: nil)
            }
            sendVC.onPublishSuccess = {
                self.presentAlert(.sendSuccess, completion: {})
            }
            sendVC.onPublishFailure = {
                self.presentAlert(.sendFailure, completion: {})
            }
            return root
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
        }
    }

    private func receiveView(isRequestAmountVisible: Bool) -> UIViewController? {
        guard let wallet = walletManager?.wallet else { return nil }
        let receiveVC = ReceiveViewController(store: store, wallet: wallet, isRequestAmountVisible: isRequestAmountVisible)
        let root = ModalViewController(childViewController: receiveVC, store: store)
        receiveVC.presentEmail = { address, image in
            self.messagePresenter.presenter = root
            self.messagePresenter.presentMailCompose(address: address, image: image)
        }
        receiveVC.presentText = { address, image in
            self.messagePresenter.presenter = root
            self.messagePresenter.presentMessageCompose(address: address, image: image)
        }
        return root
    }

    private func menuViewController() -> UIViewController? {
        let menu = MenuViewController()
        let root = ModalViewController(childViewController: menu, store: store)
        menu.didTapSecurity = { [weak self] in
            self?.modalTransitionDelegate.reset()
            root.dismiss(animated: true) {
                self?.presentSecurityCenter()
            }
        }
        menu.didTapLock = { [weak self] in
            menu.dismiss(animated: true) {
                self?.store.perform(action: RequireLogin())
            }
        }
        menu.didTapSettings = { [weak self] in
            menu.dismiss(animated: true) {
                self?.presentSettings()
            }
        }
        return root
    }

    private func presentLoginScan() {
        guard let parent = presentingViewController else { return }
        let present = presentScan(parent: parent)
        store.perform(action: RootModalActions.Present(modal: .none))
        present({ paymentRequest in
            if paymentRequest != nil {
                self.presentModal(.send, configuration: { modal in
                    guard let modal = modal as? ModalViewController else { return }
                    guard let child = modal.childViewController as? SendViewController else { return }
                    child.initialAddress = paymentRequest?.toAddress
                })
            }
        })
    }

    private func presentSettings() {
        guard let parent = presentingViewController else { return }
        guard let walletManager = self.walletManager else { return }

        let nc = UINavigationController()
        let sections = ["Wallet", "Manage", "Bread"]
        let rows = [
            "Wallet": [Setting(title: S.Settings.importTile, callback: {})],
            "Manage": [
                Setting(title: S.Settings.notifications, accessoryText: {
                    return "Off"
                }, callback: {
                    nc.pushViewController(PushNotificationsViewController(store: self.store), animated: true)
                }),
                Setting(title: S.Settings.touchIdLimit, accessoryText: {
                    guard let rate = self.store.state.currentRate else { return "" }
                    let amount = Amount(amount: walletManager.spendingLimit, rate: rate.rate)
                    return amount.localCurrency
                }, callback: {
                    nc.pushViewController(TouchIdSpendingLimitViewController(walletManager: walletManager, store: self.store), animated: true)
                }),
                Setting(title: S.Settings.currency, accessoryText: {
                    let code = self.store.state.defaultCurrency
                    let components: [String : String] = [NSLocale.Key.currencyCode.rawValue : code]
                    let identifier = Locale.identifier(fromComponents: components)
                    return Locale(identifier: identifier).currencyCode ?? ""
                }, callback: {
                    nc.pushViewController(DefaultCurrencyViewController(apiClient: self.apiClient, store: self.store), animated: true)
                }),
                Setting(title: S.Settings.sync, callback: {
                    nc.pushViewController(ReScanViewController(store: self.store), animated: true)
                }),
            ],
            "Bread": [
                Setting(title: S.Settings.shareData, callback: {

                }),
                Setting(title: S.Settings.buyBitcoin, callback: {

                }),
                Setting(title: S.Settings.about, callback: {
                    nc.pushViewController(AboutViewController(), animated: true)
                }),
            ]
        ]

        let settings = SettingsViewController(sections: sections, rows: rows)
        nc.viewControllers = [settings]
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        view.backgroundColor = .whiteTint
        nc.navigationBar.setBackgroundImage(view.imageRepresentation, for: .default)
        nc.navigationBar.shadowImage = UIImage()
        nc.navigationBar.isTranslucent = false
        nc.setBlackBackArrow()
        parent.present(nc, animated: true, completion: nil)
    }

    private func presentScan(parent: UIViewController) -> PresentScan {
        return { scanCompletion in
            guard ScanViewController.isCameraAllowed else {
                let alertController = UIAlertController(title: S.Send.cameraUnavailableTitle, message: S.Send.cameraUnavailableMessage, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
                alertController.addAction(UIAlertAction(title: S.Button.settings, style: .`default`, handler: { _ in
                    if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
                        UIApplication.shared.openURL(appSettings)
                    }
                }))
                alertController.view.tintColor = C.defaultTintColor
                parent.present(alertController, animated: true, completion: nil)
                return
            }
            let vc = ScanViewController(completion: { address in
                scanCompletion(address)
                parent.view.isFrameChangeBlocked = false
            }, isValidURI: { address in
                return address.isValidAddress
            })
            parent.view.isFrameChangeBlocked = true
            parent.present(vc, animated: true, completion: {})
        }
    }

    private func presentSecurityCenter() {
        guard let walletManager = walletManager else { return }
        let securityCenter = SecurityCenterViewController(store: store)
        let nc = ModalNavigationController(rootViewController: securityCenter)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        securityCenter.didTapPin = { [weak self] in
            guard let myself = self else { return }
            let updatePin = UpdatePinViewController(store: myself.store, walletManager: walletManager)
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
        securityCenter.didTapPaperKey = {
            print("paperkey")
        }

        window.rootViewController?.present(nc, animated: true, completion: nil)
    }

    //TODO - This is a total hack to grab the window that keyboard is in
    //After pin creation, the alert view needs to be presented over the keyboard
    //TODO - Phase this out once all pin creation view use custom pinpad
    private var activeWindow: UIWindow {
        let windowsCount = UIApplication.shared.windows.count
        if let keyboardWindow = UIApplication.shared.windows.last, windowsCount > 1 {
            return keyboardWindow
        }
        return window
    }

    private var presentingViewController: UIViewController? {
        if window.rootViewController?.presentedViewController != nil {
            return window.rootViewController?.presentedViewController
        } else if window.rootViewController != nil {
            return window.rootViewController
        } else {
            return nil
        }
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
