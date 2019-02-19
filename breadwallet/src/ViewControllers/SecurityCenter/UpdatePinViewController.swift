//
//  UpdatePinViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

enum UpdatePinType {
    case creationNoPhrase
    case creationWithPhrase
    case update
}

class UpdatePinViewController: UIViewController, Subscriber {

    // MARK: - Public
    var setPinSuccess: ((String) -> Void)?
    var resetFromDisabledSuccess: (() -> Void)?
    var resetFromDisabledWillSucceed: (() -> Void)?

    init(keyMaster: KeyMaster, type: UpdatePinType, showsBackButton: Bool = true, phrase: String? = nil) {
        self.keyMaster = keyMaster
        self.phrase = phrase
        self.pinView = PinView(style: .create, length: Store.state.pinLength)
        self.showsBackButton = showsBackButton
        self.faq = UIButton.buildFaqButton(articleId: ArticleIds.setPin)
        self.type = type
        super.init(nibName: nil, bundle: nil)
    }

    // MARK: - Private
    private let header = UILabel.wrapping(font: .customBold(size: 26.0), color: .white)
    private let instruction = UILabel.wrapping(font: .customBody(size: 14.0), color: .white)
    private let caption = UILabel.wrapping(font: .customBody(size: 13.0), color: .white)
    private var pinView: PinView
    private let pinPadBackground = UIView(color: .white)
    private let pinPad = PinPadViewController(style: .clear, keyboardType: .pinPad, maxDigits: 0, shouldShowBiometrics: false)
    private let spacer = UIView()
    private let keyMaster: KeyMaster
    private let faq: UIButton
    private var step: Step = .verify {
        didSet {
            switch step {
            case .verify:
                instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent
                caption.isHidden = true
            case .new:
                let instructionText = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterNew
                if instruction.text != instructionText {
                    instruction.pushNewText(instructionText)
                }
                header.text = S.UpdatePin.createTitle
                caption.isHidden = false
            case .confirmNew:
                caption.isHidden = true
                if isCreatingPin {
                    header.text = S.UpdatePin.createTitleConfirm
                } else {
                    instruction.pushNewText(S.UpdatePin.reEnterNew)
                }
            }
        }
    }
    private var currentPin: String?
    private var newPin: String?
    private var phrase: String?
    private let type: UpdatePinType
    private var isCreatingPin: Bool {
        return type != .update
    }
    private let newPinLength = 6
    private let showsBackButton: Bool

    private enum Step {
        case verify
        case new
        case confirmNew
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(instruction)
        view.addSubview(caption)
        view.addSubview(pinView)
        view.addSubview(faq)
        view.addSubview(spacer)
        view.addSubview(pinPadBackground)
    }

