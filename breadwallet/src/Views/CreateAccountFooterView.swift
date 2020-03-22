// 
//  CreateAccountFooterView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-03-19.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class CreateAccountFooterView: UIView {
    
    private let currency: Currency
    private var hasSetup = false
    private let button = UIButton.rounded(title: "Create Account")
    init(currency: Currency) {
        self.currency = currency
        super.init(frame: .zero)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasSetup else { return }
        setup()
        hasSetup = true
    }
    
    private func setup() {
        addViews()
        addConstraints()
        setInitialData()
    }
    
    private func addViews() {
        button.tintColor = .white
        button.backgroundColor = .transparentWhite
        addSubview(button)
    }
    
    private func addConstraints() {
        button.constrain([
            button.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[1]),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.heightAnchor.constraint(equalToConstant: 44.0),
            button.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.66)])
    }
    
    private func setInitialData() {
        backgroundColor = currency.colors.1
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
