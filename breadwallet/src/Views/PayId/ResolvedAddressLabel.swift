// 
//  PayIdLabel.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-06-08.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class ResolvedAddressLabel: UILabel {
    
    var type: ResolvableType? {
        didSet {
            self.text = type?.label
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .secondaryButton
        self.layer.cornerRadius = 2.0
        self.layer.masksToBounds = true
        self.font = Theme.body1
        self.textColor = .grayTextTint
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
