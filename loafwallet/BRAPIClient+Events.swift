//
//  BRAPIClient+Events.swift
//  breadwallet
//
//  Created by Samuel Sutch on 7/4/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

/// Implement Trackabble in your class to have access to these functions
public protocol Trackable {
    func saveEvent(_ eventName: String)
    func saveEvent(_ eventName: String, attributes: [String: String])
}

extension Trackable {
    func saveEvent(_ eventName: String) {
        NotificationCenter.default.post(name: EventManager.eventNotification, object: nil, userInfo: [
            EventManager.eventNameKey: eventName
        ])
    }
    
    func saveEvent(_ eventName: String, attributes: [String: String]) {
        NotificationCenter.default.post(name: EventManager.eventNotification, object: nil, userInfo: [
            EventManager.eventNameKey: eventName,
            EventManager.eventAttributesKey: attributes
        ])
    }
}

fileprivate var emKey: UInt8 = 1

// EventManager is attached to BRAPIClient
extension BRAPIClient {
    var events: EventManager? {
        get {
            return lazyAssociatedObject(self, key: &emKey) {
                return EventManager(adaptor: self)
            }
        }
    }
    
    func saveEvent(_ eventName: String) {
        events?.saveEvent(eventName)
    }
    
    func saveEvent(_ eventName: String, attributes: [String: String]) {
        events?.saveEvent(eventName, attributes: attributes)
    }
}

class EventManager {
    
    typealias Attributes = [String: String]
    
    fileprivate static let eventNotification = Notification.Name("__saveEvent__")
    fileprivate static let eventNameKey = "__event_name__"
    fileprivate static let eventAttributesKey = "__event_attributes__"
    
    private let sessionId = NSUUID().uuidString
    private let queue = OperationQueue()
    private let sampleChance: UInt32 = 10
    private var isSubscribed = false
    private let eventToNotifications: [String: NSNotification.Name] = [
        "foreground": .UIApplicationDidBecomeActive,
        "background": .UIApplicationDidEnterBackground
    ]
    private var buffer = [Event]()
    private let adaptor: BRAPIAdaptor
    
    struct Event {
        let sessionId: String
        let time: TimeInterval
        let eventName: String
        let attributes: Attributes
        
        var dictionary: [String: Any] {
            return [ "sessionId":    sessionId,
                     "time":        time,
                     "eventName":    eventName,
                     "metadata":     attributes ]
        }
    }
    
    init(adaptor: BRAPIAdaptor) {
        self.adaptor = adaptor
        queue.maxConcurrentOperationCount = 1
    }
    
    func saveEvent(_ eventName: String) {
        pushEvent(eventName: eventName, attributes: [:])
    }
    
    func saveEvent(_ eventName: String, attributes: [String: String]) {
        pushEvent(eventName: eventName, attributes: attributes)
    }
    
    func up() {
        guard !isSubscribed else { return }
        defer { isSubscribed = true }
        
        // slurp up app lifecycle events and save them as events
        eventToNotifications.forEach { key, value in
            NotificationCenter.default.addObserver(forName: value, object: nil, queue: self.queue, using: { [weak self] note in
                self?.saveEvent(key)
                if note.name == .UIApplicationDidEnterBackground {
                    self?.persistToDisk()
                    self?.sendToServer()
                }
            })
        }
        
        // slurp up events sent as notifications
        NotificationCenter.default.addObserver(
            forName: EventManager.eventNotification, object: nil, queue: self.queue) { [weak self] note in
                guard let eventName = note.userInfo?[EventManager.eventNameKey] as? String else {
                    print("[EventManager] received invalid userInfo dict: \(String(describing: note.userInfo))")
                    return
                }
                if let eventAttributes = note.userInfo?[EventManager.eventAttributesKey] as? Attributes {
                    self?.saveEvent(eventName, attributes: eventAttributes)
                } else {
                    self?.saveEvent(eventName)
                }
            }
    }
    
    func down() {
        guard isSubscribed else { return }
        eventToNotifications.forEach { key, value in
            NotificationCenter.default.removeObserver(self, name: value, object: nil)
        }
    }
    
    private var shouldRecordData: Bool {
        return UserDefaults.hasAquiredShareDataPermission
    }
    
    func sync(completion: @escaping () -> Void) {
        guard shouldRecordData else { removeData(); return }
        sendToServer(completion: completion)
    }
    
    private func pushEvent(eventName: String, attributes: [String: String]) {
        queue.addOperation { [weak self] in
            guard let myself = self else { return }
            print("[EventManager] pushEvent name=\(eventName) attributes=\(attributes)")
            myself.buffer.append(  Event(sessionId:     myself.sessionId,
                                         time:          Date().timeIntervalSince1970 * 1000.0,
                                         eventName:     eventName,
                                         attributes:    attributes))
        }
    }
    
    private func persistToDisk() {
        queue.addOperation { [weak self] in
            guard let myself = self else { return }
            let dataDirectory = myself.unsentDataDirectory
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
    
    private func sendToServer(completion: (() -> Void)? = nil) {
        queue.addOperation { [weak self] in
            guard let myself = self else { return }
            let dataDirectory = myself.unsentDataDirectory
            
            do {
                try FileManager.default.contentsOfDirectory(atPath: dataDirectory)
            } catch let error {
                print("error: \(error)")
            }
            
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dataDirectory) else { print("Unable to read event data directory"); return }
            files.forEach { baseName in
                // 1: read the json in
                let fileName = NSString(string: dataDirectory).appendingPathComponent("/\(baseName)")
                guard let inputStream = InputStream(fileAtPath: fileName) else { return }
                inputStream.open()
                guard let fileContents = try? JSONSerialization.jsonObject(with: inputStream, options: []) as? [[String: Any]] else { return }
                guard let inArray = fileContents else { return }
                // 2: transform it into the json data the server expects
                let eventDump = myself.eventTupleArrayToDictionary(inArray)
                guard let body = try? JSONSerialization.data(withJSONObject: eventDump, options: []) else { return }
                
                // 3: send off the request and await response
                var request = URLRequest(url: myself.adaptor.url("/events", args: nil))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
                
                myself.adaptor.dataTaskWithRequest(request, authenticated: true, retryCount: 0, handler: { (data, resp, err) in
                    if let resp = resp {
                        if resp.statusCode != 200 {
                            if let data = data {
                                print("[EventManager] Error uploading event data to server: STATUS=\(resp.statusCode), connErr=\(String(describing: err)), data=\(String(describing: String(data: data, encoding: .utf8)))")
                            }
                        } else {
                            if let data = data {
                                print("[EventManager] Successfully sent \(eventDump.count) events to server \(fileName) => \(resp.statusCode) data=\(String(describing: String(data: data, encoding: .utf8)))")
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
                    completion?()
                }).resume()
            }
        }
        
    }
    
    private func removeData() {
        queue.addOperation { [weak self] in
            guard let myself = self else { return }
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: myself.unsentDataDirectory) else { return }
            files.forEach { baseName in
                let fileName = NSString(string: myself.unsentDataDirectory).appendingPathComponent("/\(baseName)")
                do {
                    try FileManager.default.removeItem(atPath: fileName)
                } catch let error {
                    print("[EventManager] Unable to remove events file at path \(fileName): \(error)")
                }
            }
        }
    }
    
    private func eventTupleArrayToDictionary(_ events: [[String: Any]]) -> [String: Any] {
        return [    "deviceType":   0,
                    "appVersion":   Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? -1,
                    "events":       events ]
    }
    
    private var unsentDataDirectory: String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = NSString(string: paths[0])
        return documentsDirectory.appendingPathComponent("/event-data")
    }
}
