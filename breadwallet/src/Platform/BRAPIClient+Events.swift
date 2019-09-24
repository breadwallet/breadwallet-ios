//
//  BRAPIClient+Events.swift
//  breadwallet
//
//  Created by Samuel Sutch on 7/4/17.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

/// Implement Trackable in your class to have access to these functions
public protocol Trackable {
    /// Saves a basic named event.
    func saveEvent(_ eventName: String)
    
    /// Saves a named event with additional attributes.
    func saveEvent(_ eventName: String, attributes: [String: String])
    
    /// Saves an event and with a context.
    func saveEvent(context: EventContext, event: Event)
    
    /**
     *  Saves an event with a context and screen in which the event occurred. If a context is specified,
     *  the event will only be propagated to the server if the given context has been registered via
     *  EventMonitor.register().
     */
    func saveEvent(context: EventContext, screen: Screen, event: Event)
    
    /**
     *  Saves an event with a context and screen in which it occurred, with an optional callback
     *  that indicates whether the event was saved. Whether the event is saved depends on whether
     *  the given context has been registered via EventMonitor.register().
     *
     *  This callback version of saveEvent() is included primarily to facilitate unit testing.
     */
    func saveEvent(context: EventContext, screen: Screen, event: Event, callback: ((Bool) -> Void)?)
    
    /// Saves an event with a context, and additional event attributes.
    func saveEvent(context: EventContext, screen: Screen, event: Event, attributes: [String: String], callback: ((Bool) -> Void)?)
}

extension Trackable {
    
    func saveEvent(_ eventName: String) {
        NotificationCenter.default.post(name: AnalyticsEventListener.eventNotification, object: nil, userInfo: [
            AnalyticsEventListener.eventNameKey: eventName
        ])
    }
    
    func saveEvent(_ eventName: String, attributes: [String: String]) {
        NotificationCenter.default.post(name: AnalyticsEventListener.eventNotification, object: nil, userInfo: [
            AnalyticsEventListener.eventNameKey: eventName,
            AnalyticsEventListener.eventAttributesKey: attributes
        ])
    }
    
    func makeEventName(_ components: [String]) -> String {
        // This will return event strings in the format expected by the server, such as
        // "onboarding.landingPage.appeared."
        return components.filter({ return !$0.isEmpty }).joined(separator: ".")
    }
    
    func saveEvent(context: EventContext, event: Event) {
        saveEvent(context: context, screen: .none, event: event)
    }
    
    func saveEvent(context: EventContext, screen: Screen, event: Event) {
        saveEvent(context: context, screen: screen, event: event, callback: nil)
    }
    
    func saveEvent(context: EventContext, screen: Screen, event: Event, callback: ((Bool) -> Void)?) {
        guard EventMonitor.shared.include(context) else {
            callback?(false)
            return
        }
        
        saveEvent(makeEventName([context.name, screen.name, event.name]))
        
        callback?(true)
    }
    
    func saveEvent(context: EventContext, screen: Screen, event: Event, attributes: [String: String], callback: ((Bool) -> Void)?) {
        guard EventMonitor.shared.include(context) else {
            callback?(false)
            return
        }
        
        saveEvent(makeEventName([context.name, screen.name, event.name]), attributes: attributes)
        
        callback?(true)
    }
}

private var emKey: UInt8 = 1

// EventManager is attached to BRAPIClient
extension BRAPIClient {
    
    var analytics: AnalyticsEventListener? {
        return AnalyticsEventListener.shared
    }
    
    // This is accessed by the ApplicationController once there is a valid wallet.
    var eventManager: EventManager? {
        return Backend.eventManager
    }
    
    func saveEvent(_ eventName: String) {
        analytics?.saveEvent(eventName)
    }
    
    func saveEvent(_ eventName: String, attributes: [String: String]) {
        analytics?.saveEvent(eventName, attributes: attributes)
    }
}

// Responsible for listening for all analytics events posted by the app.
//
// When the app is backgrounded, buffered events are persisted to the file system,
// then uploaded to the server if an EventManager is present.
class AnalyticsEventListener {
    
    static let shared = AnalyticsEventListener()
    
