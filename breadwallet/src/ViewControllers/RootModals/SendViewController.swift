//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication
import BRCore

typealias PresentScan = ((@escaping ScanCompletion) -> Void)

private let verticalButtonPadding: CGFloat = 32.0
private let buttonSize = CGSize(width: 52.0, height: 32.0)

class SendViewController : UIViewController, Subscriber, ModalPresentable, Trackable {

    //MARK - Public
    var presentScan: PresentScan?
    var presentVerifyPin: ((String, @escaping ((String) -> Void))->Void)?
    var onPublishSuccess: (()->Void)?
    var parentView: UIView? //ModalPresentable
    var initialAddress: String?
    var isPresentedFromLock = false

    init(sender: Sender, walletManager: WalletManager, initialAddress: String? = nil, initialRequest: PaymentRequest? = nil, currency: CurrencyDef) {
        self.currency = currency
        self.sender = sender
        self.walletManager = walletManager
        self.initialAddress = initialAddress
        self.initialRequest = initialRequest
        self.addressCell = AddressCell(currency: currency)
        amountView = AmountViewController(currency: currency, isPinPadExpandedAtLaunch: false)

        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
    }

    //MARK - Private
    deinit {
        Store.unsubscribe(self)
        NotificationCenter.default.removeObserver(self)
    }

    private let sender: Sender
    private let walletManager: WalletManager
    private let amountView: AmountViewController
    private let addressCell: AddressCell
    private let memoCell = DescriptionSendCell(placeholder: S.Send.descriptionLabel)
    private let sendButton = ShadowButton(title: S.Send.sendLabel, type: .primary)
    private let currencyBorder = UIView(color: .secondaryShadow)
    private var currencySwitcherHeightConstraint: NSLayoutConstraint?
    private var pinPadHeightConstraint: NSLayoutConstraint?
    private var balance: UInt256 = 0
    private var amount: Amount?
    private var didIgnoreUsedAddressWarning = false
    private var didIgnoreIdentityNotCertified = false
    private let initialRequest: PaymentRequest?
    private let confirmTransitioningDelegate = PinTransitioningDelegate()
    private var feeType: Fee?
    private let currency: CurrencyDef

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(addressCell)
        view.addSubview(memoCell)
        view.addSubview(sendButton)

        addressCell.constrainTopCorners(height: SendCell.defaultHeight)

