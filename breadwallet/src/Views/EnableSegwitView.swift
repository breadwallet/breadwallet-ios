//
//  EnableSegwitView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-10-11.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class EnableSegwitView: UIView {
    
    private let label = UILabel.wrapping(font: .customBody(size: 13.0), color: .white)
    private let cancel = BRDButton(title: S.Button.cancel, type: .secondary)
    private let continueButton = BRDButton(title: S.Button.continueAction, type: .primary)
    
    var didCancel: (() -> Void)? {
        didSet { cancel.tap = didCancel }
    }
    var didContinue: (() -> Void)? {
        didSet { continueButton.tap = didContinue }
    }
    
    init() {
        super.init(frame: .zero)
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addSubviews() {
        addSubview(label)
        addSubview(cancel)
        addSubview(continueButton)
    }
    
    private func addConstraints() {
        label.constrain([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            label.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]) ])
        cancel.constrain([
            cancel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: C.padding[2]),
            cancel.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -C.padding[1]),
            cancel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            cancel.heightAnchor.constraint(equalToConstant: 48.0),
            cancel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[2])])
        continueButton.constrain([
            continueButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: C.padding[2]),
            continueButton.leadingAnchor.constraint(equalTo: centerXAnchor, constant: C.padding[1]),
            continueButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            continueButton.heightAnchor.constraint(equalToConstant: 48.0)])
    }
    
    private func setInitialData() {
        backgroundColor = Theme.secondaryBackground
        layer.masksToBounds = true
        layer.cornerRadius = 8.0
        label.text = S.Segwit.confirmChoiceLayout
    }
    
}
