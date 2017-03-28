//
//  UIControl+Callback.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-23.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

private class CallbackWrapper : NSObject, NSCopying {

    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }

    let callback: () -> Void

    func copy(with zone: NSZone? = nil) -> Any {
        return CallbackWrapper(callback)
    }
}

private struct AssociatedKeys {
    static var didTapCallback = "didTapCallback"
    static var valueChangedCallback = "valueChangedCallback"
}

extension UIControl {
    var tap: (() -> Void)? {
        get {
            guard let callbackWrapper = objc_getAssociatedObject(self, &AssociatedKeys.didTapCallback) as? CallbackWrapper else { return nil }
            return callbackWrapper.callback
        }
        set {
            guard let newValue = newValue else { return }
            addTarget(self, action: #selector(didTap), for: .touchUpInside)
            objc_setAssociatedObject(self, &AssociatedKeys.didTapCallback, CallbackWrapper(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc private func didTap() {
        tap?()
    }

    var valueChanged: (() -> Void)? {
        get {
            guard let callbackWrapper = objc_getAssociatedObject(self, &AssociatedKeys.valueChangedCallback) as? CallbackWrapper else { return nil }
            return callbackWrapper.callback
        }
        set {
            guard let newValue = newValue else { return }
            addTarget(self, action: #selector(valueDidChange), for: .touchUpInside)
            objc_setAssociatedObject(self, &AssociatedKeys.valueChangedCallback, CallbackWrapper(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc private func valueDidChange() {
        valueChanged?()
    }
}
