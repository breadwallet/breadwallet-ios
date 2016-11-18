//
//  ConfirmPhrase.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit


class ConfirmPhrase: UIView {

    private let label =     UILabel()
    private let separator = UIView()
    let textField =         UITextField()

    init(text: String) {
        super.init(frame: CGRect())
        label.text = text
        setupSubviews()
    }

    private func setupSubviews() {
        label.font = UIFont.customBody(size: 14.0)
        label.textColor = UIColor(white: 170.0/255.0, alpha: 1.0)
        separator.backgroundColor = .separatorGray

        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no

        addSubview(label)
        addSubview(textField)
        addSubview(separator)

        label.constrain([
                label.constraint(.leading, toView: self, constant: C.padding[1]),
                label.constraint(.top, toView: self, constant: C.padding[1])
            ])
        textField.constrain([
                textField.constraint(.leading, toView: label, constant: nil),
                textField.constraint(toBottom: label, constant: C.padding[1]/2.0),
                textField.constraint(.width, toView: self, constant: -C.padding[1]*2)
            ])

        separator.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
        separator.constrain([
                //This contraint to the bottom of the textField is pretty crucial. Without it,
                //this view will have an intrinsicHeight of 0
                separator.constraint(toBottom: textField, constant: C.padding[1]),
                separator.constraint(.height, constant: 1.0)
            ])

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
