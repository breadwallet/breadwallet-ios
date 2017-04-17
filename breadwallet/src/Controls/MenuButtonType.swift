//
//  MenuButtonType.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

enum MenuButtonType {
    case security
    case support
    case settings
    case lock
    case buy

    var title: String {
        switch self {
        case .security:
            return NSLocalizedString("Security Center", comment: "Menu button title")
        case .support:
            return NSLocalizedString("Support", comment: "Menu button title")
        case .settings:
            return NSLocalizedString("Settings", comment: "Menu button title")
        case .lock:
            return NSLocalizedString("Lock Wallet", comment: "Menu button title")
        case .buy:
            return NSLocalizedString("Buy Bitcoin", comment: "Buy bitcoin title")
        }
    }

    var image: UIImage {
        switch self {
        case .security:
            return #imageLiteral(resourceName: "Shield")
        case .support:
            return #imageLiteral(resourceName: "FaqFill")
        case .settings:
            return #imageLiteral(resourceName: "Settings")
        case .lock:
            return #imageLiteral(resourceName: "Lock")
        case .buy:
            return #imageLiteral(resourceName: "Shield") //TODO - Add buy bitcoin icon
        }
    }
}
