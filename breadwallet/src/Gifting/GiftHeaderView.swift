// 
//  GiftHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-12-06.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class GiftHeaderView: UIView {
    
    let close = UIButton.close
    private let titleLabel = UILabel(font: Theme.body1, color: .white)
    private let border = UIView(color: .white)
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        addSubview(titleLabel)
        addSubview(close)
        addSubview(border)
    }
    
    private func addConstraints() {
        close.constrain([
            close.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[1]),
            close.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.heightAnchor.constraint(equalToConstant: 44.0),
            close.widthAnchor.constraint(equalToConstant: 44.0)])
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor) ])
        border.constrain([
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1.0),
                            border.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)])
    }
    
    private func setInitialData() {
        titleLabel.text = "Give the Gift of Bitcoin"
        titleLabel.textAlignment = .center
        close.tintColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
