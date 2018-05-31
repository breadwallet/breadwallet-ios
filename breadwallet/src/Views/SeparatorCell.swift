//
//  SeparatorCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-01.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class SeparatorCell : UITableViewCell {
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let separator = UIView()
        separator.backgroundColor = .separator
        addSubview(separator)
        contentView.backgroundColor = .lightHeaderBackground
        backgroundColor = .lightHeaderBackground
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SeparatorCell {
    func setSetting(_ setting: Setting) {
        textLabel?.text = setting.title
        textLabel?.font = .customBody(size: 16.0)
        textLabel?.textColor = .darkGray
        textLabel?.backgroundColor = .lightHeaderBackground

        if let accessoryText = setting.accessoryText?() {
            let label = UILabel(font: .customMedium(size: 16.0), color: .darkGray)
            label.text = accessoryText
            label.backgroundColor = .lightHeaderBackground
            label.sizeToFit()
            accessoryView = label
        } else {
            accessoryView = nil
            accessoryType = .disclosureIndicator
        }
    }
}
