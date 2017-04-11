//
//  PinCreationViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let setPinText = NSLocalizedString("Set PIN", comment: "Set pin instruction")
private let confirmPinText = NSLocalizedString("Re-Enter PIN", comment: "Confirm pin instruction")
private let wrongPinText = NSLocalizedString("Wrong PIN , please try again", comment: "Wrong pin entered instruction")

class PinCreationViewController : UIViewController, Subscriber {

    private let instruction = UILabel.wrapping(font: .customBold(size: 26.0))
    private let caption = UILabel.wrapping(font: .customBody(size: 14.0))
    private let body = UILabel.wrapping(font: .customBody(size: 13.0))

    //This hidden Textfield is used under the hood for pin entry
    //PinView is what actually gets displayed on the screen
    private let hiddenPin: UITextField = {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.isSecureTextEntry = true
        textField.isHidden = true
        return textField
    }()

    private let pinView = PinView(style: .create, length: 6)
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
        hiddenPin.becomeFirstResponder()
        hiddenPin.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        hiddenPin.delegate = self
        addStoreSubscriptions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        store.unsubscribe(self)
    }

    private func setData() {
        caption.text = NSLocalizedString("Your PIN will be used to unlock your  Bread and send money.", comment: "Set Pin screen caption")
        body.text = NSLocalizedString("Write down your PIN and store it in a place you can access even if your phone is broken or lost.", comment: "Set Pin screen body")

        instruction.textColor = .darkText
        caption.textColor = .darkText
        body.textColor = .secondaryGrayText
    }

    private func addSubviews() {
        view.addSubview(instruction)
        view.addSubview(caption)
        view.addSubview(hiddenPin)
        view.addSubview(body)
        view.addSubview(pinView)
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        if let frameValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue {
            self.addBodyConstraints(keyboardHeight: frameValue.cgRectValue.height)
        }
    }

    private func addConstraints() {
        instruction.constrain([
            NSLayoutConstraint(item: instruction, attribute: .top, relatedBy: .equal, toItem: topLayoutGuide, attribute: .bottom, multiplier: 1.0, constant: C.padding[3]),
            instruction.constraint(.leading, toView: view, constant: C.padding[2]),
            instruction.constraint(.trailing, toView: view, constant: -C.padding[2]) ])
        caption.constrain([
            caption.constraint(toBottom: instruction, constant: C.padding[2]),
            caption.constraint(.leading, toView: instruction, constant: nil),
            caption.constraint(.trailing, toView: view, constant: -C.padding[2]) ])
        pinView.constrain([
            pinView.constraint(toBottom: caption, constant: C.padding[3]),
            pinView.constraint(.centerX, toView: view, constant: nil),
            pinView.constraint(.height, constant: pinView.itemSize),
            pinView.constraint(.width, constant: pinView.width) ])
    }

    private func addBodyConstraints(keyboardHeight: CGFloat) {
        body.constrain([
            NSLayoutConstraint(item: body, attribute: .bottom, relatedBy: .equal, toItem: bottomLayoutGuide, attribute: .top, multiplier: 1.0, constant: -C.padding[1] - keyboardHeight),
            body.constraint(.leading, toView: view, constant: C.padding[2]),
            body.constraint(.trailing, toView: view, constant: -C.padding[2]) ])
    }

    private func addStoreSubscriptions() {
        store.subscribe(self,
                        selector: {
                            //It's possible to get repeat confirmFail state updates, so
                            //we need to subscribe to all of them, even if the state doesn't change
                            if case .confirmFail(_) = $0.pinCreationStep {
                                return true
                            } else {
                                return $0.pinCreationStep != $1.pinCreationStep
                            }
                        },
                        callback: { state in
                            self.handlePinCreationStepChange(state: state)
                        })
    }

    private func handlePinCreationStepChange(state: State) {
        switch state.pinCreationStep {
        case .start:
            instruction.text = setPinText
        case .confirm:
            instruction.text = confirmPinText
            hiddenPin.text = ""
            //If this delay isn't here, the last pin filling in is never seen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.pinView.fill(0)
            }
        case .save:
            instruction.text = confirmPinText
        case .confirmFail:
            instruction.text = wrongPinText
            hiddenPin.text = ""
            pinView.shake()
            DispatchQueue.main.asyncAfter(deadline: .now() + pinView.shakeDuration) { [weak self] in
                self?.pinView.fill(0)
            }
        case .saveSuccess:
            print("noop")
        case .none:
            print("noop")
        }
    }

    @objc private func textFieldDidChange(textField: UITextField) {
        guard let pinLength = textField.text?.lengthOfBytes(using: .utf8) else { return }
        pinView.fill(pinLength)
        if pinLength == maxPinLength {
            store.perform(action: PinCreation.PinEntryComplete(newPin: textField.text!))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PinCreationViewController : UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let oldLength = textField.text?.lengthOfBytes(using: .utf8) else { return true }
        let replacementLength = string.lengthOfBytes(using: .utf8)
        let rangeLength = range.length
        let newLength = oldLength - rangeLength + replacementLength
        return newLength <= maxPinLength
    }
}
