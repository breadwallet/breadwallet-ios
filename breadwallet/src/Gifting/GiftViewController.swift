// 
//  GiftViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-11-20.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit
import WalletKit

class GiftViewController: UIViewController {
    
    //TODO:GIFT - sending protocol for these?
    var presentVerifyPin: ((String, @escaping ((String) -> Void)) -> Void)?
    var onPublishSuccess: (() -> Void)?
    
    private let sender: Sender
    private let wallet: Wallet
    private let currency: Currency
    
    init(sender: Sender, wallet: Wallet, currency: Currency) {
        self.sender = sender
        self.wallet = wallet
        self.currency = currency
        super.init(nibName: nil, bundle: nil)
    }
    
    private let gradientView = GradientView()
    private let titleLabel = UILabel(font: Theme.body1, color: .white)
    private let topBorder = UIView(color: .white)
    private let qr = UIImageView(image: UIImage(named: "GiftQR"))
    private let header = UILabel.wrapping(font: Theme.boldTitle, color: .white)
    private let subHeader = UILabel.wrapping(font: Theme.body1, color: UIColor.white.withAlphaComponent(0.85))
    private let amountHeader = UILabel(font: Theme.caption, color: .white)
    
    private let customAmount = BorderedTextInput(placeholder: "Custom amount ($500 max)")
    private let name = BorderedTextInput(placeholder: "Recipient's Name")
    private let bottomBorder = UIView(color: .white)
    private let createButton: UIButton = {
        let button = UIButton.rounded(title: "Create")
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = 4
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        return button
    }()
    private let amounts = [25, 50, 100, 250, 500]
    private let toolbar = UIStackView()
    private var buttons = [UIButton]()
    private var selectedIndex: Int = -1
    private let sendingActivity = BRActivityViewController(message: S.TransactionDetails.titleSending)
    private let extraSwitch = UISwitch()
    private let extraLabel = UILabel.wrapping(font: Theme.caption, color: .white)
    
    override func viewDidLoad() {
        addSubviews()
        setupConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        view.addSubview(gradientView)
        view.addSubview(titleLabel)
        view.addSubview(topBorder)
        view.addSubview(qr)
        view.addSubview(header)
        view.addSubview(subHeader)
        view.addSubview(amountHeader)
        view.addSubview(toolbar)
        view.addSubview(customAmount)
        view.addSubview(name)
        view.addSubview(extraSwitch)
        view.addSubview(extraLabel)
        view.addSubview(bottomBorder)
        view.addSubview(createButton)
        addButtons()
    }
    
