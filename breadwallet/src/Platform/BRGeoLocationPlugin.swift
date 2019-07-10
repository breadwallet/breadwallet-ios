//
//  BRGeoLocationPlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/8/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import CoreLocation

class BRGeoLocationDelegate: NSObject, CLLocationManagerDelegate {
    var manager: CLLocationManager?
    var response: BRHTTPResponse
    var remove: (() -> Void)?
    
    init(response: BRHTTPResponse) {
        self.response = response
        super.init()
        DispatchQueue.main.async {
            self.manager = CLLocationManager()
            self.manager?.delegate = self
        }
    }
    
    func getOne() {
        DispatchQueue.main.async {
            self.manager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
            self.manager?.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        var j = [String: Any]()
        guard let l = locations.last else {
            j["error"] = "unknown error"
            self.response.provide(500, json: j)
            self.remove?()
            return
        }
        j["timestamp"] = l.timestamp.description as AnyObject?
        j["coordinate"] = ["latitude": l.coordinate.latitude, "longitude": l.coordinate.longitude]
        j["altitude"] = l.altitude as AnyObject?
        j["horizontal_accuracy"] = l.horizontalAccuracy as AnyObject?
        j["description"] = l.description as AnyObject?
        response.request.queue.async {
            self.response.provide(200, json: j)
            self.remove?()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        var j = [String: AnyObject]()
        j["error"] = error.localizedDescription as AnyObject?
        response.request.queue.async {
            self.response.provide(500, json: j)
            self.remove?()
        }
    }
}

open class BRGeoLocationPlugin: NSObject, BRHTTPRouterPlugin, CLLocationManagerDelegate, BRWebSocketClient {
    lazy var manager = CLLocationManager()
    var outstanding = [BRGeoLocationDelegate]()
    var sockets = [String: BRWebSocket]()
    
    override init() {
        super.init()
        self.manager.delegate = self
    }
    
    open func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("new authorization status: \(status)")
    }
    
    open func hook(_ router: BRHTTPRouter) {
        // GET /_permissions/geo
        //
        // Call this method to retrieve the current permission status for geolocation.
        // The returned JSON dictionary contains the following keys:
        //
        // "status" = "denied" | "restricted | "undetermined" | "inuse" | "always"
        // "user_queried" = true | false
        // "location_enabled" = true | false
        //
        // The status correspond to those found in the apple CLLocation documentation: http://apple.co/1O0lHFv
        //
        // "user_queried" indicates whether or not the user has already been asked for geolocation
        // "location_enabled" indicates whether or not the user has geo location enabled on their phone
        router.get("/_permissions/geo") { (request, _) -> BRHTTPResponse in
            let userDefaults = UserDefaults.standard
            let authStatus = CLLocationManager.authorizationStatus()
            var retJson = [String: Any]()
            switch authStatus {
            case .denied:
                retJson["status"] = "denied"
            case .restricted:
                retJson["status"] = "restricted"
            case .notDetermined:
                retJson["status"] = "undetermined"
            case .authorizedWhenInUse:
                retJson["status"] = "inuse"
            case .authorizedAlways:
                retJson["status"] = "always"
            @unknown default:
                assertionFailure("unknown location auth status")
                retJson["status"] = "undetermined"
            }
            retJson["user_queried"] = userDefaults.bool(forKey: "geo_permission_was_queried")
            retJson["location_enabled"] = CLLocationManager.locationServicesEnabled()
            return try BRHTTPResponse(request: request, code: 200, json: retJson as AnyObject)
        }
        
        // POST /_permissions/geo
        //
        // Call this method to request the geo permission from the user.
        // The request body should be a JSON dictionary containing a single key, "style"
        // the value of which should be either "inuse" or "always" - these correspond to the
        // two ways the user can authorize geo access to the app. "inuse" will request
        // geo availability to the app when the app is foregrounded, and "always" will request
        // full time geo availability to the app
        router.post("/_permissions/geo") { (request, _) -> BRHTTPResponse in
            if let j = request.json(), let dict = j as? NSDictionary, dict["style"] is String {
                return BRHTTPResponse(request: request, code: 500) // deprecated
            }
            return BRHTTPResponse(request: request, code: 400)
        }
        
        // GET /_geo
        //
        // Calling this method will query CoreLocation for a location object. The returned value may not be returned
        // very quick (sometimes getting a geo lock takes some time) so be sure to display to the user some status
        // while waiting for a response.
        //
        // Response Object:
        //
        // "coordinate" = { "latitude": double, "longitude": double }
        // "altitude" = double
        // "description" = "a string representation of this object"
        // "timestamp" = "ISO-8601 timestamp of when this location was generated"
        // "horizontal_accuracy" = double
        router.get("/_geo") { (request, _) -> BRHTTPResponse in
            if let authzErr = self.getAuthorizationError() {
                return try BRHTTPResponse(request: request, code: 400, json: authzErr)
            }
            let resp = BRHTTPResponse(async: request)
            let del = BRGeoLocationDelegate(response: resp)
            del.remove = {
                objc_sync_enter(self)
                if let idx = self.outstanding.firstIndex(where: { (d) -> Bool in return d == del }) {
                    self.outstanding.remove(at: idx)
                }
                objc_sync_exit(self)
            }
            objc_sync_enter(self)
            self.outstanding.append(del)
            objc_sync_exit(self)
            
            print("outstanding delegates: \(self.outstanding)")
            
            // get location only once
            del.getOne()
            
            return resp
        }
        
        // GET /_geosocket
        //
        // This opens up a websocket to the location manager. It will return a new location every so often (but with no
        // predetermined interval) with the same exact structure that is sent via the GET /_geo call.
        // 
        // It will start the location manager when there is at least one client connected and stop the location manager
        // when the last client disconnects.
        router.websocket("/_geosocket", client: self)
    }
    
    func getAuthorizationError() -> [String: Any]? {
        var retJson = [String: Any]()
        if !CLLocationManager.locationServicesEnabled() {
            retJson["error"] = S.LocationPlugin.disabled
            return retJson
        }
        let authzStatus = CLLocationManager.authorizationStatus()
        if authzStatus != .authorizedWhenInUse && authzStatus != .authorizedAlways {
            retJson["error"] = S.LocationPlugin.notAuthorized
            return retJson
        }
        return nil
    }
    
    var lastLocation: [String: Any]?
    var isUpdatingSockets = false
    
    // location manager for continuous websocket clients
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        var j = [String: Any]()
        guard let l = locations.last else {
            j["error"] = "unknown error"
            sendToAllSockets(data: j)
            return
        }
        j["timestamp"] = l.timestamp.description as AnyObject?
        j["coordinate"] = ["latitude": l.coordinate.latitude, "longitude": l.coordinate.longitude]
        j["altitude"] = l.altitude as AnyObject?
        j["horizontal_accuracy"] = l.horizontalAccuracy as AnyObject?
        j["description"] = l.description as AnyObject?
        lastLocation = j
        sendToAllSockets(data: j)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        var j = [String: Any]()
        j["error"] = error.localizedDescription as AnyObject?
        sendToAllSockets(data: j)
    }
    
