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

func strongify<Context: AnyObject>(_ context: Context, closure: @escaping(Context) -> Void) -> () -> Void {
    return { [weak context] in
        guard let strongContext = context else { return }
        closure(strongContext)
    }
}

func strongify<Context: AnyObject, Arguments>(_ context: Context?, closure: @escaping (Context, Arguments) -> Void) -> (Arguments) -> Void {
    return { [weak context] arguments in
        guard let strongContext = context else { return }
        closure(strongContext, arguments)
    }
}
