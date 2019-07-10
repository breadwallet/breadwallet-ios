//
//  SendAmountCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-12.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class SendAmountCell: SendCell {

    init(placeholder: String) {
        super.init()
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.foregroundColor: UIColor.grayTextTint,
            NSAttributedString.Key.font: placeholderFont
        ]
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: attributes)
        textField.delegate = self
        textField.textColor = .darkText
        textField.inputView = UIView()
        setupViews()
    }

    var textFieldDidBeginEditing: (() -> Void)?
    var textFieldDidReturn: ((UITextField) -> Void)?
    var textFieldDidChange: ((String) -> Void)?
    var content: String? {
        didSet {
            textField.text = content
            textField.sendActions(for: .editingChanged)
            textField.font = content.isNilOrEmpty ? placeholderFont : textFieldFont
        }
    }
    
    func setLabel(text: String, color: UIColor) {
        label.text = text
        label.textColor = color
    }

    func setAmountLabel(text: String) {
        textField.isHidden = !text.utf8.isEmpty //Textfield should be hidden if amount label has text
        cursor.isHidden = !textField.isHidden
        amountLabel.text = text
    }

    private let placeholderFont = UIFont.customBody(size: 16.0)
    private let textFieldFont = UIFont.customBody(size: 26.0)
    let textField = UITextField()
    let label = UILabel(font: .customBody(size: 14.0), color: .grayTextTint)
    let amountLabel = UILabel(font: .customBody(size: 26.0), color: .darkText)
    private let cursor = BlinkingView(blinkColor: C.defaultTintColor)

    private func setupViews() {
        addSubview(textField)
        addSubview(label)
        addSubview(amountLabel)
        addSubview(cursor)

        textField.constrain([
            textField.constraint(.leading, toView: self, constant: C.padding[2]),
            textField.centerYAnchor.constraint(equalTo: accessoryView.centerYAnchor),
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 30.0),
            textField.constraint(toLeading: accessoryView, constant: 0.0) ])
        label.constrain([
            label.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            label.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: C.padding[2]),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            label.bottomAnchor.constraint(equalTo: bottomAnchor) ])
        amountLabel.constrain([
            amountLabel.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            amountLabel.topAnchor.constraint(equalTo: textField.topAnchor),
            amountLabel.bottomAnchor.constraint(equalTo: textField.bottomAnchor) ])
        cursor.constrain([
            cursor.leadingAnchor.constraint(equalTo: amountLabel.trailingAnchor, constant: 2.0),
            cursor.heightAnchor.constraint(equalTo: amountLabel.heightAnchor, constant: -4.0),
            cursor.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor),
            cursor.widthAnchor.constraint(equalToConstant: 2.0) ])

        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        textField.addTarget(self, action: #selector(SendAmountCell.editingChanged(textField:)), for: .editingChanged)
        cursor.startBlinking()
        cursor.isHidden = true
    }

    @objc private func editingChanged(textField: UITextField) {
        guard let text = textField.text else { return }
        textFieldDidChange?(text)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SendAmountCell: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textFieldDidBeginEditing?()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textFieldDidReturn?(textField)
        return true
    }
}
