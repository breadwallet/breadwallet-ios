//
//  LAContext+Extensions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-29.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import LocalAuthentication

extension LAContext {

    static var canUseTouchID: Bool {
        return LAContext().canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static var isTouchIdAvailable: Bool {
        var error: NSError? = nil
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return true
        } else {
            if error?.code == LAError.touchIDNotAvailable.rawValue {
                return false
            } else {
                return true
            }
        }
    }

    static var isPasscodeEnabled: Bool {
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

}
