//
//  SendCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-01.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class SendCell : UIView {

    init(placeholder: String) {
        super.init(frame: .zero)
        let attributes: [String: Any] = [
            NSForegroundColorAttributeName: UIColor.grayTextTint,
            NSFontAttributeName : placeholderFont
        ]
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: attributes)
        textField.tintColor = C.defaultTintColor
        textField.delegate = self
        textField.textColor = .darkText
        setupViews()
    }

    init(label: String) {
        super.init(frame: .zero)
        self.label.text = label
        setupViews()
    }

    var content: String? {
        didSet {
            if textField.placeholder != nil {
                textField.text = content
                guard let count = content?.characters.count else { return }
                textField.font = count > 0 ? textFieldFont : placeholderFont
            } else {
                contentLabel.text = content
            }
        }
    }

    var textFieldDidBeginEditing: (() -> Void)?

    let accessoryView = UIView()

    fileprivate let placeholderFont = UIFont.customBody(size: 16.0)
    fileprivate let textFieldFont = UIFont.customBody(size: 26.0)

    private let label = UILabel(font: .customBody(size: 16.0))
    private let textField = UITextField()
    private let contentLabel = UILabel(font: .customBody(size: 14.0))
    private let border = UIView()

    private func setupViews() {
        addSubview(label)
        addSubview(textField)
        addSubview(contentLabel)
        addSubview(accessoryView)
        addSubview(border)
        label.constrain([
            label.constraint(.centerY, toView: self),
            label.constraint(.leading, toView: self, constant: C.padding[2]) ])
        textField.constrain([
            textField.constraint(.leading, toView: self, constant: C.padding[2]),
            textField.constraint(.top, toView: self),
            textField.constraint(.bottom, toView: self) ])
        contentLabel.constrain([
            contentLabel.constraint(.leading, toView: label),
            contentLabel.constraint(toBottom: label, constant: 0.0),
            contentLabel.constraint(toLeading: accessoryView, constant: -C.padding[2]) ])
        accessoryView.constrain([
            accessoryView.constraint(.top, toView: self),
            accessoryView.constraint(.trailing, toView: self),
            accessoryView.constraint(.bottom, toView: self) ])
        border.constrainBottomCorners(height: 1.0)

        border.backgroundColor = .secondaryShadow
        label.textColor = .grayTextTint
        contentLabel.lineBreakMode = .byTruncatingMiddle
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SendCell : UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textFieldDidBeginEditing?()
    }
}