    fileprivate static let eventNotification = Notification.Name("__saveEvent__")
    fileprivate static let eventNameKey = "__event_name__"
    fileprivate static let eventAttributesKey = "__event_attributes__"

    private let sessionId = NSUUID().uuidString
    private var isSubscribed = false
    private var notificationObservers = [String: NSObjectProtocol]()
    
    private let eventToNotifications: [String: NSNotification.Name] = [
        "foreground": UIApplication.didBecomeActiveNotification,
        "background": UIApplication.didEnterBackgroundNotification
    ]
    
    static var eventDiskDirectory: String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = NSString(string: paths[0])
        return documentsDirectory.appendingPathComponent("/event-data")
    }

    private var eventManager: EventManager? {
        return Backend.apiClient.eventManager
    }
    
    private var isWalletReady = false
    
    private let queue = OperationQueue()
    private var buffer = [BRAnalyticsEvent]()
    
    private init() {
        // private init to enforce singleton
    }
    
    func startCollectingEvents() {
        guard !isSubscribed else { return }
        defer { isSubscribed = true }
        
        // Listener for the app-backgrounded event and persist the event to the file system
        // and send to the server.
        eventToNotifications.forEach { key, value in
            notificationObservers[key] =
                NotificationCenter.default
                    .addObserver(forName: value,
                                 object: nil,
                                 queue: self.queue) { note in
                                    self.saveEvent(key)
                                    if note.name == UIApplication.didEnterBackgroundNotification {
                                        self.persistToDisk()
                                        self.syncEventsToServer()
                                    }
            }
        }
        
        // Buffer analytics posted as notifications by the app.
        notificationObservers[AnalyticsEventListener.eventNotification.rawValue] =
            NotificationCenter.default
                .addObserver(forName: AnalyticsEventListener.eventNotification,
                             object: nil,
                             queue: self.queue) { note in
                                guard let eventName = note.userInfo?[AnalyticsEventListener.eventNameKey] as? String else {
                                    print("[EventManager] received invalid userInfo dict: \(String(describing: note.userInfo))")
                                    return
                                }
                                if let eventAttributes = note.userInfo?[AnalyticsEventListener.eventAttributesKey] as? Attributes {
                                    self.saveEvent(eventName, attributes: eventAttributes)
                                } else {
                                    self.saveEvent(eventName)
                                }
        }
    }
    
    // called by ApplicationController when we have a valid wallet (see `didSet`)
    func onWalletReady() {
        isWalletReady = true

        // With a valid wallet it's safe to fire up the event manager so it can upload events.
        syncEventsToServer()
    }
    
    // called from the share data view controller when there is a change to the analytics sharing settings
    func syncDataSharingPermissions() {
        guard isWalletReady else { return }
        syncEventsToServer()
    }
    
    func saveEvent(_ eventName: String) {
        pushEvent(eventName: eventName, attributes: [:])
    }
    
    func saveEvent(_ eventName: String, attributes: [String: String]) {
        pushEvent(eventName: eventName, attributes: attributes)
    }

    private func syncEventsToServer() {
        guard isWalletReady else { return }
        eventManager?.uploadEvents()
    }
    
    private func pushEvent(eventName: String, attributes: [String: String]) {
        queue.addOperation { [weak self] in
            guard let myself = self else { return }
            print("[EventManager] pushEvent name=\(eventName) attributes=\(attributes)")
            myself.buffer.append(  BRAnalyticsEvent(sessionId: myself.sessionId,
                                                    time: Date().timeIntervalSince1970,
                                                    eventName: eventName,
                                                    attributes: attributes))
        }
    }
    
    private func persistToDisk() {
        queue.addOperation { [weak self] in
            guard let myself = self else { return }
            let dataDirectory = AnalyticsEventListener.eventDiskDirectory
            if !FileManager.default.fileExists(atPath: dataDirectory) {
                do {
                    try FileManager.default.createDirectory(atPath: dataDirectory, withIntermediateDirectories: false, attributes: nil)
                } catch let error {
                    print("[EventManager] Could not create directory: \(error)")
                }
            }
            let fullPath = NSString(string: dataDirectory).appendingPathComponent("/\(NSUUID().uuidString).json")
            if let outputStream = OutputStream(toFileAtPath: fullPath, append: false) {
                outputStream.open()
                defer { outputStream.close() }
                let dataToSerialize = myself.buffer.map { $0.dictionary }
                guard JSONSerialization.isValidJSONObject(dataToSerialize) else { print("Invalid json"); return }
                var error: NSError?
                if JSONSerialization.writeJSONObject(dataToSerialize, to: outputStream, options: [], error: &error) == 0 {
                    print("[EventManager] Unable to write JSON for events file: \(String(describing: error))")
                } else {
                    print("[EventManager] saved \(myself.buffer.count) events to disk")
                }
            }
            myself.buffer.removeAll()
        }
    }
}

