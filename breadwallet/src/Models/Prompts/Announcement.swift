//
//  Announcement.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-02-21.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import Foundation

// Announcements are special types of prompts that are provided by the /announcemnts API.
enum AnnouncementType: String {
    // General announcement without user input.
    case announcement
    // Announcement that can obtain an email address from the user for a mailing list subscription.
    case announcementEmail = "announcement-email"
    // A promotional announcement.
    case announcementPromo = "announcement-promo"
}

/**
 *  Represents an action that can be displayed as part of an announcement prompt.
 */
struct AnnouncementAction: Decodable {
    enum Keys: String, CodingKey {
        case title
        case titleKey
        case url
    }
    
    // English title text for the action.
    var title: String?
    // Key for localized title.
    var titleKey: String?
    // URL to be invoked in response to the action.
    var url: String?
    
    // Text to be displayed as a button title, either the raw title or a localized string based
    // on the title key.
    var titleText: String {
        if let key = titleKey {
            return NSLocalizedString(key, comment: "")
        } else if let title = title {
            return title
        }
        return ""
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        do {
            title = try container.decodeIfPresent(String.self, forKey: .title)
            titleKey = try container.decodeIfPresent(String.self, forKey: .titleKey)
            url = try container.decodeIfPresent(String.self, forKey: .url)
        } catch {   // missing element
        }
    }
}

/**
 *  Represents a page in a single or multi-page announcement entity returned from the /announcements API endpoint.
 */
struct AnnouncementPage: Decodable {
    
    enum Keys: String, CodingKey {
        case title
        case titleKey
        case body
        case bodyKey
        case footnote
        case footnoteKey
        case imageName
        case imageUrl
        case emailList
        case actions
    }
    
    // English title text.
    var title: String?
    
    // Key for a localized title.
    var titleKey: String?
    
    // English body text.
    var body: String?
    
    // Key for a localized body.
    var bodyKey: String?
    
    // English footnote text.
    var footnote: String?
    
    // Key for a localized footnote.
    var footnoteKey: String?
    
    // Name of image asset included in our asset catalog.
    var imageName: String?
    
    // URL for a downloadable image that may be used if 'imageName' is not available.
    var imageUrl: String?
    
    // Name of a mailing list to be used if this announcement if of type 'announcement-email'.
    var emailList: String?
    
    // Actions associated with this announcement page.
    var actions: [AnnouncementAction]?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        do {
            title = try container.decodeIfPresent(String.self, forKey: .title)
            titleKey = try container.decodeIfPresent(String.self, forKey: .titleKey)
            body = try container.decodeIfPresent(String.self, forKey: .body)
            bodyKey = try container.decodeIfPresent(String.self, forKey: .bodyKey)
            footnote = try container.decodeIfPresent(String.self, forKey: .footnote)
            footnoteKey = try container.decodeIfPresent(String.self, forKey: .footnoteKey)
            imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
            imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            emailList = try container.decodeIfPresent(String.self, forKey: .emailList)
            actions = try container.decodeIfPresent([AnnouncementAction].self, forKey: .actions)
        } catch {
            assert(false, "missing Announcement page element")
        }
    }
}

/**
 *  Represents an announcement entity returned from the `/announcements` API endpoint.
 *
 *  An announcement typically displays a title, body, and may include an email address
 *  input field or a CTA that invokes a URL.
 */
struct Announcement: Decodable {
    
    // N.B. Add supported types here otherwise they will be ignored by PromptFactory.
    static var supportedTypes: [String] {
        return [AnnouncementType.announcementEmail.rawValue,
                AnnouncementType.announcementPromo.rawValue]
    }

    enum Keys: String, CodingKey {
        case id = "slug"    // the server sends 'slug' but we'll call it 'id'
        case type
        case pages
    }
    
    static let hasShownKeyPrefix = "has-shown-prompt-"
    
    var id: String?
    var type: String?
    var pages: [AnnouncementPage]?
        
