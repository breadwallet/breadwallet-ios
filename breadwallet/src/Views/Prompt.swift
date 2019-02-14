//
//  Prompt.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

//
// Definitions to support prompts that appear at the top of the home screen.
//

// Announcement type prompts can have multiple pages, including different title and body text,
// with each page specified as a dictionary in the /announcements API response.
typealias PromptPage = [String: Any]

// Some prompts, such as email subscription prompts, have two steps: initialDisplay and confirmation, each of
// which can have its own text and image content.
enum PromptPageStep: Int {
    case initialDisplay
    case confirmation
}

// Announcements are special types of prompts that are provided by the /announcemnts API.
enum AnnouncementType: String {
    case announcement
    case announcementEmail = "announcement-email"
}

//
// Keys which can be found in the JSON data returned from the /announcements server endpoint.
// The endpoint returns an array of 'pages,' each of which specifies an id (a.k.a., slug), text, image, etc.
//
enum PromptKey: String {
    case id = "slug"    // the server sends 'slug' but we'll call it 'id'
    case type
    case pages
    case title
    case titleKey
    case body
    case bodyKey
    case imageName
    case imageUrl
    case emailList
    
    var key: String { return rawValue }
}

// Defines the types and priority ordering of prompts. Only one prompt can appear on
// the home screen at at time.
enum PromptType: Int {
    case none
    case biometrics
    case paperKey
    case upgradePin
    case noPasscode
    case announcement
    case email

    var order: Int { return rawValue }
    
    static var defaultOrder: [PromptType] = {
        return [.upgradePin, .paperKey, .noPasscode, .biometrics, .email]
    }()
    
    var title: String {
        switch self {
        case .biometrics: return LAContext.biometricType() == .face ? S.Prompts.FaceId.title : S.Prompts.TouchId.title
        case .paperKey: return S.Prompts.PaperKey.title
        case .upgradePin: return S.Prompts.UpgradePin.title
        case .noPasscode: return S.Prompts.NoPasscode.title
        case .email: return S.Prompts.Email.title
        default: return ""
        }
    }
    
    var name: String {
        switch self {
        case .biometrics: return "biometricsPrompt"
        case .paperKey: return "paperKeyPrompt"
        case .upgradePin: return "upgradePinPrompt"
        case .noPasscode: return "noPasscodePrompt"
        case .email: return "emailPrompt"
        default: return ""
        }
    }

    var body: String {
        switch self {
        case .biometrics: return LAContext.biometricType() == .face ? S.Prompts.FaceId.body : S.Prompts.TouchId.body
        case .paperKey: return S.Prompts.PaperKey.body
        case .upgradePin: return S.Prompts.UpgradePin.body
        case .noPasscode: return S.Prompts.NoPasscode.body
        case .email: return S.Prompts.Email.body
        default: return ""
        }
    }

    // This is the trigger that happens when the prompt is tapped
    func trigger(currency: Currency) -> TriggerName? {
        switch self {
        case .biometrics: return .promptBiometrics
        case .paperKey: return .promptPaperKey
        case .upgradePin: return .promptUpgradePin
        case .noPasscode: return nil
        case .email: return .promptEmail
        default: return nil
        }
    }
}

//
// Base class for prompts.
//
class Prompt {
    
    var type: PromptType?
    var json: [String: Any]?
    
    var id: String {
        if let id = element(with: .id) as? String {
            return id
        }
        return ""
    }
    
    var order: Int {
        return type?.order ?? Int.max
    }
    
    var name: String {
        return type?.name ?? ""
    }
    
    convenience init(type: PromptType) {
        self.init(type: type, json: nil)
    }
    
    init(type: PromptType, json: [String: Any]?) {
        self.type = type
        self.json = json
    }
    
    private func element(with key: PromptKey) -> Any? {
        return json?[key.rawValue]
    }
    
    private func page(at step: PromptPageStep) -> PromptPage? {
        if let pages = element(with: .pages) as? [PromptPage] {
            let index = step.rawValue
            if index >= 0 && index < pages.count {
                return pages[index]
            }
        }
        return nil
    }
    
    func trigger(for currency: Currency) -> TriggerName? {
        return type?.trigger(currency: currency)
    }
    
    func title(for step: PromptPageStep) -> String? {
        if let page = page(at: step),
            let titleKey = page[PromptKey.titleKey.key] as? String {
            return NSLocalizedString(titleKey, comment: "")
        }
        return type?.title
    }
    
    func body(for step: PromptPageStep) -> String? {
        if let page = page(at: step),
            let bodyKey = page[PromptKey.bodyKey.key] as? String {
            return NSLocalizedString(bodyKey, comment: "")
        }
        return type?.body
    }
    
    func successFootnote() -> String? {
        return nil
    }
    
    func imageName(for step: PromptPageStep) -> String? {
        if let page = page(at: step),
            let name = page[PromptKey.imageName.key] as? String {
            return name
        }
        return nil
    }
    
