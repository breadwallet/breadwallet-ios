//
//  LabelSendCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class LabelSendCell : SendCell {

    init(label: String) {
        super.init()
        self.label.text = label
        setupViews()
    }

    var content: String? {
        didSet {
            contentLabel.text = content
        }
    }

    private let label = UILabel(font: .customBody(size: 16.0))
    private let contentLabel = UILabel(font: .customBody(size: 14.0))

    private func setupViews() {
        addSubview(label)
        addSubview(contentLabel)
        label.constrain([
            label.constraint(.centerY, toView: self),
            label.constraint(.leading, toView: self, constant: C.padding[2]) ])
        contentLabel.constrain([
            contentLabel.constraint(.leading, toView: label),
            contentLabel.constraint(toBottom: label, constant: 0.0),
            contentLabel.constraint(toLeading: accessoryView, constant: -C.padding[2]) ])
        label.textColor = .grayTextTint
        contentLabel.lineBreakMode = .byTruncatingMiddle
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
