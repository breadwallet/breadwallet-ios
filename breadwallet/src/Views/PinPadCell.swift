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
            setColors()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private let label = UILabel(font: .customBody(size: 26.0))

    private func setup() {
        setColors()
        label.textAlignment = .center
        addSubview(label)
        label.constrain(toSuperviewEdges: nil)
        layer.cornerRadius = 4.0
        layer.masksToBounds = true
    }

    func setColors() {
        if isHighlighted {
            label.backgroundColor = .secondaryShadow
            label.textColor = .darkText
        } else {
            label.backgroundColor = .white
            label.textColor = .grayTextTint
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
