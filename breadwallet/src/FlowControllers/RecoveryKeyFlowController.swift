//
//  RecoveryKeyFlowController.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-03-18.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

// Modes in which the the user can enter the recover key flow.
enum EnterRecoveryKeyMode {
    // User is generating the key for the first time.
    case generateKey
    
    // User entering the recovery key flow to write down the key.
    case writeKey
    
    // User is wiping the wallet from the device, which requires entry of the recovery key.
    case unlinkWallet
}

enum ExitRecoveryKeyAction {
    case generateKey
    case writeKey
    case confirmKey
    case unlinkWallet
    case abort
}

//
// Manages entry points for generating or writing down the paper key:
//
//  - new-user onboarding
//  - home screen prompt or security settings menu
//  - unlinking a wallet
//  - resetting the login PIN
//
class RecoveryKeyFlowController {
    
    private static let pinTransitionDelegate = PinTransitioningDelegate()
    
    //
    // Entry point into the recovery key flow.
    //
    // pin - the user's PIN, which will already be set to a valid pin if entering from the onboarding flow
    // keyMaster - used for obtaining the recovery key phrase words
    // viewController - the view controller that is initiating the recovery key flow
    // context - event context for logging analytics events
    // dismissAction - a custom dismiss action
    // modalPresentation - whether the recovery key flow should be presented as a modal view controller
    // canExit - whether the user can exit the recovery key flow; when entering from onboarding,
    //          this is 'false' to ensure the user sees the first few intro pages of the flow
    //
    static func enterRecoveryKeyFlow(pin: String?,
                                     keyMaster: KeyMaster,
                                     from viewController: UIViewController,
                                     context: EventContext,
                                     dismissAction: (() -> Void)?,
                                     modalPresentation: Bool = true,
                                     canExit: Bool = true) {
        
        let isGeneratingKey = UserDefaults.walletRequiresBackup
        let recoveryKeyMode: EnterRecoveryKeyMode = isGeneratingKey ? .generateKey : .writeKey
        let eventContext = (context == .none) ? (isGeneratingKey ? .generateKey : .writeKey) : context

        // Register the context so that the recovery key events are tracked, with the correct context.
        // When the flow is dismissed,
        EventMonitor.shared.register(eventContext)
        
        let recoveryKeyNavController = RecoveryKeyFlowController.makeNavigationController()
        
        var baseNavigationController: UINavigationController?
        var modalPresentingViewController: UIViewController?
        
        // Sort out how we should be presenting the recovery key flow. If it's dipslayed from the home
        // screen prompt or the security settings menu, it's modal. If it's displayed from the onboarding flow,
        // we're already in a modal navigation controller so the recovery key flow is pushed.
        if modalPresentation {
            modalPresentingViewController = viewController
        } else if let nc = viewController as? UINavigationController {
            baseNavigationController = nc
        }
        
        var exitButtonType: RecoveryKeyIntroExitButtonType = .none
        if canExit {
            exitButtonType = modalPresentation ? .closeButton : .backButton
        }
        
        // dismisses the entire recovery key flow
        let dismissFlow = {
            
            EventMonitor.shared.deregister(eventContext)
            
            if let dismissAction = dismissAction {
                dismissAction()
            } else {
                if modalPresentation {
                    modalPresentingViewController?.dismiss(animated: true, completion: nil)
                } else {
                    baseNavigationController?.dismiss(animated: true, completion: nil)
                }
            }
        }
        
        // pushes the next view controller in the flow
        let pushNext: ((UIViewController) -> Void) = { (next) in
            if modalPresentation {
                recoveryKeyNavController.pushViewController(next, animated: true)
            } else {
                baseNavigationController?.pushViewController(next, animated: true)
            }
        }
        
        // invoked when the user leaves the write-recovery-key view controller
        let handleWriteKeyResult: ((ExitRecoveryKeyAction, [String]) -> Void) = { (action, words) in
            switch action {
            case .abort:
                dismissFlow()
            case .confirmKey:
                
                let fromOnboarding = (context == .onboarding)
                let goToWallet = (context == .onboarding) ? dismissFlow : nil
                
                pushNext(ConfirmRecoveryKeyViewController(words: words,
                                                          keyMaster: keyMaster,
                                                          eventContext: eventContext,
                                                          confirmed: {
                                                            pushNext(RecoveryKeyCompleteViewController(fromOnboarding: fromOnboarding, proceedToWallet: goToWallet))
                }))
            default:
                break
            }
        }
        
        // the landing page for setting up the recovery key.
        let introVC = RecoveryKeyIntroViewController(mode: recoveryKeyMode,
                                                     eventContext: eventContext,
                                                     exitButtonType: exitButtonType,
                                                     exitCallback: { (exitAction) in
            switch exitAction {
            case .generateKey:
                self.ensurePinAvailable(pin: pin,
                                        navigationController: recoveryKeyNavController,
                                        keyMaster: keyMaster,
                                        pinResponse: { (responsePin) in
                                            
                                            guard let phrase = keyMaster.seedPhrase(pin: responsePin) else { return }
                                            
                                            pushNext(WriteRecoveryKeyViewController(keyMaster: keyMaster,
                                                                                    pin: responsePin,
                                                                                    mode: recoveryKeyMode,
                                                                                    eventContext: eventContext,
                                                                                    dismissAction: dismissAction,
                                                                                    exitCallback: { (action) in
                                                                                        let words = phrase.components(separatedBy: " ")
                                                                                        handleWriteKeyResult(action, words)
                                            }))
                })

            case .writeKey:
                break
                
            case .abort:
                
                // The onboarding flow has its own dismiss action.
                if let dismissAction = dismissAction {
                    dismissAction()
                } else {
                    modalPresentingViewController?.dismiss(animated: true, completion: nil)
                }
                
            default:
                break
            }
        })
        
        if modalPresentation {
            recoveryKeyNavController.viewControllers = [introVC]
            modalPresentingViewController?.present(recoveryKeyNavController, animated: true, completion: nil)
        } else {
            baseNavigationController?.navigationItem.hidesBackButton = true
            baseNavigationController?.pushViewController(introVC, animated: true)
        }
    }
    