    func shouldPrompt(walletAuthenticator: WalletAuthenticator?) -> Bool {
        let type = self.type ?? .none
        switch type {
        case .biometrics:
            return !UserDefaults.hasPromptedBiometrics && LAContext.canUseBiometrics && !UserDefaults.isBiometricsEnabled
        case .paperKey:
            return UserDefaults.walletRequiresBackup && !UserDefaults.debugShouldSuppressPaperKeyPrompt
        case .upgradePin:
            if let authenticator = walletAuthenticator, authenticator.pinLength != 6 {
                return true
            }
            return false
        case .noPasscode:
            return !LAContext.isPasscodeEnabled
        case .email:
            return !UserDefaults.hasPromptedForEmail && !UserDefaults.hasSubscribedToEmailUpdates
        default:
            return false
        }
    }
    
    /// Invoked when the prompt is displayed to on the screen.
    func didPrompt() {
        switch self.type ?? .none {
        case .biometrics:
            UserDefaults.hasPromptedBiometrics = true
        case .email:
            UserDefaults.hasPromptedForEmail = true
        default:
            break
        }
    }
    
    // Returns whether this prompt includes an email subscription prompt.
    func isEmailSubscriptionPrompt() -> Bool {
        if let type = element(with: .type) as? String, type == AnnouncementType.announcementEmail.rawValue {
            return true
        }
        return false
    }
    
    // Returns an email list to subscribe to if this prompt includes an email subscription prompt.
    func emailListParameter() -> String? {
        if let page = page(at: .initialDisplay),
            let list = page[PromptKey.emailList.key] as? String {
            return list
        }
        return nil
    }
}

/**
 *  Prompt subclass for our general email subscription.
 */
class EmailSubscriptionPrompt: Prompt {
    
    init() {
        super.init(type: .email, json: nil)
    }
    
    override func title(for step: PromptPageStep) -> String? {
        switch step {
        case .initialDisplay:   return S.Prompts.Email.title
        case .confirmation:     return S.Prompts.Email.successTitle
        }
    }
    
    override func body(for step: PromptPageStep) -> String? {
        switch step {
        case .initialDisplay:   return S.Prompts.Email.body
        case .confirmation:     return S.Prompts.Email.successBody
        }
    }
    
    override func imageName(for step: PromptPageStep) -> String? {
        switch step {
        case .initialDisplay:   return "Loudspeaker"
        case .confirmation:     return "PartyHat"
        }
    }
    
    override func shouldPrompt(walletAuthenticator: WalletAuthenticator?) -> Bool {
        return !UserDefaults.hasPromptedForEmail
    }
    
    override func isEmailSubscriptionPrompt() -> Bool {
        return true
    }
    
    override func successFootnote() -> String? {
        return S.Prompts.Email.successFootnote
    }
}

class Announcement: Prompt {
    
    static let hasShownKeyPrefix = "has-shown-prompt-"
    
    init(json: [String: Any]) {
        super.init(type: .announcement, json: json)
    }
    
    var showHideKey: String {
        return Announcement.hasShownKeyPrefix + self.id
    }
    
    override func shouldPrompt(walletAuthenticator: WalletAuthenticator?) -> Bool {
        // If didPrompt() has not been called for our id, this defaults to false.
        return !UserDefaults.standard.bool(forKey: self.showHideKey)
    }
    
    override func didPrompt() {
        // Record that we displayed the announcement prompt with our unique 'id' as key.
        UserDefaults.standard.set(true, forKey: self.showHideKey)
    }
}

// Creates prompt views based on a given type. The 'email' type requires a more
// sophisticated view with an email input field.
class PromptFactory: Subscriber {
    
    private static let shared: PromptFactory = PromptFactory()
    
    private var prompts: [Prompt] = [Prompt]()
    
    static func initialize() {
        shared.addDefaultPrompts()
        shared.listenForAnnouncements()
    }
    
    static func nextPrompt(walletAuthenticator: WalletAuthenticator) -> Prompt? {
        let prompts = PromptFactory.shared.prompts
        return prompts.first(where: { $0.shouldPrompt(walletAuthenticator: walletAuthenticator) })
    }
    
    static func createPromptView(prompt: Prompt, presenter: UIViewController?) -> PromptView {
        if prompt.isEmailSubscriptionPrompt() {
            return GetUserEmailPromptView(prompt: prompt, presenter: presenter)
        } else {
            return PromptView(prompt: prompt)
        }
    }
    
    private func addDefaultPrompts() {
        // Add the standard prompts in the correct order.
        PromptType.defaultOrder.forEach { (type) in
            if type == PromptType.email {
                prompts.append(EmailSubscriptionPrompt())
            } else {
                prompts.append(Prompt(type: type))
            }
        }
    }
    
    private func listenForAnnouncements() {
        Store.subscribe(self, name: .didFetchAnnouncements([]), callback: { [unowned self] (trigger) in
            if case .didFetchAnnouncements(let announcements)? = trigger {
                announcements.forEach({ self.prompts.append($0) })
                self.sort()
            }
        })
    }
    
    private func sort() {
        self.prompts.sort(by: { return $0.order < $1.order })
    }
    
}
