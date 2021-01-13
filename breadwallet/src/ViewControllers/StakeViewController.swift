// 
//  StakeViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-10-18.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class StakeViewController: UIViewController, Subscriber, Trackable, ModalPresentable {
    
    var presentVerifyPin: ((String, @escaping ((String) -> Void)) -> Void)?
    var onPublishSuccess: (() -> Void)?
    
    private let currency: Currency
    private let sender: Sender
    
    var parentView: UIView? //ModalPresentable
    
    private let titleLabel = UILabel(font: .customBold(size: 17.0))
    private let caption = UILabel(font: .customBody(size: 15.0))
    private let addressCaption = UILabel(font: .customBody(size: 15.0))
    private let address = UITextField()
    private let button = BRDButton(title: "Stake", type: .primary)
    private let pasteButton = UIButton(type: .system)
    private let infoView = UILabel(font: .customBold(size: 14.0))
    private let sendingActivity = BRActivityViewController(message: S.TransactionDetails.titleSending)
    
    init(currency: Currency, sender: Sender) {
        self.currency = currency
        self.sender = sender
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(titleLabel)
        view.addSubview(caption)
        view.addSubview(addressCaption)
        view.addSubview(address)
        view.addSubview(button)
        view.addSubview(infoView)
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[2]),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        caption.constrain([
            caption.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[3]),
            caption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            caption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[3])])
        addressCaption.constrain([
            addressCaption.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: C.padding[3]),
            addressCaption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            addressCaption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[3])])
        address.constrain([
            address.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            address.topAnchor.constraint(equalTo: addressCaption.bottomAnchor, constant: C.padding[4]),
            address.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            address.heightAnchor.constraint(equalToConstant: 44.0)])
        infoView.constrain([
            infoView.trailingAnchor.constraint(equalTo: address.trailingAnchor),
            infoView.topAnchor.constraint(equalTo: address.bottomAnchor, constant: C.padding[1])])
        address.addSubview(pasteButton)
        pasteButton.constrain([
            pasteButton.trailingAnchor.constraint(equalTo: address.trailingAnchor, constant: -C.padding[2]),
            pasteButton.centerYAnchor.constraint(equalTo: address.centerYAnchor)])
        button.constrain([
            button.constraint(.leading, toView: view, constant: C.padding[2]),
            button.constraint(.trailing, toView: view, constant: -C.padding[2]),
            button.constraint(toBottom: address, constant: C.padding[4]),
            button.constraint(.height, constant: C.Sizes.buttonHeight),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneX ? -C.padding[5] : -C.padding[2]) ])
        
        setInitialData()
    }
    
    private func setInitialData() {
        titleLabel.text = "Earn money while holding"
        caption.text = "Delegate your Tezos account to a validator to earn a reward while keeping full security and control of your coins."
        
        titleLabel.textAlignment = .center
        caption.textAlignment = .center
        
        caption.numberOfLines = 0
        caption.lineBreakMode = .byWordWrapping
        
        infoView.textAlignment = .right
        
        address.borderStyle = .roundedRect
        address.placeholder = "Enter Validator Address"
        address.backgroundColor = .whiteTint
        pasteButton.setTitle("Paste", for: .normal)
        
        pasteButton.tap = pasteTapped
        button.tap = stakeTapped
        button.isEnabled = false
        address.delegate = self
        
        //Shouldn't be allowed to send stake/unstake transaction while a pending transaction
        //is present
        if currency.wallet?.hasPendingTxn == true {
            button.isEnabled = false
            infoView.text = "Pending Transaction - please try later"
            infoView.textColor = Theme.accent
        } else {
            //Is Staked
            if let validatorAddress = currency.wallet?.stakedValidatorAddress {
                addressCaption.text = "You're Staked!"
                addressCaption.textColor = UIColor.green
                address.text = validatorAddress
                pasteButton.isUserInteractionEnabled = false
                pasteButton.isHidden = true
                button.isEnabled = true
                button.title = "Unstake"
            }
        }
        
        address.editingChanged = { [weak self] in
            self?.validate()
        }
    }
    
    private func stakeTapped() {
        if currency.wallet?.isStaked == true {
            unstake()
        } else {
            stake()
        }
    }
    
    private func stake() {
        guard let addressText = address.text, currency.isValidAddress(addressText) else {
            showInvalidAddress()
            return
        }
        confirm(address: addressText) { [weak self] success in
            guard success else { return }
            self?.send(address: addressText)
        }
    }
    
    private func unstake() {
        guard let address = currency.wallet?.receiveAddress else { return }
        confirm(address: address) { [weak self] success in
            guard success else { return }
            self?.send(address: address)
        }
    }
    
    private func send(address: String) {
        let pinVerifier: PinVerifier = { [weak self] pinValidationCallback in
            guard let `self` = self else { return assertionFailure() }
            self.sendingActivity.dismiss(animated: false) {
                self.presentVerifyPin?(S.VerifyPin.authorize) { pin in
                    self.parent?.view.isFrameChangeBlocked = false
                    pinValidationCallback(pin)
                    self.present(self.sendingActivity, animated: false)
                }
            }
        }
        
        present(sendingActivity, animated: true)
        sender.stake(address: address, pinVerifier: pinVerifier) { [weak self] result in
            guard let `self` = self else { return }
            self.sendingActivity.dismiss(animated: true) {
                defer { self.sender.reset() }
                switch result {
                case .success:
                    self.onPublishSuccess?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.dismiss(animated: true, completion: nil)
                    }
                case .creationError(let message):
                    self.showAlert(title: S.Alerts.sendFailure, message: message, buttonLabel: S.Button.ok)
                case .publishFailure(let code, let message):
                    self.showAlert(title: S.Alerts.sendFailure, message: "\(message) (\(code))", buttonLabel: S.Button.ok)
                case .insufficientGas(let rpcErrorMessage):
                    print("insufficientGas: \(rpcErrorMessage)")
                }
            }
        }
    }
    
    private func confirm(address: String, callback: @escaping (Bool) -> Void) {
        let confirmation = ConfirmationViewController(amount: Amount.zero(currency),
                                                      fee: Amount.zero(currency),
                                                      displayFeeLevel: FeeLevel.regular,
                                                      address: address,
                                                      isUsingBiometrics: true,
                                                      currency: currency,
                                                      shouldShowMaskView: true,
                                                      isStake: true)
        let transitionDelegate = PinTransitioningDelegate()
        transitionDelegate.shouldShowMaskView = true
        confirmation.transitioningDelegate = transitionDelegate
        confirmation.modalPresentationStyle = .overFullScreen
        confirmation.modalPresentationCapturesStatusBarAppearance = true
        confirmation.successCallback = { callback(true) }
        confirmation.cancelCallback = { callback(false) }
        present(confirmation, animated: true, completion: nil)
    }
    
    private func pasteTapped() {
        guard let string = UIPasteboard.general.string else { return }
        if currency.isValidAddress(string) {
            address.text = string
            
            showValidAddress()
            button.isEnabled = true
            pasteButton.isEnabled = false
            pasteButton.isHidden = true
        } else {
            showInvalidAddress()
        }
    }
    
    private func validate() {
        guard let addressString = address.text else { return }
        if currency.isValidAddress(addressString) {
            showValidAddress()
            button.isEnabled = true
            pasteButton.isEnabled = false
            pasteButton.isHidden = true
        } else {
            showInvalidAddress()
        }
    }
    
    private func showValidAddress() {
        infoView.text = "Valid address"
        infoView.textColor = .green
    }
    
    private func showInvalidAddress() {
        infoView.text = "Invalid Address"
        infoView.textColor = .red
    }
    
}

extension StakeViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return false
    }
}

// MARK: - ModalDisplayable

extension StakeViewController: ModalDisplayable {
    var faqArticleId: String? {
        return "staking"
    }
    
    var faqCurrency: Currency? {
        return currency
    }

    var modalTitle: String {
        return "Staking \(currency.code)"
    }
}
