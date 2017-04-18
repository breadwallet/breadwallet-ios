//
//  UpdatePinViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class UpdatePinViewController : UIViewController, Subscriber {

    //MARK: - Public
    var setPinSuccess: (() -> Void)?

    init(store: Store, walletManager: WalletManager, phrase: String? = nil) {
        self.store = store
        self.walletManager = walletManager
        self.phrase = phrase
        self.pinView = PinView(style: .create, length: walletManager.pinLength)
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let header = UILabel.wrapping(font: .customBold(size: 26.0), color: .darkText)
    private let instruction = UILabel.wrapping(font: .customBody(size: 14.0), color: .darkText)
    private let caption = UILabel.wrapping(font: .customBody(size: 13.0), color: .secondaryGrayText)
    private var pinView: PinView
    private let pinPad = PinPadViewController(style: .white, keyboardType: .pinPad)
    private let store: Store
    private let walletManager: WalletManager
    private var step: Step = .current {
        didSet {
            switch step {
            case .current:
                instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent
            case .new:
                if !isCreatingPin {
                    instruction.pushNewText(S.UpdatePin.enterNew)
                }
                caption.text = S.UpdatePin.caption
            case .confirmNew:
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
    private var isCreatingPin: Bool {
        return phrase != nil
    }
    private let newPinLength = 6

    private enum Step {
        case current
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
    }

    private func addConstraints() {
        header.constrain([
            header.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2]),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        instruction.constrain([
            instruction.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            instruction.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            instruction.trailingAnchor.constraint(equalTo: header.trailingAnchor) ])
        pinView.constrain([
            pinView.topAnchor.constraint(equalTo: instruction.bottomAnchor, constant: C.padding[6]),
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
        addChildViewController(pinPad, layout: {
            pinPad.view.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
            pinPad.view.constrain([pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height) ])
        })
        caption.constrain([
            caption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            caption.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[2]),
            caption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
    }

    private func setData() {
        view.backgroundColor = .whiteTint

        header.text = isCreatingPin ? S.UpdatePin.createTitle : S.UpdatePin.updateTitle
        instruction.text = isCreatingPin ? S.UpdatePin.createInstruction : S.UpdatePin.enterCurrent

        pinPad.ouputDidUpdate = { [weak self] text in
            guard let step = self?.step else { return }
            switch step {
            case .current:
                self?.didUpdateForCurrent(pin: text)
            case .new :
                self?.didUpdateForNew(pin: text)
            case .confirmNew:
                self?.didUpdateForConfirmNew(pin: text)
            }
        }

        if phrase != nil {
            step = .new
        }
    }

    private func didUpdateForCurrent(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == walletManager.pinLength {
            if walletManager.authenticate(pin: pin) {
                pushNewStep(.new)
                currentPin = pin
                replacePinView()
            } else {
                if walletManager.walletDisabledUntil > 0 {
                    dismiss(animated: true, completion: {
                        self.store.perform(action: RequireLogin())
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
            }
        }
    }

    private func clearAfterFailure() {
        DispatchQueue.main.asyncAfter(deadline: .now() + pinView.shakeDuration) { [weak self] in
            self?.pinView.fill(0)
        }
        pinView.shake()
        pinPad.clear()
    }

    private func replacePinView() {
        pinView.removeFromSuperview()
        pinView = PinView(style: .create, length: newPinLength)
        view.addSubview(pinView)
        pinView.constrain([
            pinView.topAnchor.constraint(equalTo: instruction.bottomAnchor, constant: C.padding[6]),
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
        var seedPhrase: String?
        if phrase != nil {
            seedPhrase = phrase
        } else {
            guard let currentPin = currentPin else { return }
            seedPhrase = walletManager.seedPhrase(pin: currentPin)
        }

        guard let newPin = newPin else { return }
        guard seedPhrase != nil else { return }

        if walletManager.forceSetPin(newPin: newPin, seedPhrase: seedPhrase) {
            setPinSuccess?()
            store.perform(action: Alert.Show(.pinSet))
            store.lazySubscribe(self,
                            selector: { $0.alert != $1.alert && $1.alert == nil },
                            callback: { _ in
                self.parent?.dismiss(animated: true, completion: {
                    self.store.unsubscribe(self)
                })
            })
        } else {
            let alert = UIAlertController(title: S.UpdatePin.updateTitle, message: S.UpdatePin.setPinError, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: { [weak self] _ in
                self?.clearAfterFailure()
                self?.pushNewStep(.new)
            }))
            present(alert, animated: true, completion: nil)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
