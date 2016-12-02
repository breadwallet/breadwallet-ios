//
//  SendCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-01.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class SendCell: UIView {

    init(label: String) {
        super.init(frame: .zero)
        self.label.text = label
        setupViews()
    }

    private let label = UILabel(font: .customBody(size: 16.0))
    private let border = UIView()

    private func setupViews() {
        addSubview(label)
        addSubview(border)
        label.constrain([
                label.constraint(.centerY, toView: self),
                label.constraint(.leading, toView: self, constant: C.padding[2])
            ])
        border.constrainBottomCorners(height: 1.0)

        border.backgroundColor = .secondaryShadow
        label.textColor = .grayTextTint
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
