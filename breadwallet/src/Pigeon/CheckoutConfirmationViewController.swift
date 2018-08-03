
//
//  CheckoutConfirmationViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-31.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

class CheckoutConfirmationViewController : UIViewController {

    private let header = UIView(color: .darkerBackground)
    private let titleLabel = UILabel(font: .customBold(size: 18.0), color: .white)
    private let footer = UIStackView()
    private let body = UIStackView()
    private let footerBackground = UIView(color: .darkerBackground)
    private let buy = BRDButton(title: S.Button.buy, type: .primary)
    private let cancel = BRDButton(title: S.Button.cancel, type: .secondary)
    private let logo = UIImageView(image: #imageLiteral(resourceName: "CCCLogo"))
    private let coinName = UILabel(font: .customBody(size: 28.0), color: .white)
    private let amount = UILabel(font: .customBody(size: 16.0), color: .white)

    private let confirmTransitioningDelegate = PinTransitioningDelegate()
    private let request: PigeonRequest
    private let sender: Sender

    var presentVerifyPin: ((String, @escaping ((String) -> Void))->Void)?
    var onPublishSuccess: (()->Void)?

    init(request: PigeonRequest, sender: Sender) {
        self.request = request
        self.sender = sender
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(body)
        view.addSubview(footer)
        header.addSubview(titleLabel)
        footer.addSubview(footerBackground)
        body.addArrangedSubview(logo)
        body.addArrangedSubview(coinName)
        body.addArrangedSubview(amount)
        footer.addArrangedSubview(cancel)
        footer.addArrangedSubview(buy)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0.0, topPadding: 0.0)
        header.constrain([
            header.heightAnchor.constraint(equalToConstant: 64.0)])
        titleLabel.constrain([
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor)])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            body.topAnchor.constraint(equalTo: header.bottomAnchor),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        logo.constrain([
            logo.heightAnchor.constraint(equalTo: logo.widthAnchor, multiplier: logo.image!.size.height/logo.image!.size.width),
            logo.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.34)])
        footer.constrain([
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.bottomAnchor.constraint(equalTo: safeBottomAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.heightAnchor.constraint(equalToConstant: 44.0 + C.padding[2])])
        footerBackground.constrain(toSuperviewEdges: nil)
    }

    private func setInitialData() {
        view.backgroundColor = .darkBackground
        setupStackViews()
        titleLabel.text = S.PaymentConfirmation.title
        coinName.text = "Container Crypto Coin"
        amount.text = String(format: S.PaymentConfirmation.amountText, request.purchaseAmount.description, "CCC")
        buy.tap = {
            self.sendTapped()
        }
        cancel.tap = {
            self.dismiss(animated: true, completion: nil)
        }
    }

    private func setupStackViews() {
        body.axis = .vertical
        body.alignment = .center
        body.spacing = C.padding[3]
        body.layoutMargins = UIEdgeInsets(top: C.padding[4], left: C.padding[1], bottom: C.padding[1], right: C.padding[1])
        body.isLayoutMarginsRelativeArrangement = true

        footer.distribution = .fillEqually
        footer.axis = .horizontal
        footer.alignment = .fill
        footer.spacing = C.padding[1]
        footer.layoutMargins = UIEdgeInsets(top: C.padding[1], left: C.padding[1], bottom: C.padding[1], right: C.padding[1])
        footer.isLayoutMarginsRelativeArrangement = true
    }

    private func sendTapped() {
        let amount = request.purchaseAmount
        let address = request.address
        let currency = request.currency

        let fee = sender.fee(forAmount: amount.rawValue) ?? UInt256(0)
        let feeCurrency = (currency is ERC20Token) ? Currencies.eth : currency

        let displyAmount = Amount(amount: amount.rawValue,
                                  currency: currency,
                                  rate: nil,
                                  maximumFractionDigits: Amount.highPrecisionDigits)
        let feeAmount = Amount(amount: fee,
                               currency: feeCurrency,
                               rate: nil,
                               maximumFractionDigits: Amount.highPrecisionDigits)

        let confirm = ConfirmationViewController(amount: displyAmount,
                                                 fee: feeAmount,
                                                 feeType: .regular,
                                                 address: address,
                                                 isUsingBiometrics: sender.canUseBiometrics,
                                                 currency: currency)
        confirm.successCallback = send
        confirm.cancelCallback = sender.reset

        confirmTransitioningDelegate.shouldShowMaskView = false
        confirm.transitioningDelegate = confirmTransitioningDelegate
        confirm.modalPresentationStyle = .overFullScreen
        confirm.modalPresentationCapturesStatusBarAppearance = true
        present(confirm, animated: true, completion: nil)
        return
    }

    private func send() {
        guard case .ok = sender.createTransaction(address: request.address,
                                                  amount: request.purchaseAmount.rawValue,
                                                  comment: request.memo) else {
                                                    return assertionFailure()
        }
        let pinVerifier: PinVerifier = { [weak self] pinValidationCallback in
            self?.presentVerifyPin?(S.VerifyPin.authorize) { pin in
                self?.parent?.view.isFrameChangeBlocked = false
                pinValidationCallback(pin)
            }
        }

        sender.sendTransaction(allowBiometrics: true, pinVerifier: pinVerifier, abi: request.abiData) { [weak self] result in
            guard let `self` = self else { return }
            self.request.responseCallback?(result)
            switch result {
            case .success:
                self.dismiss(animated: true, completion: {
                    Store.trigger(name: .showStatusBar)
                    self.onPublishSuccess?()
                })
            case .creationError(let message):
                self.showAlert(title: S.Send.createTransactionError, message: message, buttonLabel: S.Button.ok)
            case .publishFailure(let error):
                if case .posixError(let code, let description) = error {
                    self.showAlert(title: S.Alerts.sendFailure, message: "\(description) (\(code))", buttonLabel: S.Button.ok)
                }
            case .insufficientGas(_):
                self.showInsufficientGasError()
            }
        }
    }

    /// Insufficient gas for ERC20 token transfer
    private func showInsufficientGasError() {
        guard let fee = sender.fee(forAmount: request.purchaseAmount.rawValue) else { return assertionFailure() }
        let feeAmount = Amount(amount: fee, currency: Currencies.eth, rate: nil)
        let message = String(format: S.Send.insufficientGasMessage, feeAmount.description)

        let alertController = UIAlertController(title: S.Send.insufficientGasTitle, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.yes, style: .default, handler: { _ in
            Store.trigger(name: .showCurrency(Currencies.eth))
        }))
        alertController.addAction(UIAlertAction(title: S.Button.no, style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
