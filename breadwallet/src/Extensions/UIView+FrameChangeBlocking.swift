//
//  UIView+FrameChangeBlocking.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-14.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UIView {

    private struct AssociatedKeys {
        static var frameBlockedKey = "FrameBlockedKey"
    }

    var isFrameChangeBlocked: Bool {
        get {
            guard let object = objc_getAssociatedObject(self, &AssociatedKeys.frameBlockedKey) as? Bool else { return false }
            return object
        }

        set {
            objc_setAssociatedObject(self, &AssociatedKeys.frameBlockedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    static func swizzleSetFrame() {
        guard self == UIView.self else { return }

        //This is now a way to do the equivalent of dispatch_once in swift 3
        let _: () = {
            let originalSelector = #selector(setter: UIView.frame)
            let swizzledSelector = #selector(UIView.requestSetFrame(_:))

            let originalMethod = class_getInstanceMethod(self, originalSelector)
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

            let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod!), method_getTypeEncoding(swizzledMethod!))
            if didAddMethod {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod!), method_getTypeEncoding(originalMethod!))
            } else {
                method_exchangeImplementations(originalMethod!, swizzledMethod!)
            }

        }()
    }

    @objc func requestSetFrame(_ frame: CGRect) {
        guard !isFrameChangeBlocked else { return }
        self.requestSetFrame(frame)
    }
}
