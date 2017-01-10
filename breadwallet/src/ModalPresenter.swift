//
//  AlertCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ModalPresenter: Subscriber {

    init(store: Store, window: UIWindow, wallet: BRWallet) {
        self.store = store
        self.window = window
        self.wallet = wallet
        self.modalTransitionDelegate = ModalTransitionDelegate(store: store)
        addSubscriptions()
    }

    private let store: Store
    private let window: UIWindow
    private let wallet: BRWallet
    private let alertHeight: CGFloat = 260.0
    private let modalTransitionDelegate: ModalTransitionDelegate
    private let messagePresenter = MessageUIPresenter()

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

    private func presentModal(_ type: RootModal) {
        guard let vc = rootModalViewController(type) else { return }
        vc.transitioningDelegate = modalTransitionDelegate
        vc.modalPresentationStyle = .overFullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        window.rootViewController?.present(vc, animated: true, completion: {
            self.store.perform(action: RootModalActions.Reset())
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
                topConstraint
            ])
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
            let sendVC = SendViewController(store: store)
            let root = ModalViewController(childViewController: sendVC)
            sendVC.presentScan = presentScan(parent: root)
            return root
        case .receive:
            let receiveVC = ReceiveViewController(store: store, wallet: wallet)
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
        case .menu:
            return ModalViewController(childViewController: MenuViewController())
        }
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
                return address.hasPrefix("bitcoin:")
            })
            parent.view.isFrameChangeBlocked = true
            parent.present(vc, animated: true, completion: {})
        }
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
}
