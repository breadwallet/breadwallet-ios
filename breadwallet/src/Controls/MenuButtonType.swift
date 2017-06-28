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
            return S.MenuButton.security
        case .support:
            return S.MenuButton.support
        case .settings:
            return S.MenuButton.settings
        case .lock:
            return S.MenuButton.lock
        case .buy:
            return S.MenuButton.buy
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
            return #imageLiteral(resourceName: "BuyBitcoin")
        }
    }
}
