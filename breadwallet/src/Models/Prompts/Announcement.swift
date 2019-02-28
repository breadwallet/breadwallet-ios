//
//  Announcement.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-02-21.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation

// Announcements are special types of prompts that are provided by the /announcemnts API.
enum AnnouncementType: String {
    // General announcement without user input.
    case announcement
    // Announcement that can obtain an email address from the user for a mailing list subscription.
    case announcementEmail = "announcement-email"
    // Announcement that includes an action button.
    case announcementAction = "announcement-action"
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
        case imageName
        case imageUrl
        case emailList
    }
    
    // English title text.
    var title: String?
    // Key for a localized title.
    var titleKey: String?
    // English body text.
    var body: String?
    // Key for a localized body.
    var bodyKey: String?
    // Name of image asset included in our asset catalog.
    var imageName: String?
    // URL for a downloadable image that may be used if 'imageName' is not available.
    var imageUrl: String?
    // Name of a mailing list to be used if this announcement if of type 'announcement-email'.
    var emailList: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        do {
            title = try container.decodeIfPresent(String.self, forKey: .title)
            titleKey = try container.decodeIfPresent(String.self, forKey: .titleKey)
            body = try container.decodeIfPresent(String.self, forKey: .body)
            bodyKey = try container.decodeIfPresent(String.self, forKey: .bodyKey)
            imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
            imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            emailList = try container.decodeIfPresent(String.self, forKey: .emailList)
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
        return [AnnouncementType.announcementEmail.rawValue]
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
    
    var isActionAnnouncement: Bool {
        return self.type == AnnouncementType.announcementAction.rawValue
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
    
    // convenience function for getting the title for any page/step
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
    
    // convenience function for getting the body for any page/step
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
    
    // convenience function for getting the image name for any page/step
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
