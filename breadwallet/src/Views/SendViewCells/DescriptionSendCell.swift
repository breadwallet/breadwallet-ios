//
//  DescriptionSendCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class DescriptionSendCell : SendCell {

    init(placeholder: String) {
        super.init()
        let attributes: [String: Any] = [
            NSForegroundColorAttributeName: UIColor.grayTextTint,
            NSFontAttributeName : placeholderFont
        ]
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: attributes)
        textField.tintColor = C.defaultTintColor
        textField.delegate = self
        textField.textColor = .darkText
        textField.returnKeyType = .done
        setupViews()
    }


    var textFieldDidBeginEditing: (() -> Void)?
    var textFieldDidReturn: ((UITextField) -> Void)?
    var textFieldDidChange: ((String) -> Void)?
    var content: String? {
        didSet {
            textField.text = content
            textField.sendActions(for: .editingChanged)
            guard let count = content?.characters.count else { return }
            textField.font = count > 0 ? textFieldFont : placeholderFont
        }
    }

    func setLabel(text: String, color: UIColor) {
        label.text = text
        label.textColor = color
    }

    private let placeholderFont = UIFont.customBody(size: 16.0)
    private let textFieldFont = UIFont.customBody(size: 26.0)
    let textField = UITextField()
    fileprivate let label = UILabel(font: .customBody(size: 14.0), color: .grayTextTint)

    private func setupViews() {
        addSubview(textField)
        addSubview(label)
        textField.constrain([
            textField.constraint(.leading, toView: self, constant: C.padding[2]),
            textField.centerYAnchor.constraint(equalTo: accessoryView.centerYAnchor),
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 30.0),
            textField.constraint(toLeading: accessoryView, constant: 0.0) ])
        label.constrain([
            label.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            label.topAnchor.constraint(equalTo: accessoryView.bottomAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1]) ])
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        textField.addTarget(self, action: #selector(DescriptionSendCell.editingChanged(textField:)), for: .editingChanged)
    }

    @objc private func editingChanged(textField: UITextField) {
        guard let text = textField.text else { return }
        textFieldDidChange?(text)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DescriptionSendCell : UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textFieldDidBeginEditing?()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textFieldDidReturn?(textField)
        return true
    }
}
