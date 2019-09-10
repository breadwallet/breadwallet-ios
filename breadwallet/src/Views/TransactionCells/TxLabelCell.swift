//
//  TxLabelCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-20.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class TxLabelCell: TxDetailRowCell {
    
    // MARK: - Accessors
    
    public var value: String {
        get {
            return valueLabel.text ?? ""
        }
        set {
            valueLabel.text = newValue
        }
    }

    // MARK: - Views
    
    fileprivate let valueLabel = UILabel(font: UIFont.customBody(size: 14.0))
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(valueLabel)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        valueLabel.constrain([
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: C.padding[1]),
            valueLabel.constraint(.trailing, toView: container),
            valueLabel.constraint(.top, toView: container),
            valueLabel.constraint(.bottom, toView: container)
            ])
    }
    
    override func setupStyle() {
        super.setupStyle()
        valueLabel.textColor = .darkGray
        valueLabel.textAlignment = .right
    }
}