    static func enterUnlinkWalletFlow(from viewController: UIViewController,
                                      keyMaster: KeyMaster,
                                      phraseEntryReason: PhraseEntryReason) {

        let navController = RecoveryKeyFlowController.makeNavigationController()

        let enterPhrase: (() -> Void) = {
            let enterPhraseVC = EnterPhraseViewController(keyMaster: keyMaster, reason: phraseEntryReason)
            navController.pushViewController(enterPhraseVC, animated: true)
        }
        
        let introVC = RecoveryKeyIntroViewController(mode: .unlinkWallet,
                                                     eventContext: .none,
                                                     exitButtonType: .closeButton,
                                                     exitCallback: { (action) in
                                                        if action == .unlinkWallet {
                                                            enterPhrase()
                                                        } else if action == .abort {
                                                            navController.dismiss(animated: true, completion: nil)
                                                        }
        })

        navController.viewControllers = [introVC]
        viewController.present(navController, animated: true, completion: nil)
    }
    
    static func enterResetPinFlow(from viewController: UIViewController,
                                  keyMaster: KeyMaster,
                                  callback: @escaping ((String, UINavigationController) -> Void)) {
    
        let navController = RecoveryKeyFlowController.makeNavigationController()
        
        let enterPhraseVC = EnterPhraseViewController(keyMaster: keyMaster, reason: .validateForResettingPin({ (phrase) in
            callback(phrase, navController)
        }))

        navController.viewControllers = [enterPhraseVC]
        
        viewController.present(navController, animated: true, completion: nil)
    }
    
    static func promptToSetUpRecoveryKeyLater(from viewController: UIViewController, setUpLater: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: S.RecoverKeyFlow.exitRecoveryKeyPromptTitle,
                                      message: S.RecoverKeyFlow.exitRecoveryKeyPromptBody,
                                      preferredStyle: .alert)
        
        let no = UIAlertAction(title: S.Button.no, style: .default, handler: nil)
        let yes = UIAlertAction(title: S.Button.yes, style: .default) { _ in
            setUpLater(true)
        }
        
        alert.addAction(no)
        alert.addAction(yes)
        
        viewController.present(alert, animated: true, completion: nil)
    }
    
    private static func makeNavigationController() -> UINavigationController {
        let navController = UINavigationController()
        navController.setClearNavbar()
        navController.setWhiteStyle()
        navController.modalPresentationStyle = .overFullScreen
        return navController
    }
    
    private static func ensurePinAvailable(pin: String?,
                                           navigationController: UINavigationController,
                                           keyMaster: KeyMaster,
                                           pinResponse: @escaping (String) -> Void) {
        
        // If the pin was already available, just call back with it.
        if let pin = pin, !pin.isEmpty {
            pinResponse(pin)
            return
        }
        
        let pinViewController = VerifyPinViewController(bodyText: S.VerifyPin.continueBody,
                                                        pinLength: Store.state.pinLength,
                                                        walletAuthenticator: keyMaster,
                                                        pinAuthenticationType: .recoveryKey,
                                                        success: { pin in
                                                            pinResponse(pin)
        })
        
        pinViewController.transitioningDelegate = RecoveryKeyFlowController.pinTransitionDelegate
        pinViewController.modalPresentationStyle = .overFullScreen
        pinViewController.modalPresentationCapturesStatusBarAppearance = true
        
        navigationController.present(pinViewController, animated: true, completion: nil)
    }
}
