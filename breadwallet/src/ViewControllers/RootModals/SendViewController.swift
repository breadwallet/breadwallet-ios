//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import LocalAuthentication
import BRCrypto

typealias PresentScan = ((@escaping ScanCompletion) -> Void)

private let verticalButtonPadding: CGFloat = 32.0
private let buttonSize = CGSize(width: 52.0, height: 32.0)

// swiftlint:disable type_body_length
class SendViewController: UIViewController, Subscriber, ModalPresentable, Trackable {

    // MARK: - Public
    
    var presentScan: PresentScan?
    var presentVerifyPin: ((String, @escaping ((String) -> Void)) -> Void)?
    var onPublishSuccess: (() -> Void)?
    var parentView: UIView? //ModalPresentable
    
    var isPresentedFromLock = false

    init(sender: Sender, initialRequest: PaymentRequest? = nil) {
        let currency = sender.wallet.currency
        self.currency = currency
        self.sender = sender
        self.initialRequest = initialRequest
        self.balance = currency.state?.balance ?? Amount.zero(currency)
        addressCell = AddressCell(currency: currency)
        amountView = AmountViewController(currency: currency, isPinPadExpandedAtLaunch: false)

        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Private
    
    deinit {
        Store.unsubscribe(self)
        NotificationCenter.default.removeObserver(self)
    }

    private let amountView: AmountViewController
    private let addressCell: AddressCell
    private let memoCell = DescriptionSendCell(placeholder: S.Send.descriptionLabel)
    private let sendButton = BRDButton(title: S.Send.sendLabel, type: .primary)
    private let currencyBorder = UIView(color: .secondaryShadow)
    private var currencySwitcherHeightConstraint: NSLayoutConstraint?
    private var pinPadHeightConstraint: NSLayoutConstraint?
    private let confirmTransitioningDelegate = PinTransitioningDelegate()
    private let sendingActivity = BRActivityViewController(message: S.TransactionDetails.titleSending)
    
    private let sender: Sender
    private let currency: Currency
    private let initialRequest: PaymentRequest?
    private var validatedProtoRequest: PaymentProtocolRequest?
    private var didIgnoreUsedAddressWarning = false
    private var didIgnoreIdentityNotCertified = false
    private var feeSelection: FeeLevel? = .regular {
        didSet {
            updateFees()
        }
    }
    private var balance: Amount
    private var amount: Amount? {
        didSet {
            updateFees()
        }
    }
    private var address: String? {
        if let protoRequest = validatedProtoRequest {
            return protoRequest.address
        } else {
            return addressCell.address
        }
    }
    
    private var currentFeeBasis: TransferFeeBasis?

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        Store.subscribe(self, selector: { $0[self.currency]?.balance != $1[self.currency]?.balance },
                        callback: { [unowned self] in
                            if let balance = $0[self.currency]?.balance {
                                self.balance = balance
                            }
        })
        
        addAddressChangeListener()
        sender.updateNetworkFees()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let initialRequest = initialRequest {
            handleRequest(initialRequest)
        }
    }
    
    private func addAddressChangeListener() {
        addressCell.textDidChange = { [weak self] text in
            guard let `self` = self else { return }
            guard let text = text else { return }
            guard self.currency.isValidAddress(text) else { return }
            self.updateFees()
        }
    }

    // MARK: - Actions
    
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
        amountView.didUpdateFee = strongify(self) { myself, feeLevel in
            guard myself.currency.isBitcoinCompatible else { return }
            myself.feeSelection = feeLevel
        }
        
