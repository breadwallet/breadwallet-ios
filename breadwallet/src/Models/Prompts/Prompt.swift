//
//  Prompt.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-04.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import LocalAuthentication

/**
 *  Definitions to support prompts that appear at the top of the home screen.
 */

// Some prompts, such as email subscription prompts, have two steps: initialDisplay and confirmation, each of
// which can have its own text and image content.
enum PromptPageStep: Int {
    case initialDisplay
    case confirmation
    var step: Int { return rawValue }
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
    
    // N.B. The ordering in this enum determines the priority ordering of the prompts,
    // using the `order` var.
    case none
    case upgradePin
    case paperKey
    case noPasscode
    case biometrics
    case announcement
    case email

    var order: Int { return rawValue }
    
    static var defaultTypes: [PromptType] = {
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
        case .announcement: return "announcementPrompt"
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
    var trigger: TriggerName? {
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

// Standard protocol for prompts that are shown to the user, typically at the top of the home screen.
protocol Prompt {
    
    /**
     *  The type for this prompt, which is used to determine whether to show the prompt
     *  and in which order relative to other prompts.
     */
    var type: PromptType { get }
    
    /**
     *  Name of this prompt, used for event logging.
     */
    var name: String { get }
    
    /**
     *  The priority ordering of this prompt relative to other prompts.
     */
    var order: Int { get }
    
    /**
     *  The title displayed with this prompt. e.g., "Action Required" for the paper key prompt.
     */
    var title: String { get }
    
    /**
     *  The body displayed with this prompt. e.g., "Your paper key must be saved..."
     */
    var body: String { get }
    
    /**
     *  Optional footnote text displayed with this prompt.
     */
    var footnote: String? { get }
    
    /**
     *  Optional image name for an icon to be displayed with the prompt, assuming the name corresponds
     *  to an image asset that included the asset catalog.
     */
    var imageName: String? { get }
    
    /**
     *  Optional image url for an icon to be displayed with the prompt. If imageName() corresponds to a valid
     *  image, this value is ignored.
     */
    var imageUrl: String? { get }
    
    /**
     *  The trigger that should be invoked when this prompt is tapped.
     */
    var trigger: TriggerName? { get }
    
    /**
     *  Returns whether this prompt should be presented to the user.
     */
    func shouldPrompt(walletAuthenticator: WalletAuthenticator?) -> Bool
    
    /**
     *  Invoked when this prompt is shown to the user. This function may be used to track the number of
     *  times a prompt has been shown, and whether to show it again.
     */
    func didPrompt()
}

//
// default Prompt implementation
//
extension Prompt {
    
    var type: PromptType {
        return .none
    }
    
    var name: String {
        return type.name
    }
    
    var order: Int {
        return type.order
    }
    
    var title: String {
        return type.title
    }
    
    var body: String {
        return type.body
    }
    
    var footnote: String? {
        return nil
    }
    
    var imageName: String? {
        return nil
    }
    
    var imageUrl: String? {
        return nil
    }
    
    var trigger: TriggerName? {
        return type.trigger
    }
    
    // default implementation based on the type of prompt
    func shouldPrompt(walletAuthenticator: WalletAuthenticator?) -> Bool {
        switch type {
        case .biometrics:
            guard !UserDefaults.hasPromptedBiometrics && LAContext.canUseBiometrics else { return false }
            guard let authenticator = walletAuthenticator, !authenticator .isBiometricsEnabledForUnlocking else { return false }
            return true
        case .paperKey:
            return UserDefaults.walletRequiresBackup && !UserDefaults.debugShouldSuppressPaperKeyPrompt
        case .upgradePin:
            if let authenticator = walletAuthenticator, authenticator.pinLength != 6 {
                return true
            }
            return false
        case .noPasscode:
            return !LAContext.isPasscodeEnabled
        default:
            return false
        }
    }
    
    func didPrompt() {}
}

// Struct for basic prompts that include a Dismiss and Continue button, such as the
// paper-key prompt.
struct StandardPrompt: Prompt {

    var promptType: PromptType
    
    init(type: PromptType) {
        self.promptType = type
    }
    
    var type: PromptType {
        return promptType
    }
    
    func didPrompt() {
        if type == .biometrics {
            UserDefaults.hasPromptedBiometrics = true
        }
    }
}

/**
 *  Protocol for obtaining an email address from the user, optionally for a specific mailing list.
 */
protocol EmailCollectingPrompt: Prompt {

    /**
     *  Title text for the page displayed when the email subscription has been confirmed.
     */
    var confirmationTitle: String { get }

    /**
     *  Body text for the page displayed when the email subscription has been confirmed.
     */
    var confirmationBody: String { get }

    /**
     *  Text for a footnote to be displayed when the email subscription is confirmed.
     */
    var confirmationFootnote: String? { get }
    
    /**
     *  Name for an image to be displayed when the email subscription is confirmed.
     */
    var confirmationImageName: String? { get }
    
    /**
     *  The email subscription list to which the user will be subscribed if a valid email address
     *  is submitted.
     */
    var emailList: String? { get }
    
    /**
     *  To be invoked by the get-email prompt view when the user has successfully subscribed to updates.
     */
    func didSubscribe()
}

// Default email-prompt implementation, used for the standard email subscription prompt.
struct StandardEmailCollectingPrompt: Prompt, EmailCollectingPrompt {
    
    var type: PromptType {
        return .email
    }
    
    var order: Int {
        return PromptType.email.order
    }
    
    var title: String {
        return S.Prompts.Email.title
    }
    
    var body: String {
        return S.Prompts.Email.body
    }
    
    var confirmationTitle: String {
        return S.Prompts.Email.successTitle
    }
    
    var confirmationBody: String {
        return S.Prompts.Email.successBody
    }
    
    var confirmationFootnote: String? {
        return S.Prompts.Email.successFootnote
    }
    
    var confirmationImageName: String? {
        return "Email"
    }

    var imageName: String? {
        return "Email"
    }
    
    var emailList: String? {
        // The standard get-email prompt does not have an email list -- users are just subscribed to our
        // general updates mailing list.
        return nil
    }

    func shouldPrompt(walletAuthenticator: WalletAuthenticator?) -> Bool {
        return !UserDefaults.hasPromptedForEmail && !UserDefaults.hasSubscribedToEmailUpdates
    }
    
    func didPrompt() {
        UserDefaults.hasPromptedForEmail = true
    }
    
    func didSubscribe() {
        UserDefaults.hasSubscribedToEmailUpdates = true
    }
}

// Creates prompt views based on a given type. The 'email' type requires a more
// sophisticated view with an email input field.
class PromptFactory: Subscriber {
    
    private static let shared: PromptFactory = PromptFactory()
    
    private var prompts: [Prompt] = [Prompt]()
    
    init() {
        addDefaultPrompts()
    }
    
    static var promptCount: Int {
        return shared.prompts.count
    }
    
    // Invoked from BRAPIClient.fetchAnnouncements()
    static func didFetchAnnouncements(announcements: [Announcement]) {
        let supported = announcements.filter({ $0.isSupported })
        
        if supported.isEmpty {
            return
        }

        supported.forEach({
            if $0.isGetEmailAnnouncement {
                shared.prompts.append(AnnouncementBasedEmailCollectingPrompt(announcement: $0))
            } else {
                shared.prompts.append(StandardAnnouncementPrompt(announcement: $0))
            }
        })
        shared.sort()
    }
    
    static func nextPrompt(walletAuthenticator: WalletAuthenticator) -> Prompt? {
        let prompts = PromptFactory.shared.prompts
        let next = prompts.first(where: { $0.shouldPrompt(walletAuthenticator: walletAuthenticator) })
        return next
    }
    
    static func createPromptView(prompt: Prompt, presenter: UIViewController) -> PromptView {
        if let emailPrompt = prompt as? EmailCollectingPrompt {
            return GetUserEmailPromptView(prompt: emailPrompt, presenter: presenter)
        } else if let announcementPrompt = prompt as? AnnouncementBasedPrompt {
            return AnnouncementPromptView(prompt: announcementPrompt)
        } else {
            return PromptView(prompt: prompt)
        }
    }
    
    private func addDefaultPrompts() {
        PromptType.defaultTypes.forEach { (type) in
            if type == PromptType.email {
                prompts.append(StandardEmailCollectingPrompt())
            } else {
                prompts.append(StandardPrompt(type: type))
            }
        }
        sort()
    }
    
    private func sort() {
        self.prompts.sort(by: { return $0.order < $1.order })
    }
    
}