        addChildViewController(amountView, layout: {
            amountView.view.constrain([
                amountView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                amountView.view.topAnchor.constraint(equalTo: addressCell.bottomAnchor),
                amountView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
        })

        memoCell.constrain([
            memoCell.widthAnchor.constraint(equalTo: amountView.view.widthAnchor),
            memoCell.topAnchor.constraint(equalTo: amountView.view.bottomAnchor),
            memoCell.leadingAnchor.constraint(equalTo: amountView.view.leadingAnchor),
            memoCell.heightAnchor.constraint(equalTo: memoCell.textView.heightAnchor, constant: C.padding[4]) ])

        memoCell.accessoryView.constrain([
                memoCell.accessoryView.constraint(.width, constant: 0.0) ])

        sendButton.constrain([
            sendButton.constraint(.leading, toView: view, constant: C.padding[2]),
            sendButton.constraint(.trailing, toView: view, constant: -C.padding[2]),
            sendButton.constraint(toBottom: memoCell, constant: verticalButtonPadding),
            sendButton.constraint(.height, constant: C.Sizes.buttonHeight),
            sendButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: E.isIPhoneX ? -C.padding[5] : -C.padding[2]) ])
        addButtonActions()
        Store.subscribe(self, selector: { $0[self.currency].balance != $1[self.currency].balance },
                        callback: { [unowned self] in
                            if let balance = $0[self.currency].balance {
                                self.balance = balance
                            }
        })
        Store.subscribe(self, selector: { $0[self.currency].fees != $1[self.currency].fees }, callback: { [unowned self] in
            if let fees = $0[self.currency].fees {
                self.amountView.canEditFee = (fees.regular != fees.economy) || self.currency.matches(Currencies.btc)
                if let feeType = self.feeType {
                    switch feeType {
                    case .regular :
                        self.walletManager.wallet?.feePerKb = fees.regular
                    case .economy:
                        self.walletManager.wallet?.feePerKb = fees.economy
                    }
                } else {
                    self.walletManager.wallet?.feePerKb = fees.regular
                }
            }
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if initialAddress != nil {
            addressCell.setContent(initialAddress)
            amountView.expandPinPad()
        } else if let initialRequest = initialRequest {
            handleRequest(initialRequest)
        }
    }

    private func addButtonActions() {
        addressCell.paste.addTarget(self, action: #selector(SendViewController.pasteTapped), for: .touchUpInside)
        addressCell.scan.addTarget(self, action: #selector(SendViewController.scanTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        memoCell.didReturn = { textView in
            textView.resignFirstResponder()
        }
        memoCell.didBeginEditing = { [weak self] in
            self?.amountView.closePinPad()
        }
        addressCell.didBeginEditing = strongify(self) { myself in
            myself.amountView.closePinPad()
        }
        addressCell.didReceivePaymentRequest = { [weak self] request in
            self?.handleRequest(request)
        }
        amountView.balanceTextForAmount = { [weak self] amount, rate in
            return self?.balanceTextForAmount(amount, rate: rate)
        }
        amountView.didUpdateAmount = { [weak self] amount in
            self?.amount = amount
        }
        amountView.didUpdateFee = strongify(self) { myself, fee in
            guard let wallet = myself.walletManager.wallet else { return }
            myself.feeType = fee
            if let fees = self.currency.state.fees {
                switch fee {
                case .regular:
                    wallet.feePerKb = fees.regular
                case .economy:
                    wallet.feePerKb = fees.economy
                }
            }
            myself.amountView.updateBalanceLabel()
        }

        amountView.didChangeFirstResponder = { [weak self] isFirstResponder in
            if isFirstResponder {
                self?.memoCell.textView.resignFirstResponder()
                self?.addressCell.textField.resignFirstResponder()
            }
        }
    }
    
    private func balanceTextForAmount(_ amount: Amount?, rate: Rate?) -> (NSAttributedString?, NSAttributedString?) {
        let balanceAmount = Amount(amount: balance, currency: currency, rate: rate, minimumFractionDigits: 0)
        let balanceText = balanceAmount.description
        let balanceOutput = String(format: S.Send.balance, balanceText)
        var feeOutput = ""
        var color: UIColor = .grayTextTint
        var feeColor: UIColor = .grayTextTint
        
        if let amount = amount, amount.rawValue > UInt256(0) {
            if let fee = sender.feeForTx(amount: amount.rawValue) {
                let feeAmount = Amount(amount: fee, currency: currency, rate: rate)
                let feeText = feeAmount.description
                feeOutput = String(format: S.Send.fee, feeText)
                if (balance >= fee) && amount.rawValue > (balance - fee) {
                    color = .cameraGuideNegative
                }
            } else {
                feeOutput = S.Send.nilFeeError
                feeColor = .cameraGuideNegative
            }
        }

        let attributes: [NSAttributedStringKey: Any] = [
            NSAttributedStringKey.font: UIFont.customBody(size: 14.0),
            NSAttributedStringKey.foregroundColor: color
        ]

        let feeAttributes: [NSAttributedStringKey: Any] = [
            NSAttributedStringKey.font: UIFont.customBody(size: 14.0),
            NSAttributedStringKey.foregroundColor: feeColor
        ]

        return (NSAttributedString(string: balanceOutput, attributes: attributes), NSAttributedString(string: feeOutput, attributes: feeAttributes))
    }

    @objc private func pasteTapped() {
        guard let pasteboard = UIPasteboard.general.string, pasteboard.utf8.count > 0 else {
            return showAlert(title: S.Alert.error, message: S.Send.emptyPasteboard, buttonLabel: S.Button.ok)
        }

        guard let request = PaymentRequest(string: pasteboard, currency: currency) else {
            let message = String.init(format: S.Send.invalidAddressOnPasteboard, currency.name)
            return showAlert(title: S.Send.invalidAddressTitle, message: message, buttonLabel: S.Button.ok)
        }
        handleRequest(request)
    }

    @objc private func scanTapped() {
        memoCell.textView.resignFirstResponder()
        addressCell.textField.resignFirstResponder()
        presentScan? { [weak self] paymentRequest in
            guard let request = paymentRequest else { return }
            self?.handleRequest(request)
        }
    }

    @objc private func sendTapped() {
        if addressCell.textField.isFirstResponder {
            addressCell.textField.resignFirstResponder()
        }

        if sender.transaction == nil {
            guard let address = addressCell.address else {
                return showAlert(title: S.Alert.error, message: S.Send.noAddress, buttonLabel: S.Button.ok)
            }
            if currency.matches(Currencies.btc) {
                guard currency.state.fees != nil else {
                    return showAlert(title: S.Alert.error, message: S.Send.noFeesError, buttonLabel: S.Button.ok)
                }
            }
            guard currency.isValidAddress(address) else {
                let message = String.init(format: S.Send.invalidAddressMessage, currency.name)
                return showAlert(title: S.Send.invalidAddressTitle, message: message, buttonLabel: S.Button.ok)
            }
            guard let amount = amount else {
                return showAlert(title: S.Alert.error, message: S.Send.noAmount, buttonLabel: S.Button.ok)
            }
            if let minOutput = walletManager.wallet?.minOutputAmount {
                guard amount.rawValue >= minOutput else {
                    let minOutputAmount = Amount(amount: UInt256(minOutput), currency: currency, rate: Rate.empty)
                    let text = Store.state.isBtcSwapped ? minOutputAmount.fiatDescription : minOutputAmount.tokenDescription
                    let message = String(format: S.PaymentProtocol.Errors.smallPayment, text)
                    return showAlert(title: S.Alert.error, message: message, buttonLabel: S.Button.ok)
                }
            }
            guard !(walletManager.wallet?.containsAddress(address) ?? false) else {
                return showAlert(title: S.Alert.error, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
            }
            if currency.matches(Currencies.btc) || currency.matches(Currencies.bch) {
                guard amount.rawValue <= (walletManager.wallet?.maxOutputAmount ?? 0) else {
                    return showAlert(title: S.Alert.error, message: S.Send.insufficientFunds, buttonLabel: S.Button.ok)
                }
            }
            guard sender.createTransaction(amount: amount.rawValue, to: address) else {
                return showAlert(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
            }
        }

        guard let amount = amount else { return }
        //TODO:ETH
        let confirm = ConfirmationViewController(amount: amount.rawValue,
                                                 fee: sender.fee,
                                                 feeType: feeType ?? .regular,
                                                 selectedRate: amountView.selectedRate,
                                                 minimumFractionDigits: amountView.minimumFractionDigits,
                                                 address: addressCell.displayAddress ?? "",
                                                 isUsingBiometrics: sender.canUseBiometrics,
                                                 currency: currency)
        confirm.successCallback = {
            confirm.dismiss(animated: true, completion: {
                self.send()
            })
        }
        confirm.cancelCallback = {
            confirm.dismiss(animated: true, completion: {
                self.sender.transaction = nil
            })
        }
        confirmTransitioningDelegate.shouldShowMaskView = false
        confirm.transitioningDelegate = confirmTransitioningDelegate
        confirm.modalPresentationStyle = .overFullScreen
        confirm.modalPresentationCapturesStatusBarAppearance = true
        present(confirm, animated: true, completion: nil)
        return
    }

    private func handleRequest(_ request: PaymentRequest) {
        guard request.warningMessage == nil else { return handleRequestWithWarning(request) }
        switch request.type {
        case .local:
            addressCell.setContent(request.displayAddress)
            addressCell.isEditable = true
            if let amount = request.amount {
                amountView.forceUpdateAmount(amount: amount)
            }
            if request.label != nil {
                memoCell.content = request.label
            }
        case .remote:
            let loadingView = BRActivityViewController(message: S.Send.loadingRequest)
            present(loadingView, animated: true, completion: nil)
            request.fetchRemoteRequest(completion: { [weak self] request in
                DispatchQueue.main.async {
                    loadingView.dismiss(animated: true, completion: {
                        if let paymentProtocolRequest = request?.paymentProtocolRequest {
                            self?.confirmProtocolRequest(protoReq: paymentProtocolRequest)
                        } else {
                            self?.showErrorMessage(S.Send.remoteRequestError)
                        }
                    })
                }
            })
        }
    }

    private func handleRequestWithWarning(_ request: PaymentRequest) {
        guard let message = request.warningMessage else { return }
        let alert = UIAlertController(title: S.Alert.warning, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: S.Button.continueAction, style: .default, handler: { [weak self] _ in
            var requestCopy = request
            requestCopy.warningMessage = nil
            self?.handleRequest(requestCopy)
        }))
        present(alert, animated: true, completion: nil)
    }

    private func send() {
        guard let rate = currency.state.currentRate else { return }

        sender.send(biometricsMessage: S.VerifyPin.touchIdMessage,
                    rate: rate,
                    comment: memoCell.textView.text,
                    feePerKb: walletManager.wallet?.feePerKb ?? 0,
                    verifyPinFunction: { [weak self] pinValidationCallback in
                        self?.presentVerifyPin?(S.VerifyPin.authorize) { [weak self] pin in
                            self?.parent?.view.isFrameChangeBlocked = false
                            pinValidationCallback(pin)
                        }
            }, completion: { [weak self] result in
                guard let `self` = self else { return }
                switch result {
                case .success:
                    self.dismiss(animated: true, completion: {
                        Store.trigger(name: .showStatusBar)
                        if self.isPresentedFromLock {
                            Store.trigger(name: .loginFromSend)
                        }
                        self.onPublishSuccess?()
                    })
                    self.saveEvent("send.success")
                case .creationError(let message):
                    self.showAlert(title: S.Send.createTransactionError, message: message, buttonLabel: S.Button.ok)
                    self.saveEvent("send.publishFailed", attributes: ["errorMessage": message])
                case .publishFailure(let error):
                    if case .posixError(let code, let description) = error {
                        self.showAlert(title: S.Alerts.sendFailure, message: "\(description) (\(code))", buttonLabel: S.Button.ok)
                        self.saveEvent("send.publishFailed", attributes: ["errorMessage": "\(description) (\(code))"])
                    }
                }
        })
    }

    func confirmProtocolRequest(protoReq: PaymentProtocolRequest) {
        guard let firstOutput = protoReq.details.outputs.first else { return }
        guard let wallet = walletManager.wallet else { return }

        let address = firstOutput.swiftAddress
        let isValid = protoReq.isValid()
        var isOutputTooSmall = false

        if let errorMessage = protoReq.errorMessage, errorMessage == S.PaymentProtocol.Errors.requestExpired, !isValid {
            return showAlert(title: S.PaymentProtocol.Errors.badPaymentRequest, message: errorMessage, buttonLabel: S.Button.ok)
        }

        //TODO: check for duplicates of already paid requests
        var requestAmount = UInt256(0)
        protoReq.details.outputs.forEach { output in
            if output.amount > 0 && output.amount < wallet.minOutputAmount {
                isOutputTooSmall = true
            }
            requestAmount += UInt256(output.amount)
        }

        if wallet.containsAddress(address) {
            return showAlert(title: S.Alert.warning, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
        } else if wallet.addressIsUsed(address) && !didIgnoreUsedAddressWarning {
            let message = "\(S.Send.UsedAddress.title)\n\n\(S.Send.UsedAddress.firstLine)\n\n\(S.Send.UsedAddress.secondLine)"
            return showError(title: S.Alert.warning, message: message, ignore: { [weak self] in
                self?.didIgnoreUsedAddressWarning = true
                self?.confirmProtocolRequest(protoReq: protoReq)
            })
        } else if let message = protoReq.errorMessage, message.utf8.count > 0 && (protoReq.commonName?.utf8.count)! > 0 && !didIgnoreIdentityNotCertified {
            return showError(title: S.Send.identityNotCertified, message: message, ignore: { [weak self] in
                self?.didIgnoreIdentityNotCertified = true
                self?.confirmProtocolRequest(protoReq: protoReq)
            })
        } else if requestAmount < wallet.minOutputAmount {
            let amount = Amount(amount: UInt256(wallet.minOutputAmount), currency: currency, rate: Rate.empty)
            let message = String(format: S.PaymentProtocol.Errors.smallPayment, amount.tokenDescription)
            return showAlert(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
        } else if isOutputTooSmall {
            let amount = Amount(amount: UInt256(wallet.minOutputAmount), currency: currency, rate: Rate.empty)
            let message = String(format: S.PaymentProtocol.Errors.smallTransaction, amount.tokenDescription)
            return showAlert(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
        }

        if let name = protoReq.commonName {
            addressCell.setContent(protoReq.pkiType != "none" ? "\(S.Symbols.lock) \(name.sanitized)" : name.sanitized)
        }

        if requestAmount > UInt256(0) {
            amountView.forceUpdateAmount(amount: Amount(amount: requestAmount, currency: currency))
        }
        memoCell.content = protoReq.details.memo

        if requestAmount == 0 {
            if let amount = amount {
                //TODO:ETH
                guard sender.createTransaction(amount: amount.rawValue, to: address) else {
                    return showAlert(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
                }
            }
        } else {
            addressCell.isEditable = false
            sender.createTransaction(forPaymentProtocol: protoReq)
        }
    }

    private func showError(title: String, message: String, ignore: @escaping () -> Void) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.ignore, style: .default, handler: { _ in
            ignore()
        }))
        alertController.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    //MARK: - Keyboard Notifications
    @objc private func keyboardWillShow(notification: Notification) {
        copyKeyboardChangeAnimation(notification: notification)
    }

    @objc private func keyboardWillHide(notification: Notification) {
        copyKeyboardChangeAnimation(notification: notification)
    }

    //TODO - maybe put this in ModalPresentable?
    private func copyKeyboardChangeAnimation(notification: Notification) {
        guard let info = KeyboardNotificationInfo(notification.userInfo) else { return }
        UIView.animate(withDuration: info.animationDuration, delay: 0, options: info.animationOptions, animations: {
            guard let parentView = self.parentView else { return }
            parentView.frame = parentView.frame.offsetBy(dx: 0, dy: info.deltaY)
        }, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SendViewController : ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.sendBitcoin
    }
    
    var faqCurrency: CurrencyDef? {
        return currency
    }

    var modalTitle: String {
        return "\(S.Send.title) \(currency.code)"
    }
}
