//
//  MenuCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-31.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class MenuCell: SeparatorCell {
    
    static let cellIdentifier = "MenuCell"
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(item: MenuItem) {
        textLabel?.text = item.title
        textLabel?.font = .customBody(size: 16.0)
        // Disable Support for now. Not moving to an extension as it will be enabled in the future
        if item.title == S.MenuButton.support {
            textLabel?.textColor = .gray
            isUserInteractionEnabled = false
        } else {
            textLabel?.textColor = .white
        }
        
        imageView?.image = item.icon
        imageView?.tintColor = Theme.accent
        
        if let accessoryText = item.accessoryText?() {
            let label = UILabel(font: Theme.body1, color: Theme.primaryText)
            label.text = accessoryText
            label.sizeToFit()
            accessoryView = label
        } else {
            accessoryView = nil
            accessoryType = .none
        }
        
        if let subTitle = item.subTitle {
            detailTextLabel?.text = subTitle
            detailTextLabel?.font = Theme.caption
            detailTextLabel?.textColor = Theme.secondaryText
        } else {
            detailTextLabel?.text = nil
        }
    }
}
