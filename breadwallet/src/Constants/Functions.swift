//
//  Functions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-18.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

func guardProtected(callback: @escaping () -> Void) {
    if UIApplication.shared.isProtectedDataAvailable {
        callback()
    } else {
        var observer: Any?
        observer = NotificationCenter.default.addObserver(forName: .UIApplicationProtectedDataDidBecomeAvailable, object: nil, queue: nil,
                                                          using: { note in
                                                            callback()
                                                            if let observer = observer {
                                                                NotificationCenter.default.removeObserver(observer)
                                                            }
        })
    }
}