    private func addConstraints() {
        header.constrain([
            header.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2]),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.trailingAnchor.constraint(equalTo: faq.leadingAnchor, constant: -C.padding[1]) ])
        instruction.constrain([
            instruction.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            instruction.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            instruction.trailingAnchor.constraint(equalTo: header.trailingAnchor) ])
        pinView.constrain([
            pinView.centerYAnchor.constraint(equalTo: spacer.centerYAnchor),
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
        addPinPad()
        spacer.constrain([
            spacer.topAnchor.constraint(equalTo: instruction.bottomAnchor),
            spacer.bottomAnchor.constraint(equalTo: caption.topAnchor) ])
        faq.constrain([
            faq.topAnchor.constraint(equalTo: header.topAnchor),
            faq.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            faq.constraint(.height, constant: 44.0),
            faq.constraint(.width, constant: 44.0)])
        caption.constrain([
            caption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            caption.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[2]),
            caption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
    }

    private func addPinPad() {
        addChildViewController(pinPad)
        pinPadBackground.addSubview(pinPad.view)
        pinPadBackground.constrain([
            pinPadBackground.widthAnchor.constraint(equalToConstant: floor(view.bounds.width/3.0)*3.0),
            pinPadBackground.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinPadBackground.heightAnchor.constraint(equalToConstant: pinPad.height),
            pinPadBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneX ? -C.padding[3] : 0.0) ])
        pinPad.view.constrain(toSuperviewEdges: nil)
        pinPad.didMove(toParentViewController: self)
    }

    private func setData() {
        caption.text = S.UpdatePin.caption
        view.backgroundColor = .darkBackground
        faq.tintColor = .white
        header.text = isCreatingPin ? S.UpdatePin.createTitle : S.UpdatePin.updateTitle
        instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent
        pinPad.ouputDidUpdate = { [weak self] text in
            guard let step = self?.step else { return }
            switch step {
            case .verify:
                self?.didUpdateForCurrent(pin: text)
            case .new :
                self?.didUpdateForNew(pin: text)
            case .confirmNew:
                self?.didUpdateForConfirmNew(pin: text)
            }
        }

        if isCreatingPin {
            step = .new
            caption.isHidden = false
        } else {
            caption.isHidden = true
        }

        if !showsBackButton {
            navigationItem.leftBarButtonItem = nil
            navigationItem.hidesBackButton = true
        }
    }

    private func didUpdateForCurrent(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == Store.state.pinLength {
            if keyMaster.authenticate(withPin: pin) {
                pushNewStep(.new)
                currentPin = pin
                replacePinView()
            } else {
                if keyMaster.walletDisabledUntil > 0 {
                    dismiss(animated: true, completion: {
                        Store.perform(action: RequireLogin())
                    })
                } else {
                    clearAfterFailure()
                }
            }
        }
    }

    private func didUpdateForNew(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == newPinLength {
            newPin = pin
            pushNewStep(.confirmNew)
        }
    }

    private func didUpdateForConfirmNew(pin: String) {
        guard let newPin = newPin else { return }
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == newPinLength {
            if pin == newPin {
                didSetNewPin()
            } else {
                clearAfterFailure()
                pushNewStep(.new)
            }
        }
    }

    private func clearAfterFailure() {
        pinPad.view.isUserInteractionEnabled = false
        pinView.shake { [weak self] in
            self?.pinPad.view.isUserInteractionEnabled = true
            self?.pinView.fill(0)
        }
        pinPad.clear()
    }

    private func replacePinView() {
        pinView.removeFromSuperview()
        pinView = PinView(style: .create, length: newPinLength)
        view.addSubview(pinView)
        pinView.constrain([
            pinView.centerYAnchor.constraint(equalTo: spacer.centerYAnchor),
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
    }

    private func pushNewStep(_ newStep: Step) {
        step = newStep
        pinPad.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pinView.fill(0)
        }
    }

    private func didSetNewPin() {
        guard let newPin = newPin else { return }
        var success: Bool? = false
        if let seedPhrase = phrase {
            success = keyMaster.resetPin(newPin: newPin, seedPhrase: seedPhrase)
        } else if let currentPin = currentPin {
            success = keyMaster.changePin(newPin: newPin, currentPin: currentPin)
            DispatchQueue.main.async { Store.trigger(name: .didUpgradePin) }
        } else if type == .creationNoPhrase {
            success = keyMaster.setPin(newPin)
        }

        DispatchQueue.main.async {
            if let success = success, success == true {
                if self.resetFromDisabledSuccess != nil {
                    self.resetFromDisabledWillSucceed?()
                    Store.perform(action: Alert.Show(.pinSet(callback: { [weak self] in
                        self?.dismiss(animated: true, completion: {
                            self?.resetFromDisabledSuccess?()
                        })
                    })))
                } else {
                    Store.perform(action: Alert.Show(.pinSet(callback: { [weak self] in
                        self?.setPinSuccess?(newPin)
                        if self?.type != .creationNoPhrase {
                            self?.parent?.dismiss(animated: true, completion: nil)
                        }
                    })))
                }

            } else {
                let alert = UIAlertController(title: S.UpdatePin.updateTitle, message: S.UpdatePin.setPinError, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: { [weak self] _ in
                    self?.clearAfterFailure()
                    self?.pushNewStep(.new)
                }))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
