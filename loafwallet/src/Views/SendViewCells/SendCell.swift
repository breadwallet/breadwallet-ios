//
//  SendCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-01.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class SendCell : UIView {

    static let defaultHeight: CGFloat = 60.0
    
    init() {
        super.init(frame: .zero)
        setupViews()
    }

    let accessoryView = UIView()
    let border = UIView(color: .secondaryShadow)

    private func setupViews() {
        addSubview(accessoryView)
        addSubview(border)
        accessoryView.constrain([
            accessoryView.constraint(.top, toView: self),
            accessoryView.constraint(.trailing, toView: self),
            accessoryView.heightAnchor.constraint(equalToConstant: SendCell.defaultHeight) ])
        border.constrainBottomCorners(height: 1.0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

