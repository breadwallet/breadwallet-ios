//
//  TextFieldSendCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class TextFieldSendCell : SendCell {

    init(placeholder: String, isKeyboardHidden: Bool) {
        super.init()
        let attributes: [String: Any] = [
            NSForegroundColorAttributeName: UIColor.grayTextTint,
            NSFontAttributeName : placeholderFont
        ]
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: attributes)
        textField.tintColor = C.defaultTintColor
        textField.delegate = self
        textField.textColor = .darkText
        if isKeyboardHidden {
            textField.inputView = UIView()
        } else {
            textField.returnKeyType = .done
        }
        setupViews()
    }


    var textFieldDidBeginEditing: (() -> Void)?
    var textFieldDidReturn: ((UITextField) -> Void)?

    var content: String? {
        didSet {
            textField.text = content
            guard let count = content?.characters.count else { return }
            textField.font = count > 0 ? textFieldFont : placeholderFont
        }
    }

    private let placeholderFont = UIFont.customBody(size: 16.0)
    private let textFieldFont = UIFont.customBody(size: 26.0)
    let textField = UITextField()
    private func setupViews() {
        addSubview(textField)
        textField.constrain([
            textField.constraint(.leading, toView: self, constant: C.padding[2]),
            textField.constraint(.top, toView: self),
            textField.constraint(.bottom, toView: self),
            textField.constraint(toLeading: accessoryView, constant: 0.0) ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TextFieldSendCell : UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textFieldDidBeginEditing?()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textFieldDidReturn?(textField)
        return true
    }
}