    private func setupConstraints() {
        gradientView.constrain(toSuperviewEdges: nil)
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[4]),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        topBorder.constrain([
            topBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBorder.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[1]),
            topBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1.0)])
        qr.constrain([
            qr.topAnchor.constraint(equalTo: topBorder.bottomAnchor, constant: C.padding[4]),
            qr.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        header.constrain([
            header.topAnchor.constraint(equalTo: qr.bottomAnchor, constant: C.padding[2]),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[6]),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[6])])
        subHeader.constrain([
            subHeader.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            subHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            subHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])])
        amountHeader.constrain([
            amountHeader.topAnchor.constraint(equalTo: subHeader.bottomAnchor, constant: C.padding[2]),
            amountHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            amountHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])])
        toolbar.constrain([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            toolbar.topAnchor.constraint(equalTo: amountHeader.bottomAnchor, constant: C.padding[2]),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            toolbar.heightAnchor.constraint(equalToConstant: 44.0)])
        customAmount.constrain([
            customAmount.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            customAmount.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: C.padding[2]),
            customAmount.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])])
        name.constrain([
            name.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            name.topAnchor.constraint(equalTo: customAmount.bottomAnchor, constant: C.padding[2]),
            name.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])])
        
        extraSwitch.constrain([
            extraSwitch.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            extraSwitch.topAnchor.constraint(equalTo: name.bottomAnchor, constant: C.padding[2])
        ])
        
        extraLabel.constrain([
            extraLabel.leadingAnchor.constraint(equalTo: extraSwitch.trailingAnchor, constant: C.padding[1]),
            extraLabel.centerYAnchor.constraint(equalTo: extraSwitch.centerYAnchor),
            extraLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2])
        ])
        
        bottomBorder.constrain([
            bottomBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBorder.topAnchor.constraint(equalTo: extraLabel.bottomAnchor, constant: C.padding[3]),
            bottomBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1.0)])
        createButton.constrain([
            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            createButton.topAnchor.constraint(equalTo: bottomBorder.bottomAnchor, constant: C.padding[3]),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            createButton.heightAnchor.constraint(equalToConstant: 44.0)])
    }
    
    private func setInitialData() {
        titleLabel.text = "Give the Gift of Bitcoin"
        header.text = "Send Bitcoin to someone\n even if they don't have a wallet."
        header.textAlignment = .center
        subHeader.text = """
            We'll create what's called a \"paper wallet\" with a QR code and instructions for installing BRD that you can email or text to friends and family
            """
        subHeader.textAlignment = .center
        amountHeader.text = "Choose amount ($USD)"
        toolbar.distribution = .fillEqually
        toolbar.spacing = 8.0
        extraSwitch.onTintColor = .white
        extraLabel.text = "add an additional $10 for import network fees"
        extraLabel.numberOfLines = 0
        extraLabel.lineBreakMode = .byWordWrapping
        createButton.tap = create
        
    }
    
    private func create() {
        let result = wallet.createExportablePaperWallet()
        guard case .success(let paperWallet) = result else { return handleCreatePaperWalletError() }
        guard let address = paperWallet.address else { return handleCreatePaperWalletError() }
        guard let privKey = paperWallet.privateKey else { return handleCreatePaperWalletError() }
        
        let amount = Amount(tokenString: "0.002", currency: currency)
        sender.estimateFee(address: address.description, amount: amount, tier: .regular, completion: { [weak self] feeBasis in
            guard let `self` = self else { return }
            guard let feeBasis = feeBasis else { return }
            let feeCurrency = self.sender.wallet.feeCurrency
            let fee = Amount(cryptoAmount: feeBasis.fee, currency: feeCurrency)

            let rate = Rate(code: "USD", name: "USD", rate: 18000.0, reciprocalCode: "BTC")
            
            let displayAmount = Amount(amount: amount,
                                      rate: rate,
                                      maximumFractionDigits: Amount.highPrecisionDigits)
            let feeAmount = Amount(amount: fee,
                                   rate: rate,
                                   maximumFractionDigits: Amount.highPrecisionDigits)
            
            let gift = Gift.create(key: privKey, hash: nil)
            _ = self.sender.createTransaction(address: address.description, amount: amount, feeBasis: feeBasis, comment: "Gift to <name>", gift: gift)
            
            DispatchQueue.main.async {
                let confirm = ConfirmationViewController(amount: displayAmount,
                                                         fee: feeAmount,
                                                         displayFeeLevel: .regular,
                                                         address: address.description,
                                                         isUsingBiometrics: self.sender.canUseBiometrics,
                                                         currency: self.currency,
                                                         resolvedAddress: nil,
                                                         shouldShowMaskView: false)
                confirm.successCallback = self.send
                confirm.cancelCallback = self.sender.reset
                self.present(confirm, animated: true, completion: nil)
            }
        })
        
    }
    
    private func send() {
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
        sender.sendTransaction(allowBiometrics: true, pinVerifier: pinVerifier) { [weak self] result in
            guard let `self` = self else { return }
            self.sendingActivity.dismiss(animated: true) {
                defer { self.sender.reset() }
                switch result {
                case .success:
                    self.dismiss(animated: true) {
                        Store.trigger(name: .showStatusBar)
                        self.onPublishSuccess?()
                    }
                    //self.saveEvent("send.success")
                case .creationError(let message):
                    self.showAlert(title: S.Alerts.sendFailure, message: message, buttonLabel: S.Button.ok)
                    //self.saveEvent("send.publishFailed", attributes: ["errorMessage": message])
                case .publishFailure(let code, let message):
                    self.showAlert(title: S.Alerts.sendFailure, message: "\(message) (\(code))", buttonLabel: S.Button.ok)
                    //self.saveEvent("send.publishFailed", attributes: ["errorMessage": "\(message) (\(code))"])
                case .insufficientGas(let rpcErrorMessage):
                    print("blah: \(rpcErrorMessage)")
                    //self.showInsufficientGasError()
                    //self.saveEvent("send.publishFailed", attributes: ["errorMessage": rpcErrorMessage])
                }
            }
        }
    }
    
    private func handleCreatePaperWalletError() {
        
    }
    
    private func addButtons() {
        let buttons: [UIButton] = amounts.map {
            let button = UIButton.rounded(title: "$ \($0)")
            button.tintColor = .white
            button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            button.layer.cornerRadius = 4
            button.layer.borderWidth = 0.5
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
            return button
        }
        for (index, button) in buttons.enumerated() {
            self.toolbar.addArrangedSubview(button)
            button.tap = {
                self.didTap(index: index)
            }
        }
        self.buttons = buttons
    }
    
    private func didTap(index: Int) {
        let selectedButton = buttons[index]
        let previousSelectedButton: UIButton? = selectedIndex >= 0 ? buttons[selectedIndex] : nil
        
        selectedIndex = index
        
        UIView.animate(withDuration: 0.4, animations: {
            selectedButton.backgroundColor = UIColor.white.withAlphaComponent(0.85)
            selectedButton.layer.cornerRadius = 4
            selectedButton.layer.borderWidth = 0.5
            selectedButton.layer.borderColor = UIColor.white.cgColor
            selectedButton.tintColor = UIColor.fromHex("FF7E47")
            
            previousSelectedButton?.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            previousSelectedButton?.layer.cornerRadius = 4
            previousSelectedButton?.layer.borderWidth = 0.5
            previousSelectedButton?.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
            previousSelectedButton?.tintColor = .white
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
