//
//  EventMonitor.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-01-31.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

/**
 *  Allows event contexts to be registered. Only events with registered contexts will be propagated to the
 *  server if they are logged using the Trackable protocol with a context parameter.
 *
 * See Trackable.saveEvent() for more information.
 */
class EventMonitor {
    
    public static let shared: EventMonitor = EventMonitor()
    
    private var activeContexts = [EventContext]()
    
    private init() {
        
    }
    
    func register(_ context: EventContext) {
        guard context != .none else { return }
        activeContexts.append(context)
    }
    
    func deregister(_ context: EventContext) {
        activeContexts.removeAll(where: { return $0 == context })
    }
    
    func include(_ context: EventContext) -> Bool {
        return activeContexts.contains(context)
    }
}
