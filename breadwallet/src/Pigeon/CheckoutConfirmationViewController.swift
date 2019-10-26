//
//  CheckoutConfirmationViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-31.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class CheckoutConfirmationViewController: UIViewController {

    private let header = UIView(color: Theme.secondaryBackground)
    private let titleLabel = UILabel(font: .customBold(size: 18.0), color: .white)
    private let footer = UIStackView()
    private let body = UIStackView()
    private let footerBackground = UIView(color: Theme.secondaryBackground)
    private let buy = BRDButton(title: S.Button.buy, type: .primary)
    private let cancel = BRDButton(title: S.Button.cancel, type: .secondary)
    private let logo = UIImageView()
    private let coinName = UILabel(font: .customBody(size: 28.0), color: .white)
    private let amount = UILabel(font: .customBody(size: 16.0), color: .white)

    private let confirmTransitioningDelegate = PinTransitioningDelegate()
    private let request: PigeonRequest
    private let sender: Sender
    private var token: Currency? {
        didSet {
            coinName.text = token?.name ?? S.LinkWallet.logoFooter
            amount.text = String(format: S.PaymentConfirmation.amountText, request.purchaseAmount.description, token?.code ?? "")
            logo.image = token?.imageSquareBackground
        }
    }

    var presentVerifyPin: ((String, @escaping ((String) -> Void)) -> Void)?
    var onPublishSuccess: (() -> Void)?

    init(request: PigeonRequest, sender: Sender) {
        self.request = request
        self.sender = sender
        super.init(nibName: nil, bundle: nil)
        request.getToken { [weak self] token in
            self?.token = token
        }
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
        header.constrain([
            header.topAnchor.constraint(equalTo: safeTopAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 64.0)])
        titleLabel.constrain([
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor)])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            body.topAnchor.constraint(equalTo: header.bottomAnchor),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        logo.constrain([
            logo.heightAnchor.constraint(equalTo: logo.widthAnchor, multiplier: 1.0),
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
        logo.contentMode = .scaleAspectFill
        buy.tap = {
            self.sendTapped()
        }
        cancel.tap = {
            self.request.responseCallback?(CheckoutResult.declined)
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

        let displyAmount = Amount(amount: amount,
                                  rate: nil,
                                  maximumFractionDigits: Amount.highPrecisionDigits)

        let confirm = ConfirmationViewController(amount: displyAmount,
                                                 fee: Amount.zero(currency), //TODO:CRYPTO_V2
                                                 displayFeeLevel: .regular,
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
    
    private func validateTransaction(completion: @escaping (Bool) -> Void) {
        sender.estimateFee(address: request.address,
                           amount: request.purchaseAmount,
                           tier: .priority) { feeBasis in
            
            guard let feeBasis = feeBasis else {
                completion(false)
                return
            }
                            
            let validationResult = self.sender.createTransaction(address: self.request.address,
                                                                 amount: self.request.purchaseAmount,
                                                                 feeBasis: feeBasis,
                                                                 comment: self.request.memo)
            switch validationResult {
            case .ok, .noExchangeRate:
                return completion(true)
            case .insufficientFunds:
                self.showErrorMessageAndDismiss(S.Send.insufficientFunds)
            case .insufficientGas:
                self.showInsufficientGasError()
            default:
                self.showErrorMessageAndDismiss(S.Send.createTransactionError)
            }
            self.request.responseCallback?(CheckoutResult.accepted(result: .creationError(message: "")))
            completion(false)
        }
    }

    private func send() {
        validateTransaction { valid in
            guard valid else { return }
            
            let pinVerifier: PinVerifier = { [weak self] pinValidationCallback in
                self?.presentVerifyPin?(S.VerifyPin.authorize) { pin in
                    self?.parent?.view.isFrameChangeBlocked = false
                    pinValidationCallback(pin)
                }
            }
            
            //TODO:CRYPTO_V2 contract execution
            self.sender.sendTransaction(allowBiometrics: true, pinVerifier: pinVerifier) { [weak self] result in
                guard let `self` = self else { return }
                self.request.responseCallback?(CheckoutResult.accepted(result: result))
                switch result {
                case .success:
                    self.dismiss(animated: true, completion: {
                        Store.trigger(name: .showStatusBar)
                        self.onPublishSuccess?()
                    })
                case .creationError(let message):
                    self.showAlertAndDismiss(title: S.Send.createTransactionError, message: message, buttonLabel: S.Button.ok)
                case .publishFailure(let error):
                    self.showAlertAndDismiss(title: S.Alerts.sendFailure, message: "\(error.message) (\(error.code))", buttonLabel: S.Button.ok)
                case .insufficientGas:
                    self.showInsufficientGasError()
                }
            }
        }
    }

    /// Insufficient gas for ERC20 token transfer
    private func showInsufficientGasError() {
        let fee = Amount.zero(request.currency) //TODO:CRYPTO_V2
        let message = String(format: S.Send.insufficientGasMessage, fee.description)

        let alertController = UIAlertController(title: S.Send.insufficientGasTitle, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.yes, style: .default, handler: { _ in
            self.dismiss(animated: true) {
                Store.trigger(name: .showCurrency(fee.currency))
            }
        }))
        alertController.addAction(UIAlertAction(title: S.Button.no, style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        present(alertController, animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
