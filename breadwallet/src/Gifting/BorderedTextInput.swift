// 
//  BorderedTextInput.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-11-20.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class BorderedTextInput: UIView {
    
    private let placeholder = UILabel(font: Theme.caption, color: .white)
    private let textField = UITextField()
    private let placeholderText: String
    
    init(placeholder: String) {
        self.placeholderText = placeholder
        super.init(frame: .zero)
        addSubviews()
        setupConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        addSubview(placeholder)
        addSubview(textField)
    }
    
    private func setupConstraints() {
        placeholder.constrain([
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[1]),
            placeholder.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[1])
        ])
        textField.constrain([
            textField.leadingAnchor.constraint(equalTo: placeholder.leadingAnchor),
            textField.topAnchor.constraint(equalTo: placeholder.bottomAnchor, constant: C.padding[1]),
            textField.heightAnchor.constraint(equalToConstant: 44.0),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1])
        ])
    }
    
    private func setInitialData() {
        placeholder.text = placeholderText
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = 4
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
