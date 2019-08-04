//
//  MenuItem.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-01.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

struct MenuItem {
    
    enum Icon {
        static let scan = UIImage(named: "scan")
        static let wallet = UIImage(named: "wallet")
        static let preferences = UIImage(named: "prefs")
        static let security = UIImage(named: "security")
        static let support = UIImage(named: "support")
        static let rewards = UIImage(named: "Star")
        static let about = UIImage(named: "about")
        static let atmMap = UIImage(named: "placemark")
    }
    
    var title: String
    var subTitle: String?
    let icon: UIImage?
    let accessoryText: (() -> String)?
    let callback: () -> Void
    let faqButton: UIButton? = nil
    var shouldShow: () -> Bool = { return true }
    
    init(title: String, subTitle: String? = nil, icon: UIImage? = nil, accessoryText: (() -> String)? = nil, callback: @escaping () -> Void) {
        self.title = title
        self.subTitle = subTitle
        self.icon = icon?.withRenderingMode(.alwaysTemplate)
        self.accessoryText = accessoryText
        self.callback = callback
    }
    
    init(title: String, icon: UIImage? = nil, subMenu: [MenuItem], rootNav: UINavigationController, faqButton: UIButton? = nil) {
        let subMenuVC = MenuViewController(items: subMenu, title: title, faqButton: faqButton)
        self.init(title: title, icon: icon, accessoryText: nil) {
            rootNav.pushViewController(subMenuVC, animated: true)
        }
    }
}