    func sendTo(socket: BRWebSocket, data: [String: Any]) {
        do {
            let j = try JSONSerialization.data(withJSONObject: data, options: [])
            if let s = String(data: j, encoding: .utf8) {
                socket.request.queue.async {
                    socket.send(s)
                }
            }
        } catch let e {
            print("LOCATION SOCKET FAILED ENCODE JSON: \(e)")
        }
    }
    
    func sendToAllSockets(data: [String: Any]) {
        for (_, s) in sockets {
            sendTo(socket: s, data: data)
        }
    }
    
    public func socketDidConnect(_ socket: BRWebSocket) {
        print("LOCATION SOCKET CONNECT \(socket.id)")
        sockets[socket.id] = socket
        // on first socket connect to the manager
        if !isUpdatingSockets {
            // if not authorized yet send an error
            if let authzErr = getAuthorizationError() {
                sendTo(socket: socket, data: authzErr)
                return
            }
            // begin updating location
            isUpdatingSockets = true
            DispatchQueue.main.async {
                self.manager.delegate = self
                self.manager.startUpdatingLocation()
            }
        }
        if let loc = lastLocation {
            sendTo(socket: socket, data: loc)
        }
    }
    
    public func socketDidDisconnect(_ socket: BRWebSocket) {
        print("LOCATION SOCKET DISCONNECT \(socket.id)")
        sockets.removeValue(forKey: socket.id)
        // on last socket disconnect stop updating location
        if sockets.isEmpty {
            isUpdatingSockets = false
            lastLocation = nil
            self.manager.stopUpdatingLocation()
        }
    }
    
    public func socket(_ socket: BRWebSocket, didReceiveText text: String) {
        print("LOCATION SOCKET RECV TEXT \(text)")
    }
    
    public func socket(_ socket: BRWebSocket, didReceiveData data: Data) {
        print("LOCATION SOCKET RECV DATA \(data.hexString)")
    }
}
