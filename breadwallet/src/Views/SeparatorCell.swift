//
//  SeparatorCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-01.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class SeparatorCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        let separator = UIView()
        separator.backgroundColor = Theme.secondaryBackground
        addSubview(separator)
        contentView.backgroundColor = .clear
        backgroundColor = Theme.primaryBackground
        selectedBackgroundView = UIView.init(color: UIColor.navigationTint.withAlphaComponent(0.7))
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
