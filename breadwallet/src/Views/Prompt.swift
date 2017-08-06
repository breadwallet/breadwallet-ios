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
    case touchId
    case paperKey
    case upgradePin
    case recommendRescan
    case noPasscode
    case shareData

    static var defaultOrder: [PromptType] = {
        return [.recommendRescan, .upgradePin, .paperKey, .noPasscode, .touchId, .shareData]
    }()

    var title: String {
        switch self {
        case .touchId: return S.Prompts.TouchId.title
        case .paperKey: return S.Prompts.PaperKey.title
        case .upgradePin: return S.Prompts.UpgradePin.title
        case .recommendRescan: return S.Prompts.RecommendRescan.title
        case .noPasscode: return S.Prompts.NoPasscode.title
        case .shareData: return S.Prompts.ShareData.title
        }
    }
    
    var name: String {
        switch self {
        case .touchId: return "touchIdPrompt"
        case .paperKey: return "paperKeyPrompt"
        case .upgradePin: return "upgradePinPrompt"
        case .recommendRescan: return "recommendRescanPrompt"
        case .noPasscode: return "noPasscodePrompt"
        case .shareData: return "shareDataPrompt"
        }
    }

    var body: String {
        switch self {
        case .touchId: return S.Prompts.TouchId.body
        case .paperKey: return S.Prompts.PaperKey.body
        case .upgradePin: return S.Prompts.UpgradePin.body
        case .recommendRescan: return S.Prompts.RecommendRescan.body
        case .noPasscode: return S.Prompts.NoPasscode.body
        case .shareData: return S.Prompts.ShareData.body
        }
    }

    //This is the trigger that happens when the prompt is tapped
    var trigger: TriggerName? {
        switch self {
        case .touchId: return .promptTouchId
        case .paperKey: return .promptPaperKey
        case .upgradePin: return .promptUpgradePin
        case .recommendRescan: return .recommendRescan
        case .noPasscode: return nil
        case .shareData: return .promptShareData
        }
    }

    func shouldPrompt(walletManager: WalletManager, state: State) -> Bool {
        switch self {
        case .touchId:
            return !UserDefaults.hasPromptedTouchId && LAContext.canUseTouchID && !UserDefaults.isTouchIdEnabled
        case .paperKey:
            return UserDefaults.walletRequiresBackup
        case .upgradePin:
            return walletManager.pinLength != 6
        case .recommendRescan:
            return state.recommendRescan
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

    let close = UIButton.close
    let type: PromptType
    private let title = UILabel(font: .customBold(size: 14.0), color: .darkText)
    private let body = UILabel.wrapping(font: .customBody(size: 13.0), color: .darkText)

    private func setup() {
        addSubview(title)
        addSubview(body)
        addSubview(close)
        title.constrain([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            title.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]) ])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            body.topAnchor.constraint(equalTo: title.bottomAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]) ])
        close.constrain([
            close.topAnchor.constraint(equalTo: topAnchor),
            close.trailingAnchor.constraint(equalTo: trailingAnchor) ])
        close.pin(toSize: CGSize(width: 44.0, height: 44.0))
        title.text = type.title
        body.text = type.body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
