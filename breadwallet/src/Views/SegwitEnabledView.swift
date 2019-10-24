//
//  SegwitEnabledView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-10-11.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class SegwitEnabledView: UIView {
    
    private let primaryLabel = UILabel.wrapping(font: .customBody(size: 13.0), color: .white)
    private let secondaryLabel = UILabel.wrapping(font: .customBody(size: 11.0), color: .white)
    let home = BRDButton(title: S.Segwit.homeButton, type: .primary)
    let checkView = LinkStatusCircle(colour: .greenCheck)
    
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
        addSubview(checkView)
        addSubview(primaryLabel)
        addSubview(secondaryLabel)
        addSubview(home)
    }
    
    private func addConstraints() {
        checkView.constrain([
            checkView.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]),
            checkView.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkView.heightAnchor.constraint(equalToConstant: 96.0),
            checkView.widthAnchor.constraint(equalToConstant: 96.0) ])
        primaryLabel.constrain([
            primaryLabel.topAnchor.constraint(equalTo: checkView.bottomAnchor, constant: C.padding[2]),
            primaryLabel.centerXAnchor.constraint(equalTo: centerXAnchor)])
        secondaryLabel.constrain([
            secondaryLabel.topAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: C.padding[1]),
            secondaryLabel.centerXAnchor.constraint(equalTo: centerXAnchor)])
        home.constrain([
            home.topAnchor.constraint(equalTo: secondaryLabel.bottomAnchor, constant: C.padding[2]),
            home.leadingAnchor.constraint(equalTo: leadingAnchor),
            home.bottomAnchor.constraint(equalTo: bottomAnchor),
            home.trailingAnchor.constraint(equalTo: trailingAnchor),
            home.heightAnchor.constraint(equalToConstant: 48.0)])
        
    }
    
    private func setInitialData() {
        backgroundColor = Theme.secondaryBackground
        layer.masksToBounds = true
        layer.cornerRadius = 8.0
        
        primaryLabel.text = S.Segwit.confirmationConfirmationTitle
        primaryLabel.textAlignment = .center
        
        secondaryLabel.text = S.Segwit.confirmationInstructionsDescription
        secondaryLabel.textAlignment = .center

    }
}
