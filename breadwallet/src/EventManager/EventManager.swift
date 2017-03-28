//
//  Trackable.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-19.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension Trackable {
    func saveEvent(_ eventName: String) {
        EventManager.shared.saveEvent(eventName)
    }

    func saveEvent(_ eventName: String, attributes: [String: String]) {
        EventManager.shared.saveEvent(eventName, attributes: attributes)
    }
}

extension EventManagerCoordinator {
    func startEventManager() {
        EventManager.shared.up()
    }

    func syncEventManager(completion: @escaping () -> Void) {
        EventManager.shared.sync(completion: completion)
    }

    func acquireEventManagerUserPermissions(callback: () -> Void) {
        EventManager.shared.acquireUserPermission(callback: callback)
    }
}

fileprivate class EventManager {

    typealias Attributes = [String: String]

    static let shared = EventManager()
    private let sessionId = NSUUID().uuidString
    private let queue = OperationQueue()
    private let sampleChance: UInt32 = 10
    private var isSubscribed = false
    private let eventToNotifications: [String: NSNotification.Name] = [
        "foreground": .UIApplicationDidBecomeActive,
        "background": .UIApplicationDidEnterBackground
    ]
    private var buffer = [Event]()

    private enum SampleGroup {
        static let hasDetermined =          "has_determined_sample_group"
        static let isMember =               "is_in_sample_group"
        static let hasPrompted =            "has_prompted_for_permission"
        static let hasAquiredPermission =   "has_acquired_permission"
    }
    //private let eventServerUrl = URL(string: "https://api.breadwallet.com/events")!
    private let eventServerUrl = URL(string: "http://localhost:8080/events")!

    struct Event {
        let sessionId: String
        let time: TimeInterval
        let eventName: String
        let attributes: Attributes

        var dictionary: [String: Any] {
            return [ "sessionId":    sessionId,
                     "time":         time,
                     "eventName":    eventName,
                     "metadata":     attributes ]
        }
    }

    private init() {
        queue.maxConcurrentOperationCount = 1

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: SampleGroup.hasDetermined) {
            let isInSample = arc4random_uniform(100) < sampleChance
            defaults.set(isInSample, forKey: SampleGroup.isMember)
            defaults.set(true, forKey: SampleGroup.hasDetermined)
        }
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

        eventToNotifications.forEach { key, value in
            NotificationCenter.default.addObserver(forName: value, object: nil, queue: self.queue, using: { [weak self] note in
                self?.saveEvent(key)
                if note.name == .UIApplicationDidEnterBackground {
                    self?.persistToDisk()
                    self?.sendToServer()
                }
            })
        }
    }

    func down() {
        guard isSubscribed else { return }
        eventToNotifications.forEach { key, value in
            NotificationCenter.default.removeObserver(self, name: value, object: nil)
        }
    }

    private var isInSampleGroup: Bool {
        return UserDefaults.standard.bool(forKey: SampleGroup.isMember)
    }

    private var hasAcquiredPermission: Bool {
        return UserDefaults.standard.bool(forKey: SampleGroup.hasAquiredPermission)
    }

    private var shouldRecordData: Bool {
        return isInSampleGroup && hasAcquiredPermission
    }

    func acquireUserPermission(callback: () -> Void) {

    }

    func sync(completion: @escaping () -> Void) {
        guard shouldRecordData else { removeData(); return }
        sendToServer(completion: completion)
    }

    private func pushEvent(eventName: String, attributes: [String: String]) {
        queue.addOperation { [weak self] in
            guard let myself = self else { return }
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
                    print("Could not create directory: \(error)")
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
                    print("Unable to write JSON for events file: \(String(describing: error))")
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
                let request = NSMutableURLRequest(url: myself.eventServerUrl)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let urlSession = URLSession(configuration: URLSessionConfiguration.default)
                let uploadTask = urlSession.uploadTask(with: request as URLRequest, from: body, completionHandler: { (data, response, error) in
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode != 201 {
                            if let responseData = data {
                                print("Error uploading event data to server: STATUS=\(httpResponse.statusCode), connErr=\(String(describing: error)), data=\(String(describing: String(data: responseData, encoding: .utf8)))")
                            }
                        } else {
                            if let responseData = data {
                                print("Successfully sent event data to server \(fileName) => \(httpResponse.statusCode) data=\(String(describing: String(data: responseData, encoding: .utf8)))")
                            }
                        }
                    }

                    // 4. remove the file from disk since we no longer need it
                    myself.queue.addOperation {
                        do {
                            try FileManager.default.removeItem(atPath: fileName)
                        } catch let error {
                            print("Unable to remove evnets file at path \(fileName) \(error)")
                        }
                    }
                    completion?()
                })

                uploadTask.resume()
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
                    print("Unable to remove events file at path \(fileName): \(error)")
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
