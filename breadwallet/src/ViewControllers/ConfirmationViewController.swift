//
//  ConfirmationViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-07-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class ConfirmationViewController : UIViewController, ContentBoxPresenter {

    init(amount: Satoshis, fee: Satoshis, feeType: Fee, state: State, selectedRate: Rate?, minimumFractionDigits: Int?, address: String, isUsingTouchId: Bool) {
        self.amount = amount
        self.feeAmount = fee
        self.feeType = feeType
        self.state = state
        self.selectedRate = selectedRate
        self.minimumFractionDigits = minimumFractionDigits
        self.addressText = address
        self.isUsingTouchId = isUsingTouchId
        super.init(nibName: nil, bundle: nil)
    }

    private let amount: Satoshis
    private let feeAmount: Satoshis
    private let feeType: Fee
    private let state: State
    private let selectedRate: Rate?
    private let minimumFractionDigits: Int?
    private let addressText: String
    private let isUsingTouchId: Bool

    //ContentBoxPresenter
    let contentBox = UIView(color: .white)
    let blurView = UIVisualEffectView()
    let effect = UIBlurEffect(style: .dark)

    var callback: (() -> Void)?

    private let header = ModalHeaderView(title: S.Confirmation.title, style: .dark)
    private let cancel = ShadowButton(title: S.Button.cancel, type: .secondary)
    private let sendButton = ShadowButton(title: S.Confirmation.send, type: .primary, image: #imageLiteral(resourceName: "TouchId"))

    private let payLabel = UILabel(font: .customBody(size: 14.0), color: .grayTextTint)
    private let toLabel = UILabel(font: .customBody(size: 14.0), color: .grayTextTint)
    private let amountLabel = UILabel(font: .customBody(size: 16.0), color: .darkText)
    private let address = UILabel(font: .customBody(size: 16.0), color: .darkText)

    private let processingTime = UILabel.wrapping(font: .customBody(size: 14.0), color: .grayTextTint)
    private let sendLabel = UILabel(font: .customBody(size: 14.0), color: .darkText)
    private let feeLabel = UILabel(font: .customBody(size: 14.0), color: .darkText)
    private let totalLabel = UILabel(font: .customMedium(size: 14.0), color: .darkText)

    private let send = UILabel(font: .customBody(size: 14.0), color: .darkText)
    private let fee = UILabel(font: .customBody(size: 14.0), color: .darkText)
    private let total = UILabel(font: .customMedium(size: 14.0), color: .darkText)

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(contentBox)
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

        let displayAmount = DisplayAmount(amount: amount, state: state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
        let displayFee = DisplayAmount(amount: feeAmount, state: state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
        let displayTotal = DisplayAmount(amount: amount + feeAmount, state: state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)

        amountLabel.text = displayAmount.combinedDescription

        toLabel.text = S.Confirmation.to
        address.text = addressText
        address.lineBreakMode = .byTruncatingMiddle
        switch feeType {
        case .regular:
            processingTime.text = String(format: S.Confirmation.processingTime, "10-30")
        case .economy:
            processingTime.text = String(format: S.Confirmation.processingTime, "60+")
        }

        sendLabel.text = S.Confirmation.amountLabel
        send.text = displayAmount.description
        feeLabel.text = S.Confirmation.feeLabel
        fee.text = displayFee.description

        totalLabel.text = S.Confirmation.totalLabel
        total.text = displayTotal.description

        cancel.tap = strongify(self) { myself in
            myself.dismiss(animated: true, completion: nil)
        }
        header.closeCallback = strongify(self) { myself in
            myself.dismiss(animated: true, completion: nil)
        }
        sendButton.tap = strongify(self) { myself in
            myself.callback?()
        }

        contentBox.layer.cornerRadius = 6.0
        contentBox.layer.masksToBounds = true

        if !isUsingTouchId {
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
