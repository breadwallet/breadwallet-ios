//
//  ConfirmPaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ConfirmPaperPhraseViewController: UIViewController {

    private let label =                 UILabel.wrapping(font: UIFont.customBody(size: 16.0))
    private let confirmFirstPhrase =    ConfirmPhrase(text: "Word 3")
    private let confirmSecondPhrase =   ConfirmPhrase(text: "Word 8")
    private let submit =                ShadowButton(title: NSLocalizedString("Submit", comment: "button label"), type: .primary)

    private let store: Store

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        label.text = "Prove you wrote down your paper key by answering the following questions."
        addSubviews()
        addConstraints()
        addButtonActions()

        confirmFirstPhrase.textField.becomeFirstResponder()
    }

    private func addSubviews() {
        view.addSubview(label)
        view.addSubview(confirmFirstPhrase)
        view.addSubview(confirmSecondPhrase)
        view.addSubview(submit)
    }

    private func addConstraints() {
        label.constrainTopCorners(sidePadding: Constants.Padding.single, topPadding: Constants.Padding.double, topLayoutGuide: topLayoutGuide)
        confirmFirstPhrase.constrain([
                confirmFirstPhrase.constraint(toBottom: label, constant: 0.0),
                confirmFirstPhrase.constraint(.width, toView: view, constant: 0.0),
                confirmFirstPhrase.constraint(.centerX, toView: view, constant: 0.0)
            ])
        confirmSecondPhrase.constrain([
                confirmSecondPhrase.constraint(toBottom: confirmFirstPhrase, constant: 0.0),
                confirmSecondPhrase.constraint(.width, toView: view, constant: 0.0),
                confirmSecondPhrase.constraint(.centerX, toView: view, constant: 0.0)
            ])
    }

    private func addButtonActions() {
        submit.addTarget(self, action: #selector(checkTextFields), for: .touchUpInside)
    }

    private func addSubmitButtonConstraints(keyboardHeight: CGFloat) {
        submit.constrain([
                NSLayoutConstraint(item: submit, attribute: .bottom, relatedBy: .equal, toItem: bottomLayoutGuide, attribute: .top, multiplier: 1.0, constant: -Constants.Padding.single - keyboardHeight),
                submit.constraint(.leading, toView: view, constant: Constants.Padding.double),
                submit.constraint(.trailing, toView: view, constant: -Constants.Padding.double),
                submit.constraint(.height, constant: Constants.Sizes.buttonHeight)
            ])
    }

    @objc private func checkTextFields() {

        //TODO - These strings should be received from the store and more feedback for incorrect strings should be added
        if confirmFirstPhrase.textField.text == "liverish" && confirmSecondPhrase.textField.text == "mandarin" {
            store.perform(action: PaperPhrase.Confirmed())
        }
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        if let frameValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue {
            self.addSubmitButtonConstraints(keyboardHeight: frameValue.cgRectValue.height)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
