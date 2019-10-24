//
//  AnalyticsEventTests.swift
//  breadwalletTests
//
//  Created by Ray Vander Veen on 2018-12-12.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class AnalyticsEventTests: XCTestCase {

    func testCreateEventNoAttributes() {
        let session = "session1"
        let time = Date().timeIntervalSince1970
        let name = "testEvent"
        let event: BRAnalyticsEvent = BRAnalyticsEvent(sessionId: session,
                                                       time: time,
                                                       eventName: name,
                                                       attributes: [:])
        XCTAssertEqual(session, event.sessionId)
        XCTAssertEqual(time, event.time)
        XCTAssertEqual(name, event.eventName)
        XCTAssertTrue(event.attributes.isEmpty)        
    }

    func testCreateEventWithAttributes() {
        let session = "session1"
        let name = "testEvent"
        let event: BRAnalyticsEvent = BRAnalyticsEvent(sessionId: session,
                                                       time: Date().timeIntervalSince1970,
                                                       eventName: name,
                                                       attributes: [ "foo": "bar",
                                                                     "hey" : "whatever"])
        XCTAssertEqual(session, event.sessionId)
        XCTAssertEqual(name, event.eventName)
        XCTAssertFalse(event.attributes.isEmpty)
        
        //
        // test serialization
        //
        let serialized: [String: Any] = event.dictionary
        
        guard let serializedSessionId = serialized[BRAnalyticsEventName.sessionId.rawValue] as? String else {
            XCTAssertTrue(false)
            return
        }
        XCTAssertTrue(serializedSessionId == session)
        
        guard let serializedName = serialized[BRAnalyticsEventName.eventName.rawValue] as? String else {
            XCTAssertTrue(false)
            return
        }
        XCTAssertTrue(serializedName == name)
        
        // Make sure the meta data key/value pairs are encoded correctly for the server's consumption.
        // There may be a better way to compare dictionary equivalenc but Swift is kinda crazy about
        // type safety and such and it doesn't have a nice built-in operator/function for comparing
        // dictionaries.
        guard let metaData = serialized[BRAnalyticsEventName.metaData.rawValue] as? [[String: Any]] else {
            XCTAssertTrue(false)
            return
        }

        // make sure the foo/bar pair exists
        let containsFooBar = metaData.contains { (pair) -> Bool in
            let key = (pair["key"] as? String) ?? ""
            let value = (pair["value"] as? String) ?? ""
            return (key == "foo") && (value == "bar")
        }        
        XCTAssertTrue(containsFooBar)
        
        // make sure the hey/whatever pair exists
        let containsHeyWhatever = metaData.contains { (pair) -> Bool in
            let key = (pair["key"] as? String) ?? ""
            let value = (pair["value"] as? String) ?? ""
            return (key == "hey") && (value == "whatever")
        }
        XCTAssertTrue(containsHeyWhatever)
    }
    
    func testEventContexts() {
        let trackable = MockTrackable()
        XCTAssertTrue(trackable.makeEventName(["onboarding"]) == "onboarding")
        XCTAssertTrue(trackable.makeEventName(["onboarding", "landingPage"]) == "onboarding.landingPage")
        XCTAssertTrue(trackable.makeEventName(["onboarding", "landingPage", "appeared"]) == "onboarding.landingPage.appeared")
    }
    
    func testRegistrationAndDeregistration() {
        let monitor = EventMonitor.shared
        
        XCTAssertFalse(monitor.include(.test))
        
        monitor.register(.test)
        XCTAssertTrue(monitor.include(.test))
        
        monitor.deregister(.test)
        XCTAssertFalse(monitor.include(.test))
    }
    
    func testEventNotPostedIfContextNotRegistered() {
        let trackable = MockTrackable()
        let expectation = self.expectation(description: "expect event not saved")
        
        // do not register any contexts to have events saved
        
        trackable.saveEvent(context: .test, screen: .test, event: .appeared, callback: { (didSaveEvent) in
            XCTAssertFalse(didSaveEvent)
            expectation.fulfill()
        })
        
        self.waitForExpectations(timeout: 1, handler: nil)
    }

    func testEventPostedIfContextIsRegistered() {
        let monitor = EventMonitor.shared
        
        // Register the 'test' context to be included in saved events
        monitor.register(.test)
        
        let trackable = MockTrackable()
        let expectation = self.expectation(description: "expect event saved")
        
        trackable.saveEvent(context: .test, screen: .test, event: .appeared, callback: { (didSaveEvent) in
            XCTAssertTrue(didSaveEvent)
            monitor.deregister(.test)
            expectation.fulfill()
        })
        
        self.waitForExpectations(timeout: 1, handler: nil)
    }
    
}
