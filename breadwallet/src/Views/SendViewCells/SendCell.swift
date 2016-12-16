//
//  SendCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-01.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class SendCell : UIView {

    init() {
        super.init(frame: .zero)
        setupViews()
    }

    let accessoryView = UIView()

    private let border = UIView()

    private func setupViews() {
        addSubview(accessoryView)
        addSubview(border)
        accessoryView.constrain([
            accessoryView.constraint(.top, toView: self),
            accessoryView.constraint(.trailing, toView: self),
            accessoryView.constraint(.bottom, toView: self) ])

        border.constrainBottomCorners(height: 1.0)
        border.backgroundColor = .secondaryShadow
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

