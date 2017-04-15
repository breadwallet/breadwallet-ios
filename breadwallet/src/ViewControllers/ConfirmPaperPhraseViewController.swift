//
//  ConfirmPaperPhraseViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ConfirmPaperPhraseViewController : UIViewController {

    init(store: Store, walletManager: WalletManager, pin: String) {
        self.store = store
        self.pin = pin
        self.walletManager = walletManager
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
    }

    var didConfirm: (() -> Void)?

    private let label = UILabel.wrapping(font: UIFont.customBody(size: 16.0))
    lazy private var confirmFirstPhrase: ConfirmPhrase = { ConfirmPhrase(text: "\(S.ConfirmPaperPhrase.word) \(self.indices.0 + 1)") }()
    lazy private var confirmSecondPhrase: ConfirmPhrase = { ConfirmPhrase(text: "\(S.ConfirmPaperPhrase.word) \(self.indices.1 + 1)") }()
    private let submit = ShadowButton(title: S.Button.submit, type: .primary)
    private let header = RadialGradientView(backgroundColor: .brand)
    private let store: Store
    private let pin: String
    private let walletManager: WalletManager

    //Select 2 random indices from 1 to 10. The second number must
    //be at least one number away from the first.
    private let indices: (Int, Int) = {
        func random() -> Int { return Int(arc4random_uniform(10) + 1) }
        let first = random()
        var second = random()
        while !(abs(Int32(second - first)) > 1) {
            second = random()
        }
        return (first, second)
    }()
    lazy private var words: [String] = {
        guard let phraseString = self.walletManager.seedPhrase(pin: self.pin) else { return [] }
        return phraseString.components(separatedBy: " ")
    }()

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        label.text = S.ConfirmPaperPhrase.label
        label.textColor = .white
        
        addSubviews()
        addConstraints()
        addButtonActions()

        confirmFirstPhrase.textField.becomeFirstResponder()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private func addSubviews() {
        view.addSubview(header)
        header.addSubview(label)
        view.addSubview(confirmFirstPhrase)
        view.addSubview(confirmSecondPhrase)
        view.addSubview(submit)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0, topPadding: 0)
        header.constrain([
            header.constraint(.height, constant: 152.0) ])
        label.constrainBottomCorners(sidePadding: C.padding[1], bottomPadding: C.padding[2])
        confirmFirstPhrase.constrain([
            confirmFirstPhrase.constraint(toBottom: header, constant: 0.0),
            confirmFirstPhrase.constraint(.width, toView: view, constant: 0.0),
            confirmFirstPhrase.constraint(.centerX, toView: view, constant: 0.0) ])
        confirmSecondPhrase.constrain([
            confirmSecondPhrase.constraint(toBottom: confirmFirstPhrase, constant: 0.0),
            confirmSecondPhrase.constraint(.width, toView: view, constant: 0.0),
            confirmSecondPhrase.constraint(.centerX, toView: view, constant: 0.0) ])
    }

    private func addButtonActions() {
        submit.addTarget(self, action: #selector(checkTextFields), for: .touchUpInside)
    }

    private func addSubmitButtonConstraints(keyboardHeight: CGFloat) {
        submit.constrain([
            NSLayoutConstraint(item: submit, attribute: .bottom, relatedBy: .equal, toItem: bottomLayoutGuide, attribute: .top, multiplier: 1.0, constant: -C.padding[1] - keyboardHeight),
            submit.constraint(.leading, toView: view, constant: C.padding[2]),
            submit.constraint(.trailing, toView: view, constant: -C.padding[2]),
            submit.constraint(.height, constant: C.Sizes.buttonHeight) ])
    }

    @objc private func checkTextFields() {
        //TODO - These strings should be received from the store and more feedback for incorrect strings should be added
        if confirmFirstPhrase.textField.text == words[indices.0] && confirmSecondPhrase.textField.text == words[indices.1] {
            UserDefaults.writePaperPhraseDate = Date()
            if didConfirm != nil {
                didConfirm?()
            } else {
                store.perform(action: PaperPhrase.Confirmed())
            }
        }
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        guard let frameValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue else { return }
        self.addSubmitButtonConstraints(keyboardHeight: frameValue.cgRectValue.height)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
