//
//  ConfirmationViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-07-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

class ConfirmationViewController : UIViewController, ContentBoxPresenter {

    init(amount: Satoshis, fee: Satoshis, feeType: FeeType, state: State, selectedRate: Rate?, minimumFractionDigits: Int?, address: String, isUsingBiometrics: Bool, isDonation: Bool = false) {
        self.amount = amount
        self.feeAmount = fee
        self.feeType = feeType
        self.state = state
        self.selectedRate = selectedRate
        self.minimumFractionDigits = minimumFractionDigits
        self.addressText = address
        self.isUsingBiometrics = isUsingBiometrics
        
        self.header = ModalHeaderView(title: S.Confirmation.title, style: .dark)
        super.init(nibName: nil, bundle: nil)
    }

    private let amount: Satoshis
    private let feeAmount: Satoshis
    private let feeType: FeeType
    private let state: State
    private let selectedRate: Rate?
    private let minimumFractionDigits: Int?
    private let addressText: String
    private let isUsingBiometrics: Bool
    
    //ContentBoxPresenter
    let contentBox = UIView(color: .white)
    let blurView = UIVisualEffectView()
    let effect = UIBlurEffect(style: .dark)

    var successCallback: (() -> Void)?
    var cancelCallback: (() -> Void)?

    private var header: ModalHeaderView?
    private let cancel = ShadowButton(title: S.Button.cancel, type: .flatWhiteBorder)
    private let sendButton = ShadowButton(title: S.Confirmation.send, type: .flatLitecoinBlue, image: (LAContext.biometricType() == .face ? #imageLiteral(resourceName: "FaceId") : #imageLiteral(resourceName: "TouchId")))

    private let payLabel = UILabel(font: .barlowLight(size: 15.0), color: .grayTextTint)
    private let toLabel = UILabel(font: .barlowLight(size: 15.0), color: .grayTextTint)
    private let amountLabel = UILabel(font: .barlowRegular(size: 15.0), color: .darkText)
    private let address = UILabel(font: .barlowRegular(size: 15.0), color: .darkText)

    private let processingTime = UILabel.wrapping(font: .barlowLight(size: 14.0), color: .grayTextTint)
    private let sendLabel = UILabel(font: .barlowLight(size: 14.0), color: .darkGray)
    private let feeLabel = UILabel(font: .barlowLight(size: 14.0), color: .darkGray)
    private let totalLabel = UILabel(font: .barlowLight(size: 14.0), color: .darkGray)

    private let send = UILabel(font: .barlowRegular(size: 15.0), color: .darkText)
    private let fee = UILabel(font: .barlowRegular(size: 15.0), color: .darkText)
    private let total = UILabel(font: .barlowMedium(size: 15.0), color: .darkText)

    override func viewDidLoad() {
         
        DispatchQueue.main.async(execute: {
            self.addSubviews()
            self.addConstraints()
            self.setInitialData()
        })
    }

    private func addSubviews() {
        view.addSubview(contentBox)
        
        guard let header = header else {
            NSLog("ERROR: Header not initialized")
            return
        }
        
        contentBox.addSubview(header)
        contentBox.addSubview(payLabel)
        contentBox.addSubview(toLabel)
        contentBox.addSubview(amountLabel)
        contentBox.addSubview(address)
        contentBox.addSubview(processingTime)
        contentBox.addSubview(sendLabel)
        contentBox.addSubview(feeLabel)
        contentBox.addSubview(totalLabel)
        contentBox.addSubview(send)
        contentBox.addSubview(fee)
        contentBox.addSubview(total)
        contentBox.addSubview(cancel)
        contentBox.addSubview(sendButton)
    }

    private func addConstraints() {
        
        guard let header = header else {
            NSLog("ERROR: Header not initialized")
            return
        }
        
        contentBox.constrain([
            contentBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentBox.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentBox.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[6] ) ])
        header.constrainTopCorners(height: 49.0)
        payLabel.constrain([
            payLabel.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: C.padding[2]),
            payLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]) ])
        amountLabel.constrain([
            amountLabel.leadingAnchor.constraint(equalTo: payLabel.leadingAnchor),
            amountLabel.topAnchor.constraint(equalTo: payLabel.bottomAnchor)])
        toLabel.constrain([
            toLabel.leadingAnchor.constraint(equalTo: amountLabel.leadingAnchor),
            toLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: C.padding[2]) ])
        address.constrain([
            address.leadingAnchor.constraint(equalTo: toLabel.leadingAnchor),
            address.topAnchor.constraint(equalTo: toLabel.bottomAnchor),
            address.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])
        processingTime.constrain([
            processingTime.leadingAnchor.constraint(equalTo: address.leadingAnchor),
            processingTime.topAnchor.constraint(equalTo: address.bottomAnchor, constant: C.padding[2]),
            processingTime.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])
        sendLabel.constrain([
            sendLabel.leadingAnchor.constraint(equalTo: processingTime.leadingAnchor),
            sendLabel.topAnchor.constraint(equalTo: processingTime.bottomAnchor, constant: C.padding[2]) ])
        send.constrain([
            send.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]),
            sendLabel.firstBaselineAnchor.constraint(equalTo: send.firstBaselineAnchor) ])
        feeLabel.constrain([
            feeLabel.leadingAnchor.constraint(equalTo: sendLabel.leadingAnchor),
            feeLabel.topAnchor.constraint(equalTo: sendLabel.bottomAnchor) ])
        fee.constrain([
            fee.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]),
            fee.firstBaselineAnchor.constraint(equalTo: feeLabel.firstBaselineAnchor) ])
        totalLabel.constrain([
            totalLabel.leadingAnchor.constraint(equalTo: feeLabel.leadingAnchor),
            totalLabel.topAnchor.constraint(equalTo: feeLabel.bottomAnchor) ])
        total.constrain([
            total.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]),
            total.firstBaselineAnchor.constraint(equalTo: totalLabel.firstBaselineAnchor) ])
        cancel.constrain([
            cancel.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: C.padding[2]),
            cancel.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: C.padding[2]),
            cancel.trailingAnchor.constraint(equalTo: contentBox.centerXAnchor, constant: -C.padding[1]),
            cancel.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -C.padding[2]) ])
        sendButton.constrain([
            sendButton.leadingAnchor.constraint(equalTo: contentBox.centerXAnchor, constant: C.padding[1]),
            sendButton.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: C.padding[2]),
            sendButton.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]),
            sendButton.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -C.padding[2]) ])
    }

    private func setInitialData() {
        view.backgroundColor = .clear
        payLabel.text = S.Confirmation.send
        guard let header = header else {
            NSLog("ERROR: Header not initialized")
            return
        }
         
        switch feeType {
        case .luxury:
            processingTime.text = String(format: S.Confirmation.processingTime, "2.5-5")
        case .regular:
            processingTime.text = String(format: S.Confirmation.processingTime, "2.5-5")
        case .economy:
            processingTime.text = String(format: S.Confirmation.processingTime, "5+")
        }
        
        let displayAmount = DisplayAmount(amount: amount, state: state, selectedRate: selectedRate, minimumFractionDigits: 2)
        let displayFee = DisplayAmount(amount: feeAmount, state: state, selectedRate: selectedRate, minimumFractionDigits: 2)
        let displayTotal = DisplayAmount(amount: amount + feeAmount, state: state, selectedRate: selectedRate, minimumFractionDigits: 2)

        toLabel.text = S.Confirmation.to
        feeLabel.text = S.Confirmation.feeLabel
        sendLabel.text = S.Confirmation.amountLabel
        totalLabel.text = S.Confirmation.totalLabel
        
        amountLabel.text = displayAmount.combinedDescription
        address.text = self.addressText
        
        send.text = displayAmount.description
        fee.text = displayFee.description.replacingZeroFeeWithOneCent()
        total.text = displayTotal.description

        cancel.tap = strongify(self) { myself in
            myself.cancelCallback?()
        }
        header.closeCallback = strongify(self) { myself in
            myself.cancelCallback?()
        }
        sendButton.tap = strongify(self) { myself in
            myself.successCallback?()
        }

        contentBox.layer.cornerRadius = 6.0
        contentBox.layer.masksToBounds = true

        if !isUsingBiometrics {
            sendButton.image = nil
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
