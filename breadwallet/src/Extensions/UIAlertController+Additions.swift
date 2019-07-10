//
//  UIAlertController+Additions.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-07-12.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UIAlertController {
    
    /// Alert with OK/Cancel buttons with a handler for OK and no-op for Cancel
    static func confirmationAlert(title: String,
                                  message: String,
                                  okButtonTitle: String = S.Button.ok,
                                  cancelButtonTitle: String = S.Button.cancel,
                                  isDestructiveAction: Bool = false,
                                  handler: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: okButtonTitle, style: (isDestructiveAction ? .destructive : .default), handler: { _ in
            handler()
        }))
        alert.addAction(UIAlertAction(title: cancelButtonTitle, style: .cancel, handler: nil))
        return alert
    }
}
