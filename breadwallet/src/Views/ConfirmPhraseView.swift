//
//  ConfirmPhrase.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

private let circleRadius: CGFloat = 12.0

class ConfirmPhraseView: UIView {

    let textField = UITextField()
    var callback: (() -> Void)?
    var doneCallback: (() -> Void)?

    init(text: String, word: String) {
        self.word = word
        super.init(frame: CGRect())
        label.text = text
        setupSubviews()
    }

    internal let word: String
    private let label = UILabel()
    private let separator = UIView()
    private let circle = DrawableCircle()

    private func setupSubviews() {
        label.font = UIFont.customBody(size: 14.0)
        label.textColor = UIColor(white: 170.0/255.0, alpha: 1.0)
        separator.backgroundColor = .separatorGray

        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.font = UIFont.customBody(size: 16.0)
        textField.textColor = .white
        textField.delegate = self

        addSubview(label)
        addSubview(textField)
        addSubview(separator)
        addSubview(circle)

        label.constrain([
            label.constraint(.leading, toView: self, constant: C.padding[1]),
            label.constraint(.top, toView: self, constant: C.padding[1]) ])
        textField.constrain([
            textField.constraint(.leading, toView: label, constant: nil),
            textField.constraint(toBottom: label, constant: C.padding[1]/2.0),
            textField.constraint(.width, toView: self, constant: -C.padding[1]*2) ])

        separator.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
        separator.constrain([
            //This contraint to the bottom of the textField is pretty crucial. Without it,
            //this view will have an intrinsicHeight of 0
            separator.constraint(toBottom: textField, constant: C.padding[1]),
            separator.constraint(.height, constant: 1.0) ])
        circle.constrain([
            circle.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            circle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            circle.heightAnchor.constraint(equalToConstant: circleRadius*2.0),
            circle.widthAnchor.constraint(equalToConstant: circleRadius*2.0) ])

        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
    }

    func validate() {
        if textField.text != word {
            textField.textColor = .cameraGuideNegative
        }
    }

    @objc private func textFieldChanged() {
        textField.textColor = .white
        guard textField.markedTextRange == nil else { return }
        if textField.text == word {
            circle.show()
            if !E.isIPhone4 {
                textField.isEnabled = false
            }
            callback?()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ConfirmPhraseView: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        validate()
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.textColor = .white
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if E.isIPhone4 {
            doneCallback?()
        }
        return true
    }
}
