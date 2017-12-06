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

    static var canUseBiometrics: Bool {
        return LAContext().canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static var isBiometricsAvailable: Bool {
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
    
    static func biometricType() -> BiometricType {
        let context = LAContext()
        if #available(iOS 11, *) {
            let _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            switch(context.biometryType) {
            case .none:
                return .none
            case .touchID:
                return .touch
            case .faceID:
                return .face
            }
        } else {
            return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? .touch : .none
        }
    }
    
    enum BiometricType {
        case none
        case touch
        case face
    }

}
