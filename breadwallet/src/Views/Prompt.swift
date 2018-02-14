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
    case recommendRescan
    case noPasscode
    case shareData

    static var defaultOrder: [PromptType] = {
        return [.recommendRescan, .upgradePin, .paperKey, .noPasscode, .biometrics, .shareData]
    }()
    

    var title: String {
        switch self {
        case .biometrics: return LAContext.biometricType() == .face ? S.Prompts.FaceId.title : S.Prompts.TouchId.title
        case .paperKey: return S.Prompts.PaperKey.title
        case .upgradePin: return S.Prompts.UpgradePin.title
        case .recommendRescan: return S.Prompts.RecommendRescan.title
        case .noPasscode: return S.Prompts.NoPasscode.title
        case .shareData: return S.Prompts.ShareData.title
        }
    }
    
    var name: String {
        switch self {
        case .biometrics: return "biometricsPrompt"
        case .paperKey: return "paperKeyPrompt"
        case .upgradePin: return "upgradePinPrompt"
        case .recommendRescan: return "recommendRescanPrompt"
        case .noPasscode: return "noPasscodePrompt"
        case .shareData: return "shareDataPrompt"
        }
    }

    var body: String {
        switch self {
        case .biometrics: return LAContext.biometricType() == .face ? S.Prompts.FaceId.body : S.Prompts.TouchId.body
        case .paperKey: return S.Prompts.PaperKey.body
        case .upgradePin: return S.Prompts.UpgradePin.body
        case .recommendRescan: return S.Prompts.RecommendRescan.body
        case .noPasscode: return S.Prompts.NoPasscode.body
        case .shareData: return S.Prompts.ShareData.body
        }
    }

    //This is the trigger that happens when the prompt is tapped
    func trigger(currency: CurrencyDef) -> TriggerName? {
        switch self {
        case .biometrics: return .promptBiometrics
        case .paperKey: return .promptPaperKey
        case .upgradePin: return .promptUpgradePin
        case .recommendRescan: return .recommendRescan(currency)
        case .noPasscode: return nil
        case .shareData: return .promptShareData
        }
    }

    func shouldPrompt(walletManager: WalletManager, state: State) -> Bool {
        switch self {
        case .biometrics:
            return !UserDefaults.hasPromptedBiometrics && LAContext.canUseBiometrics && !UserDefaults.isBiometricsEnabled
        case .paperKey:
            return UserDefaults.walletRequiresBackup
        case .upgradePin:
            return walletManager.pinLength != 6
        case .recommendRescan:
            return state[walletManager.currency].recommendRescan
        case .noPasscode:
            return !LAContext.isPasscodeEnabled
        case .shareData:
            return !UserDefaults.hasAquiredShareDataPermission && !UserDefaults.hasPromptedShareData
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
    
    private let title = UILabel(font: .customBold(size: 16.0), color: .darkGray)
    private let body = UILabel.wrapping(font: .customBody(size: 14.0), color: .darkGray)

    private func setup() {
        addSubview(title)
        addSubview(body)
        addSubview(dismissButton)
        addSubview(continueButton)
        
        title.constrain([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            title.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2])
            ])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: C.padding[1]),
            body.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2])
            ])
        dismissButton.constrain([
            dismissButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            dismissButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            dismissButton.heightAnchor.constraint(equalToConstant: 44.0),
            dismissButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1])
            ])
        continueButton.constrain([
            continueButton.topAnchor.constraint(equalTo: dismissButton.topAnchor),
            continueButton.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: C.padding[1]),
            continueButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            continueButton.heightAnchor.constraint(equalTo: dismissButton.heightAnchor),
            continueButton.widthAnchor.constraint(equalTo: dismissButton.widthAnchor),
            continueButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1])
            ])
        
        dismissButton.backgroundColor = .lightGray
        dismissButton.setTitleColor(.white, for: .normal)
        continueButton.backgroundColor = .statusIndicatorActive
        continueButton.setTitleColor(.white, for: .normal)
        
        title.text = type.title
        body.text = type.body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
