//
//  Bonjour.swift
//  breadwallet
//
//  Created by Samuel Sutch on 6/6/17.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

public class Bonjour: NSObject, NetServiceBrowserDelegate {
    let serviceBrowser: NetServiceBrowser = NetServiceBrowser()
    var isSearching = false
    var services = [NetService]()
    var serviceTimeout: Timer = Timer()
    var timeout: TimeInterval = 1.0
    var serviceFoundClosure: (([NetService]) -> Void)
    
    override init() {
        serviceFoundClosure = { (v) in return }
        super.init()
        serviceBrowser.delegate = self
    }
    
    func findService(_ identifier: String, domain: String = "local.", found: @escaping ([NetService]) -> Void) -> Bool {
        if !isSearching {
            serviceTimeout = Timer.scheduledTimer(timeInterval: timeout, target: self,
                                                selector: #selector(Bonjour.noServicesFound),
                                                userInfo: nil, repeats: false)
            serviceBrowser.searchForServices(ofType: identifier, inDomain: domain)
            serviceFoundClosure = found
            isSearching = true
            return true
        }
        return false
    }
    
    @objc func noServicesFound() {
        serviceFoundClosure(services)
        serviceBrowser.stop()
        isSearching = false
    }
    
    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("[Bonjour] netServiceBrowser willSearch")
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        print("[Bonjour] netServiceBrowser didFind domain = \(domainString) moreComing = \(moreComing)")
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("[Bonjour] netServiceBrowser didFind service = \(service) moreComing = \(moreComing)")
        serviceTimeout.invalidate()
        services.append(service)
        if !moreComing {
            serviceFoundClosure(services)
            serviceBrowser.stop()
            isSearching = false
        }
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("[Bonjour] netServiceBrowser didNotSearch errors = \(errorDict)")
        noServicesFound()
    }
    
    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("[Bonjour] netServiceBrowser didStopSearch")
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        print("[Bonjour] netServiceBrowser didRemove domain = \(domainString) moreComing = \(moreComing)")
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("[Bonjour] netServiceBrowser didRemove service = \(service) moreComing = \(moreComing)")
    }
}
