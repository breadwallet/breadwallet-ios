//
//  PromptTests.swift
//  breadwalletTests
//
//  Created by Ray Vander Veen on 2019-02-22.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import XCTest

@testable import breadwallet

/**
 *  Tests for prompts and announcements.
 */
class PromptTests: XCTestCase {

    private func getJSONData(file: String) -> Data? {
        if let path = Bundle(for: PromptTests.self).path(forResource: file, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                return data
            } catch {
            }
        }
        return nil
    }
    
    private func getAnnouncementsFromFile(file: String) -> [Announcement]? {
        if let data = getJSONData(file: file) {
            let decoder = JSONDecoder()
            do {
                let announcements = try decoder.decode([Announcement].self, from: data)
                return announcements
            } catch {
            }
        }
        return nil
    }
    
    func testStandardEmailPromptShowsOnce() {
        UserDefaults.resetAll()
        let emailPrompt = StandardEmailCollectingPrompt()
        XCTAssertTrue(emailPrompt.shouldPrompt(walletAuthenticator: nil))
        
        emailPrompt.didPrompt()
        XCTAssertTrue(UserDefaults.hasPromptedForEmail)
        
        emailPrompt.didSubscribe()
        XCTAssertTrue(UserDefaults.hasSubscribedToEmailUpdates)
        
        XCTAssertFalse(emailPrompt.shouldPrompt(walletAuthenticator: nil))
    }
    
    func testGetEmailAnnouncement() {
        // 'getAnnouncementsFromFile()' mimics how BRAPIClient+Announcements handles the /announcements endpoint response.
        guard let announcements = getAnnouncementsFromFile(file: "announcement-email"), !announcements.isEmpty else {
            XCTFail()
            return
        }
        
        let expectEmailAnnouncement = expectation(description: "expect email announcement")
        let announcement = announcements[0]
        
        XCTAssertTrue(announcement.isGetEmailAnnouncement)
        
        guard let pages = announcement.pages, !pages.isEmpty else {
            XCTFail()
            return
        }
        
        let page = pages[0]
        
        // The expected values are in 'announcement-email.json'.
        XCTAssertEqual(page.title, "title")
        XCTAssertEqual(page.body, "body")
        XCTAssertEqual(page.titleKey, "titleKey")
        XCTAssertEqual(page.bodyKey, "bodyKey")
        XCTAssertEqual(page.imageName, "imageName")
        XCTAssertEqual(page.imageUrl, "imageUrl")
        XCTAssertEqual(page.emailList, "emailList")
        
        
        // Verify that showing the prompt sets an appropriate flag such that it won't be shown again.
        UserDefaults.reset(for: Announcement.hasShownKeyPrefix)
        XCTAssertTrue(announcement.shouldPrompt(walletAuthenticator: nil))
        announcement.didPrompt()
        XCTAssertFalse(announcement.shouldPrompt(walletAuthenticator: nil))
        
        expectEmailAnnouncement.fulfill()

        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testPromoAnnouncement() {
        // 'getAnnouncementsFromFile()' mimics how BRAPIClient+Announcements handles the /announcements endpoint response.
        guard let announcements = getAnnouncementsFromFile(file: "announcement-promo"), !announcements.isEmpty else {
            XCTFail()
            return
        }
        
        let expectEmailAnnouncement = expectation(description: "expect action announcement")
        let announcement = announcements[0]
        
        XCTAssertTrue(announcement.type == AnnouncementType.announcementPromo.rawValue)
        
        guard let pages = announcement.pages, !pages.isEmpty else {
            XCTFail()
            return
        }
        
        let page = pages[0]
        
        // The expected values are in 'announcement-action.json'.
        XCTAssertEqual(page.title, "title")
        XCTAssertEqual(page.body, "body")
        XCTAssertEqual(page.footnote, "footnote")
        XCTAssertEqual(page.titleKey, "titleKey")
        XCTAssertEqual(page.bodyKey, "bodyKey")
        XCTAssertEqual(page.footnoteKey, "footnoteKey")
        XCTAssertEqual(page.imageName, "imageName")
        XCTAssertEqual(page.imageUrl, "imageUrl")
        
        XCTAssertNotNil(page.actions)
        XCTAssertEqual(page.actions?.count, 1)
        
        let action = page.actions![0]
        XCTAssertEqual(action.title, "title")
        XCTAssertEqual(action.titleKey, "titleKey")
        XCTAssertEqual(action.url, "url")
        
        // Verify that showing the prompt sets an appropriate flag such that it won't be shown again.
        UserDefaults.reset(for: Announcement.hasShownKeyPrefix)
        XCTAssertTrue(announcement.shouldPrompt(walletAuthenticator: nil))
        announcement.didPrompt()
        XCTAssertFalse(announcement.shouldPrompt(walletAuthenticator: nil))
        
        expectEmailAnnouncement.fulfill()
        
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testPromptOrdering() {
        let biometricsPrompt = StandardPrompt(type: .biometrics)
        let noPasscodePrompt = StandardPrompt(type: .noPasscode)
        let paperKeyPrompt = StandardPrompt(type: .paperKey)
        let announcementPrompt = StandardAnnouncementPrompt(announcement: Announcement())
        let emailPrompt = StandardEmailCollectingPrompt()
        let upgradePinPrompt = StandardPrompt(type: .upgradePin)
        
        var unsortedPrompts: [Prompt] = [noPasscodePrompt, emailPrompt, announcementPrompt, biometricsPrompt, paperKeyPrompt]
        unsortedPrompts.sort { (p1, p2) -> Bool in
            return p1.order < p2.order
        }
        
        let sorted = unsortedPrompts
        
        // upgrade PIN beats paper key
        XCTAssertTrue(upgradePinPrompt.order < paperKeyPrompt.order)

        // make sure paper key appears first (if upgrade PIN not present)
        XCTAssertTrue(sorted.first?.order == PromptType.paperKey.rawValue)
        
        // no passcode beats biometrics
        XCTAssertTrue(noPasscodePrompt.order < biometricsPrompt.order)

        // biometrics beats announcements
        XCTAssertTrue(biometricsPrompt.order < announcementPrompt.order)
        
        // last prompt should be the email prompt
        XCTAssertTrue(sorted.last?.order == PromptType.email.rawValue)
    }
    
    func testSupportedAnnouncementTypes() {
        // 'getAnnouncementsFromFile()' mimics how BRAPIClient+Announcements handles the /announcements endpoint response.
        guard let announcements = getAnnouncementsFromFile(file: "announcement-supported"), !announcements.isEmpty else {
            XCTFail()
            return
        }

        let promptCount = PromptFactory.promptCount
        let announcementsCount = announcements.count
        
        XCTAssertEqual(announcementsCount, 2)
        
        // add the new announcements; one should be filtered out
        PromptFactory.didFetchAnnouncements(announcements: announcements)
        
        XCTAssertEqual(PromptFactory.promptCount, promptCount + 1)
    }
}