// Uploads events that have been that have been persisted to the file system by the `AnalyticsEventListener` instance.
class EventManager {
    
    private let queue = OperationQueue()
    private let adaptor: BRAPIAdaptor

    init(adaptor: BRAPIAdaptor) {
        self.adaptor = adaptor
        queue.maxConcurrentOperationCount = 1
    }
    
    private var shouldRecordData: Bool {
        return UserDefaults.hasAquiredShareDataPermission
    }
    
    func uploadEvents() {

        guard shouldRecordData else {
            removeData()
            return
        }
        
        queue.addOperation { [weak self] in
            guard let myself = self else { return }
            let dataDirectory = AnalyticsEventListener.eventDiskDirectory
            
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dataDirectory) else {
                do {
                    try FileManager.default.contentsOfDirectory(atPath: dataDirectory)
                } catch let error {
                    print("[EventManager] Unable to read event data directory: \(error.localizedDescription)")
                }
                return
            }
            
            files.forEach { baseName in
                // 1: read the json in
                let fileName = NSString(string: dataDirectory).appendingPathComponent("/\(baseName)")
                guard let inputStream = InputStream(fileAtPath: fileName) else { return }
                inputStream.open()
                guard let fileContents = try? JSONSerialization.jsonObject(with: inputStream, options: []) as? [[String: Any]] else { return }
                // 2: transform it into the json data the server expects
                let eventDump = myself.eventTupleArrayToDictionary(fileContents)
                guard let body = try? JSONSerialization.data(withJSONObject: eventDump, options: []) else { return }
                
                // 3: send off the request and await response
                var request = URLRequest(url: myself.adaptor.url("/events", args: nil))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
                
                myself.adaptor.dataTaskWithRequest(request, authenticated: true, retryCount: 0, responseQueue: DispatchQueue.main, handler: { (data, resp, err) in
                    if let resp = resp {
                        if resp.statusCode != 200 {
                            if let data = data {
                                print("""
                                    [EventManager] Error uploading event data to server: STATUS=\(resp.statusCode), connErr=\(String(describing: err)), \
                                    data=\(String(describing: String(data: data, encoding: .utf8)))
                                    """)
                            }
                        } else {
                            if let data = data {
                                print("""
                                    [EventManager] Successfully sent \(eventDump.count) events to server \(fileName) => \(resp.statusCode), \
                                    data=\(String(describing: String(data: data, encoding: .utf8)))
                                    """)
                            }
                        }
                    }
                    
                    // 4. remove the file from disk since we no longer need it
                    myself.queue.addOperation {
                        do {
                            try FileManager.default.removeItem(atPath: fileName)
                        } catch let error {
                            print("[EventManager] Unable to remove evnets file at path \(fileName) \(error)")
                        }
                    }
                }).resume()
            }
        }
    }
    
    private func removeData() {
        queue.addOperation {
            let directory = AnalyticsEventListener.eventDiskDirectory
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return }
            files.forEach { baseName in
                let fileName = NSString(string: directory).appendingPathComponent("/\(baseName)")
                do {
                    try FileManager.default.removeItem(atPath: fileName)
                } catch let error {
                    print("[EventManager] Unable to remove events file at path \(fileName): \(error)")
                }
            }
        }
    }
    
    private func eventTupleArrayToDictionary(_ events: [[String: Any]]) -> [String: Any] {
        return [    "deviceType": 0,
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? -1,
                    "events": events ]
    }
}