        amountView.didChangeFirstResponder = { [weak self] isFirstResponder in
            if isFirstResponder {
                self?.memoCell.textView.resignFirstResponder()
                self?.addressCell.textField.resignFirstResponder()
            }
        }
    }
    
    private func updateFees() {
        guard let address = address else { return }
        guard let amount = amount else { return }
        guard let fee = feeSelection else { return }
        sender.estimateFee(address: address, amount: amount, tier: fee, completion: { basis in
            DispatchQueue.main.async {
                self.currentFeeBasis = basis
                self.amountView.updateBalanceLabel()
            }
        })
    }
    
    private func balanceTextForAmount(_ amount: Amount?, rate: Rate?) -> (NSAttributedString?, NSAttributedString?) {
        let balanceAmount = Amount(amount: balance, rate: rate, minimumFractionDigits: 0)
        let balanceText = balanceAmount.description
        let balanceOutput = String(format: S.Send.balance, balanceText)
        var feeOutput = ""
        var color: UIColor = .grayTextTint
        let feeColor: UIColor = .grayTextTint

        if let amount = amount, !amount.isZero, let feeBasis = currentFeeBasis {
            var feeAmount = Amount(cryptoAmount: feeBasis.fee, currency: sender.wallet.feeCurrency)
            feeAmount.rate = rate
            let feeText = feeAmount.description
            feeOutput = String(format: S.Send.fee, feeText)

            if feeAmount.currency == currency && (balance >= feeAmount) && amount > (balance - feeAmount) {
                color = .cameraGuideNegative
            }
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UIFont.customBody(size: 14.0),
            NSAttributedString.Key.foregroundColor: color
        ]
        
        let feeAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: UIFont.customBody(size: 14.0),
            NSAttributedString.Key.foregroundColor: feeColor
        ]
        
        return (NSAttributedString(string: balanceOutput, attributes: attributes), NSAttributedString(string: feeOutput, attributes: feeAttributes))
    }
    
    @objc private func pasteTapped() {
        guard let pasteboard = UIPasteboard.general.string, !pasteboard.utf8.isEmpty else {
            return showAlert(title: S.Alert.error, message: S.Send.emptyPasteboard, buttonLabel: S.Button.ok)
        }

        guard let request = PaymentRequest(string: pasteboard, currency: currency) else {
            let message = String.init(format: S.Send.invalidAddressOnPasteboard, currency.name)
            return showAlert(title: S.Send.invalidAddressTitle, message: message, buttonLabel: S.Button.ok)
        }
        self.validatedProtoRequest = nil
        handleRequest(request)
    }

    @objc private func scanTapped() {
        memoCell.textView.resignFirstResponder()
        addressCell.textField.resignFirstResponder()
        presentScan? { [weak self] scanResult in
            self?.validatedProtoRequest = nil
            guard case .paymentRequest(let request)? = scanResult else { return }
            self?.handleRequest(request)
        }
    }
    
    private func validateSendForm() -> Bool {
        guard let address = address, !address.isEmpty else {
            showAlert(title: S.Alert.error, message: S.Send.noAddress, buttonLabel: S.Button.ok)
            return false
        }
        
        guard let amount = amount, !amount.isZero else {
            showAlert(title: S.Alert.error, message: S.Send.noAmount, buttonLabel: S.Button.ok)
            return false
        }
        
        guard let feeBasis = currentFeeBasis else {
            showAlert(title: S.Alert.error, message: "No fee estimate", buttonLabel: S.Button.ok)
            return false
        }

        let validationResult = sender.createTransaction(address: address,
                                                        amount: amount,
                                                        feeBasis: feeBasis,
                                                        comment: memoCell.textView.text)
        switch validationResult {
        case .noFees:
            showAlert(title: S.Alert.error, message: S.Send.noFeesError, buttonLabel: S.Button.ok)
            
        case .invalidAddress:
            let message = String.init(format: S.Send.invalidAddressMessage, currency.name)
            showAlert(title: S.Send.invalidAddressTitle, message: message, buttonLabel: S.Button.ok)
            
        case .ownAddress:
            showAlert(title: S.Alert.error, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
            
        case .outputTooSmall(let minOutput):
            let text = Store.state.showFiatAmounts ? minOutput.fiatDescription : minOutput.tokenDescription
            let message = String(format: S.PaymentProtocol.Errors.smallPayment, text)
            showAlert(title: S.Alert.error, message: message, buttonLabel: S.Button.ok)
            
        case .insufficientFunds:
            showAlert(title: S.Alert.error, message: S.Send.insufficientFunds, buttonLabel: S.Button.ok)
            
        case .failed:
            showAlert(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
            
        case .insufficientGas:
            showInsufficientGasError()
            
        // allow sending without exchange rates available (the tx metadata will not be set)
        case .ok, .noExchangeRate:
            return true
            
        default:
            break
        }
        
        return false
    }

    @objc private func sendTapped() {
        if addressCell.textField.isFirstResponder {
            addressCell.textField.resignFirstResponder()
        }
        
        guard validateSendForm(),
            let amount = amount,
            let address = address,
            let feeBasis = currentFeeBasis else { return }

        let feeCurrency = sender.wallet.feeCurrency
        let fee = Amount(cryptoAmount: feeBasis.fee, currency: feeCurrency)
        
        let displyAmount = Amount(amount: amount,
                                  rate: amountView.selectedRate,
                                  maximumFractionDigits: Amount.highPrecisionDigits)
        let feeAmount = Amount(amount: fee,
                               rate: (amountView.selectedRate != nil) ? feeCurrency.state?.currentRate : nil,
                               maximumFractionDigits: Amount.highPrecisionDigits)

        let confirm = ConfirmationViewController(amount: displyAmount,
                                                 fee: feeAmount,
                                                 displayFeeLevel: feeSelection ?? .regular,
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
                            self?.confirmProtocolRequest(paymentProtocolRequest)
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
                        if self.isPresentedFromLock {
                            Store.trigger(name: .loginFromSend)
                        }
                        self.onPublishSuccess?()
                    }
                    self.saveEvent("send.success")
                case .creationError(let message):
                    self.showAlert(title: S.Alerts.sendFailure, message: message, buttonLabel: S.Button.ok)
                    self.saveEvent("send.publishFailed", attributes: ["errorMessage": message])
                case .publishFailure(let error):
                    self.showAlert(title: S.Alerts.sendFailure, message: "\(error.message) (\(error.code))", buttonLabel: S.Button.ok)
                    self.saveEvent("send.publishFailed", attributes: ["errorMessage": "\(error.message) (\(error.code))"])
                case .insufficientGas(let rpcErrorMessage):
                    self.showInsufficientGasError()
                    self.saveEvent("send.publishFailed", attributes: ["errorMessage": rpcErrorMessage])
                }
            }
        }
    }

    func confirmProtocolRequest(_ protoReq: PaymentProtocolRequest) {
        let result = sender.validate(paymentRequest: protoReq, ignoreUsedAddress: didIgnoreUsedAddressWarning, ignoreIdentityNotCertified: didIgnoreIdentityNotCertified)
        
        switch result {
        case .invalidRequest(let errorMessage):
            return showAlert(title: S.PaymentProtocol.Errors.badPaymentRequest, message: errorMessage, buttonLabel: S.Button.ok)
            
        case .ownAddress:
            return showAlert(title: S.Alert.warning, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
            
        case .usedAddress:
            let message = "\(S.Send.UsedAddress.title)\n\n\(S.Send.UsedAddress.firstLine)\n\n\(S.Send.UsedAddress.secondLine)"
            return showError(title: S.Alert.warning, message: message, ignore: { [unowned self] in
                self.didIgnoreUsedAddressWarning = true
                self.confirmProtocolRequest(protoReq)
            })
            
        case .identityNotCertified(let errorMessage):
            return showError(title: S.Send.identityNotCertified, message: errorMessage, ignore: { [unowned self] in
                self.didIgnoreIdentityNotCertified = true
                self.confirmProtocolRequest(protoReq)
            })
            
        case .paymentTooSmall(let minOutput):
            let message = String(format: S.PaymentProtocol.Errors.smallPayment, minOutput.tokenDescription)
            return showAlert(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
            
        case .outputTooSmall(let minOutput):
            let message = String(format: S.PaymentProtocol.Errors.smallTransaction, minOutput.tokenDescription)
            return showAlert(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)

        case .insufficientFunds:
            return showAlert(title: S.Alert.error, message: S.Send.insufficientFunds, buttonLabel: S.Button.ok)
            
        case .ok:
            self.validatedProtoRequest = protoReq
            
        default:
            assertionFailure("unhandled error")
            print("[SEND] payment request validation error: \(result)")
            return
        }

        //TODO:CRYPTO protocol request
        let address = protoReq.address
        let requestAmount = Amount(tokenString: protoReq.amount.description, currency: currency, unit: currency.baseUnit)
        
        if let name = protoReq.commonName {
            addressCell.setContent(protoReq.pkiType != "none" ? "\(S.Symbols.lock) \(name.sanitized)" : name.sanitized)
        } else {
            addressCell.setContent(address)
        }

        memoCell.content = protoReq.details.memo
        
        //TODO:CRYPTO protocol request
//        if requestAmount.isZero {
//            if let amount = amount {
//                guard case .ok = sender.createTransaction(address: address, amount: amount, comment: nil) else {
//                    return showAlert(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
//                }
//            }
//        } else {
//            amountView.forceUpdateAmount(amount: requestAmount)
//            addressCell.isEditable = false
//            guard case .ok = sender.createTransaction(forPaymentProtocol: protoReq) else {
//                return showAlert(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
//            }
//        }
    }

    private func showError(title: String, message: String, ignore: @escaping () -> Void) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.ignore, style: .default, handler: { _ in
            ignore()
        }))
        alertController.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    /// Insufficient gas for ERC20 token transfer
    private func showInsufficientGasError() {
        guard let feeAmount = self.currentFeeBasis?.fee else { return assertionFailure() }
        
        let message = String(format: S.Send.insufficientGasMessage, feeAmount.description)

        let alertController = UIAlertController(title: S.Send.insufficientGasTitle, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.yes, style: .default, handler: { _ in
            Store.trigger(name: .showCurrency(self.sender.wallet.feeCurrency))
        }))
        alertController.addAction(UIAlertAction(title: S.Button.no, style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Keyboard Notifications

extension SendViewController {
    
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
}

// MARK: - ModalDisplayable

extension SendViewController: ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.sendTx
    }
    
    var faqCurrency: Currency? {
        return currency
    }

    var modalTitle: String {
        return "\(S.Send.title) \(currency.code)"
    }
}
