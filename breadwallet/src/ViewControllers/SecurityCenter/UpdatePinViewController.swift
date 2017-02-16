//
//  UpdatePinViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class UpdatePinViewController : UIViewController {

    //MARK: - Public
    init(store: Store, walletManager: WalletManager) {
        self.store = store
        self.walletManager = walletManager
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let header = UILabel.wrapping(font: .customBold(size: 26.0), color: .darkText)
    private let instruction = UILabel.wrapping(font: .customBody(size: 14.0), color: .darkText)
    private let caption = UILabel.wrapping(font: .customBody(size: 13.0), color: .secondaryGrayText)
    private let pinView = PinView(style: .create)
    private let pinPad = PinPadViewController(style: .white, keyboardType: .pinPad)
    private let store: Store
    private let walletManager: WalletManager
    private var step: Step = .current {
        didSet {
            switch step {
            case .current:
                instruction.text = S.UpdatePin.enterCurrent
            case .new:
                instruction.pushNewText(S.UpdatePin.enterNew)
                caption.text = S.UpdatePin.caption
            case .confirmNew:
                instruction.pushNewText(S.UpdatePin.reEnterNew)
            }
        }
    }
    private var currentPin: String?
    private var newPin: String?

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
        view.backgroundColor = .white

        header.text = S.UpdatePin.title
        instruction.text = S.UpdatePin.enterCurrent

        pinPad.ouputDidUpdate = { text in
            switch self.step {
            case .current:
                self.didUpdateForCurrent(pin: text)
            case .new :
                self.didUpdateForNew(pin: text)
            case .confirmNew:
                self.didUpdateForConfirmNew(pin: text)
            }
        }
    }

    private func didUpdateForCurrent(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == 6 {
            if walletManager.authenticate(pin: pin) {
                pushNewStep(.new)
                currentPin = pin
            } else {
                clearAfterFailure()
            }
        }
    }

    private func didUpdateForNew(pin: String) {
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == 6 {
            newPin = pin
            pushNewStep(.confirmNew)
        }
    }

    private func didUpdateForConfirmNew(pin: String) {
        guard let newPin = newPin else { return }
        pinView.fill(pin.utf8.count)
        if pin.utf8.count == 6 {
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

    private func pushNewStep(_ newStep: Step) {
        step = newStep
        pinPad.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pinView.fill(0)
        }
    }

    private func didSetNewPin() {
        guard let currentPin = currentPin else { return }
        guard let newPin = newPin else { return }
        let result = walletManager.forceSetPin(newPin: newPin, seedPhrase: walletManager.seedPhrase(pin: currentPin))
        let message = result ? "Success" : "Failed"
        let alert = UIAlertController(title: "Set pin", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .destructive, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
