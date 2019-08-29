//
//  LAContext+Extensions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-29.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import LocalAuthentication

enum BiometricsAuthResult {
    case success
    case cancelled
    case failed
}

extension LAContext {

    static var canUseBiometrics: Bool {
        return LAContext().canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static var isBiometricsAvailable: Bool {
        var error: NSError?
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return true
        } else {
            if error?.code == Int(kLAErrorBiometryNotAvailable) {
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
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touch
        case .faceID:
            return .face
        @unknown default:
            assertionFailure("unknown biometry type")
            return .none
        }
    }
    
    static func checkUserBiometricsAuthorization(callback: @escaping (BiometricsAuthResult) -> Void) {
        
        if E.isSimulator {
            callback(.success)
            return
        }
        
        let context = LAContext()
        
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        
        let type = context.biometryType
        
        guard type == .faceID || type == .touchID else {
            callback(.failed)
            return
        }

        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        let prompt = type == .faceID ? S.FaceIDSettings.explanatoryText : S.TouchIdSettings.explanatoryText
        
        // Ensures that the Enter Passcode iOS fallback option is not displayed if the touch/face ID input
        // fails, otherwise Apple expects us to present our own enter-passcode UI for the device passcode.
        context.localizedFallbackTitle = ""
        
        context.evaluatePolicy(policy, localizedReason: prompt, reply: { success, error in
            DispatchQueue.main.async {
                if success {
                    callback(.success)
                    return
                }
                
                guard let error = error else {
                    callback(.failed)
                    return
                }
                
                if error._code == Int(kLAErrorUserCancel) {
                    callback(.cancelled)
                } else {
                    callback(.failed)
                }
            }
        })
    }
    
    enum BiometricType {
        case none
        case touch
        case face
    }

}
