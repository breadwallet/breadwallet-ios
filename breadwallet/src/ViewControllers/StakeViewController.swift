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
        
        titleLabel.text = "Earn money while holding"
        caption.text = "Delegate your Tezos account to a validator to earn a reward while keeping full security and control of your coins."
        
        titleLabel.textAlignment = .center
        caption.textAlignment = .center
        
        caption.numberOfLines = 0
        caption.lineBreakMode = .byWordWrapping
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[2]),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        caption.constrain([
            caption.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[3]),
            caption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            caption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[3])
        ])
        addressCaption.constrain([
            addressCaption.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: C.padding[3]),
            addressCaption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            addressCaption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[3])
        ])
        address.constrain([
            address.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            address.topAnchor.constraint(equalTo: addressCaption.bottomAnchor, constant: C.padding[4]),
            address.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            address.heightAnchor.constraint(equalToConstant: 44.0)
        ])
        infoView.constrain([
            infoView.trailingAnchor.constraint(equalTo: address.trailingAnchor),
            infoView.topAnchor.constraint(equalTo: address.bottomAnchor, constant: C.padding[1])
        ])
        infoView.textAlignment = .right
        address.borderStyle = .roundedRect
        address.placeholder = "Enter Validator Address"
        address.backgroundColor = .whiteTint
        
        pasteButton.setTitle("Paste", for: .normal)
        
        address.addSubview(pasteButton)
        
        pasteButton.constrain([
            pasteButton.trailingAnchor.constraint(equalTo: address.trailingAnchor, constant: -C.padding[2]),
            pasteButton.centerYAnchor.constraint(equalTo: address.centerYAnchor)
        ])
        
        pasteButton.tap = pasteTapped
        button.tap = stakeTapped
        
        button.constrain([
            button.constraint(.leading, toView: view, constant: C.padding[2]),
            button.constraint(.trailing, toView: view, constant: -C.padding[2]),
            button.constraint(toBottom: address, constant: C.padding[4]),
            button.constraint(.height, constant: C.Sizes.buttonHeight),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneX ? -C.padding[5] : -C.padding[2]) ])
        
        setInitialData()
    }
    
    private func setInitialData() {
        if let validatorAddress = currency.wallet?.stakedValidatorAddress {
            addressCaption.text = "You're Staked!"
            addressCaption.textColor = UIColor.green
            
            address.text = validatorAddress
            address.isEnabled = false
            address.borderStyle = .none
            pasteButton.isUserInteractionEnabled = false
            pasteButton.isHidden = true
            
            button.title = "Unstake"
            
        } else {
            
        }
    }
    
    private func stakeTapped() {
        let confirmation = ConfirmationViewController(amount: Amount.zero(currency),
                                                      fee: Amount.zero(currency),
                                                      displayFeeLevel: FeeLevel.regular,
                                                      address: address.text!,
                                                      isUsingBiometrics: true,
                                                      currency: currency)
        let transitionDelegate = PinTransitioningDelegate()
        transitionDelegate.shouldShowMaskView = true
        confirmation.transitioningDelegate = transitionDelegate
        confirmation.modalPresentationStyle = .overFullScreen
        confirmation.modalPresentationCapturesStatusBarAppearance = true
        confirmation.successCallback = { [weak self] in
            //TODO pin entry/auth
            self?.confirmed()
        }
        confirmation.cancelCallback = {
            //callback(false)
        }
        
        present(confirmation, animated: true, completion: nil)
        
    }
    
    private func confirmed() {
        guard let address = currency.wallet?.receiveAddress else { return }
        sender.stake(address: address)
    }
    
    private func send() {
        
    }
    
    private func reset() {
        
    }
    
    private func pasteTapped() {
        guard let string = UIPasteboard.general.string else { return }
        if currency.isValidAddress(string) {
            showValidAddress()
            address.text = string
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

// MARK: - ModalDisplayable

extension StakeViewController: ModalDisplayable {
    var faqArticleId: String? {
        return ""
    }
    
    var faqCurrency: Currency? {
        return currency
    }

    var modalTitle: String {
        return "Staking \(currency.code)"
    }
}
