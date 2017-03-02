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
    init(store: Store, window: UIWindow) {
        self.store = store
        self.window = window
        self.modalTransitionDelegate = ModalTransitionDelegate(store: store, type: .regular)
        addSubscriptions()
    }

    //MARK: - Private
    private let store: Store
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
            self.store.perform(action: RootModalActions.Reset())
        })
    }

    private func handleAlertChange(_ type: AlertType?) {
        guard let type = type else { return }
        presentAlert(type, completion: {
            self.store.perform(action: Alert.hide())
        })
    }

    private func presentAlert(_ type: AlertType, completion: @escaping ()->Void) {
        let alertView = AlertView(type: type)
        let size = activeWindow.bounds.size
        activeWindow.addSubview(alertView)

        let topConstraint = alertView.constraint(.top, toView: activeWindow, constant: size.height)
        alertView.constrain([
            alertView.constraint(.width, constant: size.width),
            alertView.constraint(.height, constant: alertHeight + 25.0),
            alertView.constraint(.leading, toView: activeWindow, constant: nil),
            topConstraint ])
        activeWindow.layoutIfNeeded()

        UIView.spring(0.6, animations: {
            topConstraint?.constant = size.height - self.alertHeight
            self.activeWindow.layoutIfNeeded()
        }, completion: { _ in
            alertView.animate()
            UIView.spring(0.6, delay: 2.0, animations: {
                topConstraint?.constant = size.height
                self.activeWindow.layoutIfNeeded()
            }, completion: { _ in
                completion()
                alertView.removeFromSuperview()
            })
        })
    }

    private func rootModalViewController(_ type: RootModal) -> UIViewController? {
        switch type {
        case .none:
            return nil
        case .send:
            guard let walletManager = walletManager else { return nil }
            let sendVC = SendViewController(store: store, sender: Sender(walletManager: walletManager))
            let root = ModalViewController(childViewController: sendVC)
            sendVC.presentScan = presentScan(parent: root)
            sendVC.presentVerifyPin = { callback in
                let vc = VerifyPinViewController(callback: callback)
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
            let menu = MenuViewController()
            let root = ModalViewController(childViewController: menu)
            menu.didTapSecurity = {
                self.modalTransitionDelegate.reset()
                root.dismiss(animated: true, completion: {
                    self.presentSecurityCenter()
                })
            }
            return root
        case .loginScan:
            return nil //The scan view needs a custom presentation
        case .loginAddress:
            return receiveView(isRequestAmountVisible: false)
        }
    }

    private func receiveView(isRequestAmountVisible: Bool) -> UIViewController? {
        guard let wallet = walletManager?.wallet else { return nil }
        let receiveVC = ReceiveViewController(store: store, wallet: wallet, isRequestAmountVisible: isRequestAmountVisible)
        let root = ModalViewController(childViewController: receiveVC)
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

    private func presentLoginScan() {
        guard let parent = presentingViewController else { return }
        let present = presentScan(parent: parent)
        store.perform(action: RootModalActions.Reset())
        present({ address in
            if address != nil {
                self.presentModal(.send, configuration: { modal in
                    guard let modal = modal as? ModalViewController else { return }
                    guard let child = modal.childViewController as? SendViewController else { return }
                    child.initialAddress = address
                })
            }
        })
    }

    private func presentScan(parent: UIViewController) -> PresentScan {
        return { scanCompletion in
            guard ScanViewController.isCameraAllowed else {
                //TODO - add link to settings here
                let alertController = UIAlertController(title: S.Send.cameraUnavailableTitle, message: S.Send.cameraUnavailableMessage, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
                alertController.view.tintColor = C.defaultTintColor
                parent.present(alertController, animated: true, completion: nil)
                return
            }
            let vc = ScanViewController(completion: { address in
                scanCompletion(address)
                parent.view.isFrameChangeBlocked = false
            }, isValidURI: { address in
                return address.hasPrefix("1") || address.hasPrefix("3")
            })
            parent.view.isFrameChangeBlocked = true
            parent.present(vc, animated: true, completion: {})
        }
    }

    private func presentSecurityCenter() {
        let securityCenter = SecurityCenterViewController()
        let nc = UINavigationController(rootViewController: securityCenter)
        nc.setDefaultStyle()
        nc.isNavigationBarHidden = true
        nc.delegate = securityCenterNavigationDelegate
        securityCenter.didTapPin = {
            guard let walletManager = self.walletManager else { return }
            let updatePin = UpdatePinViewController(store: self.store, walletManager: walletManager)
            nc.pushViewController(updatePin, animated: true)
        }
        securityCenter.didTapTouchId = {
            print("touchid")
        }
        securityCenter.didTapPaperKey = {
            print("paperkey")
        }

        window.rootViewController?.present(nc, animated: true, completion: nil)
    }

    //TODO - This is a total hack to grab the window that keyboard is in
    //After pin creation, the alert view needs to be presented over the keyboard
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
        if viewController is SecurityCenterViewController {
            navigationController.isNavigationBarHidden = true
        } else {
            navigationController.isNavigationBarHidden = false
        }
    }
}
