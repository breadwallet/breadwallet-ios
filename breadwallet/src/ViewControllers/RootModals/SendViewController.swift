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
    private var paymentProtocolRequest: PaymentProtocolRequest?
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
        if let protoRequest = paymentProtocolRequest {
            return protoRequest.primaryTarget?.description
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
        Store.subscribe(self,
                        selector: { [weak self] oldState, newState in
                            guard let `self` = self else { return false }
                            return oldState[self.currency]?.balance != newState[self.currency]?.balance },
                        callback: { [weak self] in
                            guard let `self` = self else { return }
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
        guard paymentProtocolRequest == nil else {
            self.estimateFeeForRequest(paymentProtocolRequest!) {
                guard case .success(let feeBasis) = $0 else { return }
                self.handleFeeEstimationResult(feeBasis)
            }
            return
        }
        guard let address = address else { return }
        guard let amount = amount else { return }
        guard let fee = feeSelection else { return }
        sender.estimateFee(address: address, amount: amount, tier: fee) { self.handleFeeEstimationResult($0) }
    }
    
    private func handleFeeEstimationResult(_ basis: TransferFeeBasis?) {
        DispatchQueue.main.async {
            self.currentFeeBasis = basis
            self.amountView.updateBalanceLabel()
        }
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
        self.paymentProtocolRequest = nil
        handleRequest(request)
    }

    @objc private func scanTapped() {
        memoCell.textView.resignFirstResponder()
        addressCell.textField.resignFirstResponder()
        presentScan? { [weak self] scanResult in
            self?.paymentProtocolRequest = nil
            guard case .paymentRequest(let request)? = scanResult else { return }
            self?.handleRequest(request)
        }
    }
    
    private func validateSendForm() -> Bool {
        //Payment Protocol Requests do their own validation
        guard paymentProtocolRequest == nil else { return true }
        
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

        return handleValidationResult(sender.createTransaction(address: address,
                                                        amount: amount,
                                                        feeBasis: feeBasis,
                                                        comment: memoCell.textView.text))
    }
    
    private func handleValidationResult(_ result: SenderValidationResult, protocolRequest: PaymentProtocolRequest? = nil) -> Bool {
        switch result {
        case .noFees:
            showAlert(title: S.Alert.error, message: S.Send.noFeesError, buttonLabel: S.Button.ok)
            
        case .invalidAddress:
            let message = String.init(format: S.Send.invalidAddressMessage, currency.name)
            showAlert(title: S.Send.invalidAddressTitle, message: message, buttonLabel: S.Button.ok)
            
        case .ownAddress:
            showAlert(title: S.Alert.error, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
            
        case .outputTooSmall(let minOutput), .paymentTooSmall(let minOutput):
            let text = Store.state.showFiatAmounts ? minOutput.fiatDescription : minOutput.tokenDescription
            let message = String(format: S.PaymentProtocol.Errors.smallPayment, text)
            showAlert(title: S.Alert.error, message: message, buttonLabel: S.Button.ok)
            
        case .insufficientFunds:
            showAlert(title: S.Alert.error, message: S.Send.insufficientFunds, buttonLabel: S.Button.ok)
            
        case .failed:
            showAlert(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
            
        case .insufficientGas:
            showInsufficientGasError()
            
        case .identityNotCertified(let message):
            showError(title: S.Send.identityNotCertified, message: message, ignore: { [unowned self] in
                self.didIgnoreIdentityNotCertified = true
                if let protoReq = protocolRequest {
                    self.didReceivePaymentProtocolRequest(protoReq)
                }
            })
            return false
        case .invalidRequest(let errorMessage):
            showAlert(title: S.PaymentProtocol.Errors.badPaymentRequest, message: errorMessage, buttonLabel: S.Button.ok)
            return false
        case .usedAddress:
            showError(title: S.Send.UsedAddress.title, message: "\(S.Send.UsedAddress.firstLine)\n\n\(S.Send.UsedAddress.secondLine)", ignore: { [unowned self] in
                self.didIgnoreUsedAddressWarning = true
            })
            return false
            
        // allow sending without exchange rates available (the tx metadata will not be set)
        case .ok, .noExchangeRate:
            return true
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
    
    // MARK: - Payment Protocol Requests

    private func handleRequest(_ request: PaymentRequest) {
        switch request.type {
        case .local:
            addressCell.setContent(request.toAddress?.description)
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
                            self?.didReceivePaymentProtocolRequest(paymentProtocolRequest)
                        } else {
                            self?.showErrorMessage(S.Send.remoteRequestError)
                        }
                    })
                }
            })
        }
    }
    
    private func didReceivePaymentProtocolRequest(_ paymentProtocolRequest: PaymentProtocolRequest) {
        self.paymentProtocolRequest = paymentProtocolRequest
        estimateFeeForRequest(paymentProtocolRequest) { self.handleProtoReqFeeEstimation(paymentProtocolRequest, result: $0) }
    }
    
    func estimateFeeForRequest(_ protoReq: PaymentProtocolRequest, completion: @escaping (Result<TransferFeeBasis, BRCrypto.Wallet.FeeEstimationError>) -> Void) {
        let networkFee = protoReq.requiredNetworkFee ?? sender.wallet.feeForLevel(level: feeSelection ?? .regular)
        protoReq.estimateFee(fee: networkFee, completion: completion)
    }
    
    private func handleProtoReqFeeEstimation(_ protoReq: PaymentProtocolRequest, result: Result<TransferFeeBasis, BRCrypto.Wallet.FeeEstimationError>) {
        switch result {
        case .success(let transferFeeBasis):
            DispatchQueue.main.async {
                //We need to keep track of the fee basis here so that we can display the fee amount
                //in the tx confirmation view
                self.currentFeeBasis = transferFeeBasis
                self.validateReq(protoReq: protoReq, feeBasis: transferFeeBasis)
            }
        case .failure(let error):
            self.showErrorMessage("Error estimating fee: \(error)")
        }
    }
    
    private func validateReq(protoReq: PaymentProtocolRequest, feeBasis: TransferFeeBasis) {
        guard let totalAmount = protoReq.totalAmount else { handleZeroAmountPaymentProtocolRequest(protoReq); return }
        let requestAmount = Amount(cryptoAmount: totalAmount, currency: currency, maximumFractionDigits: 8)
        guard !requestAmount.isZero else { handleZeroAmountPaymentProtocolRequest(protoReq); return }
        let result = sender.createTransaction(protocolRequest: protoReq,
                                            ignoreUsedAddress: didIgnoreUsedAddressWarning,
                                            ignoreIdentityNotCertified: didIgnoreIdentityNotCertified,
                                            feeBasis: feeBasis,
                                            comment: protoReq.memo)
        guard handleValidationResult(result, protocolRequest: protoReq) else { return }
        addressCell.setContent(protoReq.displayText)
        memoCell.content = protoReq.memo
        amountView.forceUpdateAmount(amount: requestAmount)
        addressCell.isEditable = false
        addressCell.hideActionButtons()
        amountView.isEditable = false
        sender.displayPaymentProtocolResponse = { self.showAlert(title: S.Import.success, message: $0) }
    }
    
    private func handleZeroAmountPaymentProtocolRequest(_ protoReq: PaymentProtocolRequest) {
        guard let address = protoReq.primaryTarget?.description else {
            showErrorMessage(S.Send.invalidAddressTitle); return
        }
        //After this point, a zero amount Payment protocol request behaves like a
        //regular send except the address cell isn't editable
        addressCell.setContent(address)
        addressCell.isEditable = false
        addressCell.hideActionButtons()
    }
    
    // MARK: - Errors

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
