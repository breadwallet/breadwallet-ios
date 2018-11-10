//
//  Prompt.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

enum PromptType {
    case biometrics
    case paperKey
    case upgradePin
    case noPasscode
    case email

    static var defaultOrder: [PromptType] = {
        return [.upgradePin, .paperKey, .noPasscode, .biometrics, .email]
    }()
    
    static func nextPrompt(walletManager: BTCWalletManager) -> PromptType? {
        return defaultOrder.first(where: { $0.shouldPrompt(walletManager: walletManager) })
    }

    var title: String {
        switch self {
        case .biometrics: return LAContext.biometricType() == .face ? S.Prompts.FaceId.title : S.Prompts.TouchId.title
        case .paperKey: return S.Prompts.PaperKey.title
        case .upgradePin: return S.Prompts.UpgradePin.title
        case .noPasscode: return S.Prompts.NoPasscode.title
        case .email: return S.Prompts.Email.title
        }
    }
    
    var name: String {
        switch self {
        case .biometrics: return "biometricsPrompt"
        case .paperKey: return "paperKeyPrompt"
        case .upgradePin: return "upgradePinPrompt"
        case .noPasscode: return "noPasscodePrompt"
        case .email: return "emailPrompt"
        }
    }

    var body: String {
        switch self {
        case .biometrics: return LAContext.biometricType() == .face ? S.Prompts.FaceId.body : S.Prompts.TouchId.body
        case .paperKey: return S.Prompts.PaperKey.body
        case .upgradePin: return S.Prompts.UpgradePin.body
        case .noPasscode: return S.Prompts.NoPasscode.body
        case .email: return S.Prompts.Email.body
        }
    }

    // This is the trigger that happens when the prompt is tapped
    func trigger(currency: CurrencyDef) -> TriggerName? {
        switch self {
        case .biometrics: return .promptBiometrics
        case .paperKey: return .promptPaperKey
        case .upgradePin: return .promptUpgradePin
        case .noPasscode: return nil
        case .email: return .promptEmail
        }
    }

    func shouldPrompt(walletManager: BTCWalletManager) -> Bool {
        switch self {
        case .biometrics:
            return !UserDefaults.hasPromptedBiometrics && LAContext.canUseBiometrics && !UserDefaults.isBiometricsEnabled
        case .paperKey:
            return UserDefaults.walletRequiresBackup
        case .upgradePin:
            return walletManager.pinLength != 6
        case .noPasscode:
            return !LAContext.isPasscodeEnabled
        case .email:
            return !UserDefaults.hasPromptedForEmail && !UserDefaults.hasSubscribedToEmailUpdates
        }
    }
}

// Creates prompt views based on a given type. The 'email' type requires a more
// sophisticated view with an email input field.
class PromptFactory {
    static func createPrompt(type: PromptType, presenter: UIViewController?) -> Prompt {
        switch type {
        case .email:
            let prompt = GetUserEmailPrompt()
            if let presenter = presenter {
                prompt.presenter = presenter
            }
            return prompt
        default:
            return Prompt(type: type)
        }
    }
}

class Prompt : UIView {
    
    init(type: PromptType) {
        self.type = type
        super.init(frame: .zero)
        setup()
    }

    let dismissButton = UIButton.rounded(title: S.Button.dismiss)
    let continueButton = UIButton.rounded(title: S.Button.continueAction)
    let type: PromptType
    
    let title = UILabel(font: .customBold(size: 16.0), color: .darkGray)
    let body = UILabel.wrapping(font: .customBody(size: 14.0), color: .darkGray)
    let container = UIView()

    var shouldHandleTap: Bool {
        return false
    }
    
    func setup() {
        addSubviews()
        setupConstraints()
        setupStyle()
        
        title.text = type.title
        body.text = type.body
    }
    
    var containerBackgroundColor: UIColor {
        return .whiteBackground
    }
            
    func addSubviews() {
        addSubview(container)
        container.addSubview(title)
        container.addSubview(body)
        container.addSubview(dismissButton)
        container.addSubview(continueButton)
    }
    
    func setupConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1],
                                                           left: 10.0,
                                                           bottom: -C.padding[1],
                                                           right: -10.0))
        title.constrain([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: C.padding[1])])
        dismissButton.constrain([
            dismissButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            dismissButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            dismissButton.heightAnchor.constraint(equalToConstant: 44.0),
            dismissButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])])
        continueButton.constrain([
            continueButton.topAnchor.constraint(equalTo: dismissButton.topAnchor),
            continueButton.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: C.padding[1]),
            continueButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            continueButton.widthAnchor.constraint(equalTo: dismissButton.widthAnchor),
            continueButton.bottomAnchor.constraint(equalTo: dismissButton.bottomAnchor)])
    }
    
    func styleDismissButton() {
        dismissButton.backgroundColor = .lightGray
        dismissButton.setTitleColor(.white, for: .normal)
    }

    func styleContinueButton() {
        continueButton.backgroundColor = .statusIndicatorActive
        continueButton.setTitleColor(.white, for: .normal)
    }
    
    private func setupStyle() {
        styleDismissButton()
        styleContinueButton()
        
        container.backgroundColor = containerBackgroundColor
        container.layer.cornerRadius = 4.0
        container.layer.shadowRadius = 4.0
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        container.layer.borderColor = UIColor.black.withAlphaComponent(0.12).cgColor
        container.layer.borderWidth = 1.0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