    // default initializer to help unit testing
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        do {
            id = try container.decode(String.self, forKey: .id)
            type = try container.decode(String.self, forKey: .type)
            pages = try container.decodeIfPresent([AnnouncementPage].self, forKey: .pages)
        } catch { // missing element
            assert(false, "missing Announcement element")
        }
    }
    
    var isSupported: Bool {
        return Announcement.supportedTypes.contains(self.type ?? "")
    }
    
    var isGetEmailAnnouncement: Bool {
        return self.type == AnnouncementType.announcementEmail.rawValue
    }
        
    func page(at step: PromptPageStep) -> AnnouncementPage? {
        if let pages = pages, !pages.isEmpty && step.step < pages.count {
            return pages[step.rawValue]
        }
        return nil
    }
    
    var title: String {
        return title(for: .initialDisplay)
    }
    
    var body: String {
        return body(for: .initialDisplay)
    }
    
    var footnote: String {
        return footnote(for: .initialDisplay)
    }
    
    var imageName: String? {
        if let page = page(at: .initialDisplay), let imageName = page.imageName {
            return imageName
        }
        return nil
    }
    
    private var showHideKey: String {
        return Announcement.hasShownKeyPrefix + (self.id ?? "")
    }
    
    func shouldPrompt(walletAuthenticator: WalletAuthenticator?) -> Bool {
        // If didPrompt() has not been called for our id, this defaults to false.
        return !UserDefaults.standard.bool(forKey: self.showHideKey)
    }
    
    func didPrompt() {
        // Record that we displayed the announcement prompt with our unique 'id' as key so that it's not shown again.
        UserDefaults.standard.set(true, forKey: self.showHideKey)
    }
    
    func actions(for step: PromptPageStep) -> [AnnouncementAction]? {
        if let page = page(at: .initialDisplay) {
            return page.actions
        }
        return nil
    }
    
    // MARK: convenience functions

    func title(for step: PromptPageStep) -> String {
        if let page = page(at: step) {
            if let key = page.titleKey {
                return NSLocalizedString(key, comment: "")
            } else if let title = page.title {
                return title
            }
        }
        return ""
    }
    
    func body(for step: PromptPageStep) -> String {
        if let page = page(at: step) {
            if let key = page.bodyKey {
                return NSLocalizedString(key, comment: "")
            } else if let body = page.body {
                return body
            }
        }
        return ""
    }

    func footnote(for step: PromptPageStep) -> String {
        if let page = page(at: step) {
            if let key = page.footnoteKey {
                return NSLocalizedString(key, comment: "")
            } else if let footnote = page.footnote {
                return footnote
            }
        }
        return ""
    }
    
    func imageName(for step: PromptPageStep) -> String? {
        if let page = page(at: step), let name = page.imageName {
            return name
        }
        return nil
    }
}

/**
 *  Protocol for prompts that are based on an announcement entity returned from the /announcements API endpoint.
 */
protocol AnnouncementBasedPrompt: Prompt {
    var announcement: Announcement { get }
}

/**
 *  Announcement-based prompt default implementation.
 */
extension AnnouncementBasedPrompt {
    
    var order: Int {
        return PromptType.announcement.order
    }
    
    var title: String {
        return announcement.title
    }
    
    var body: String {
        return announcement.body
    }
    
    var footnote: String? {
        return announcement.footnote
    }
    
    var imageName: String? {
        return announcement.imageName
    }
    
    func shouldPrompt(walletAuthenticator: WalletAuthenticator?) -> Bool {
        return announcement.shouldPrompt(walletAuthenticator: walletAuthenticator)
    }
    
    func didPrompt() {
        announcement.didPrompt()
    }
}

/**
 *  A Prompt that is based on an announcement object returned from the /announcements API endpoint.
 */
struct StandardAnnouncementPrompt: AnnouncementBasedPrompt {
    let announcement: Announcement

    init(announcement: Announcement) {
        self.announcement = announcement
    }
}

/**
 *  A prompt based on an announcement that can obtain an email address from the user.
 */
struct AnnouncementBasedEmailCollectingPrompt: AnnouncementBasedPrompt, EmailCollectingPrompt {
    let announcement: Announcement
    
    init(announcement: Announcement) {
        self.announcement = announcement
    }
    
    // MARK: EmailCollecting

    var confirmationTitle: String {
        return announcement.title(for: .confirmation)
    }
    
    var confirmationBody: String {
        return announcement.body(for: .confirmation)
    }
    
    var confirmationFootnote: String? {
        return nil
    }
    
    var confirmationImageName: String? {
        return announcement.imageName(for: .confirmation)
    }
    
    var emailList: String? {
        if let page = announcement.page(at: .initialDisplay), let list = page.emailList {
            return list
        }
        return nil
    }

    func didSubscribe() {
        
    }
}
