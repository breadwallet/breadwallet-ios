//
//  TxAddressCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxAddressCell: TxDetailRowCell {

    // MARK: - Accessors
    
    public var address: String {
        get {
            return addressLabel.text ?? ""
        }
        set {
            addressLabel.text = newValue
        }
    }
    
    // MARK: - Views
    
    private let addressLabel = UILabel(font: UIFont.customMedium(size: 13.0))
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(addressLabel)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        addressLabel.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        addressLabel.constrain([
            addressLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: C.padding[1]),
            //titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: addressLabel.leadingAnchor, constant: -C.padding[1]),
            addressLabel.constraint(.trailing, toView: container, constant: -C.padding[2]),
            addressLabel.constraint(.top, toView: container, constant: C.padding[2])
            ])
    }
    
    override func setupStyle() {
        super.setupStyle()
        addressLabel.textColor = .darkText
        addressLabel.lineBreakMode = .byTruncatingMiddle
        addressLabel.textAlignment = .right
    }

}
