//
//  PinPadCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-15.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class PinPadCell : UICollectionViewCell {

    var text: String? {
        didSet {
            label.text = text
        }
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                label.backgroundColor = .lightGray
            } else {
                label.backgroundColor = .white
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private let label = UILabel(font: .customBody(size: 26.0))

    private func setup() {
        label.textColor = .grayTextTint
        label.textAlignment = .center
        label.backgroundColor = .white
        addSubview(label)
        label.constrain(toSuperviewEdges: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
