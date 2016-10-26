//
//  PinCreationViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class PinCreationViewController: UIViewController, Subscriber {

    private let instruction: UILabel = {
        let label = UILabel()
        return label
    }()

    private let caption: UILabel = {
        let label = UILabel()
        return label
    }()

    private let pin: UITextField = {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.isSecureTextEntry = true
        textField.placeholder = "●●●●●●"
        textField.font = UIFont.preferredFont(forTextStyle: .headline)
        return textField
    }()

    private let body: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    fileprivate let maxPinLength = 6
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
        setData()
        addSubviews()
        addConstraints()
        pin.becomeFirstResponder()
        pin.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        pin.delegate = self
        addStoreSubscriptions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        store.unsubscribe(self)
    }

    private func setData() {
        caption.text = "Your PIN will be used to login to Bread."
        body.text = "Write down your PIN and store it in a place you can access even if your phone is broken or lost."
    }

    private func addSubviews() {
        view.addSubview(instruction)
        view.addSubview(caption)
        view.addSubview(pin)
        view.addSubview(body)
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        if let frameValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue {
            self.addBodyConstraints(keyboardHeight: frameValue.cgRectValue.height)
        }
    }

    private func addConstraints() {
        instruction.constrain([
                NSLayoutConstraint(item: instruction, attribute: .top, relatedBy: .equal, toItem: topLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: Constants.Padding.triple),
                instruction.constraint(.leading, toView: view, constant: Constants.Padding.double)
            ])
        caption.constrain([
                caption.constraint(toBottom: instruction, constant: Constants.Padding.double),
                caption.constraint(.leading, toView: instruction, constant: nil)
            ])
        pin.constrain([
                pin.constraint(toBottom: caption, constant: Constants.Padding.triple),
                pin.constraint(.centerX, toView: view, constant: nil)
            ])
    }

    private func addBodyConstraints(keyboardHeight: CGFloat) {
        body.constrain([
                NSLayoutConstraint(item: body, attribute: .bottom, relatedBy: .equal, toItem: bottomLayoutGuide, attribute: .top, multiplier: 1.0, constant: -Constants.Padding.single - keyboardHeight),
                body.constraint(.leading, toView: view, constant: Constants.Padding.double),
                body.constraint(.trailing, toView: view, constant: -Constants.Padding.double)
            ])
    }

    private func addStoreSubscriptions() {
        store.subscribe(self, subscription: Subscription(
            selector: { $0.pinCreationStep != $1.pinCreationStep },
            callback: { state in
                switch state.pinCreationStep {
                    case .start:
                        self.instruction.text = "Set PIN"
                    case .confirm:
                        self.instruction.text = "Re-Enter PIN"
                        self.pin.text = ""
                    case .save:
                        self.instruction.text = "Re-Enter PIN"
                    case .none:
                        self.instruction.text = ""
                }
        }))
    }


    @objc private func textFieldDidChange(textField: UITextField) {
        if textField.text?.lengthOfBytes(using: .utf8) == maxPinLength {
            store.perform(action: PinCreation.PinEntryComplete())
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PinCreationViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let oldLength = textField.text?.lengthOfBytes(using: .utf8) else { return true }
        let replacementLength = string.lengthOfBytes(using: .utf8)
        let rangeLength = range.length
        let newLength = oldLength - rangeLength + replacementLength
        return newLength <= maxPinLength
    }

}
