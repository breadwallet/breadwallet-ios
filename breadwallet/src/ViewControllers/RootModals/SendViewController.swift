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

class SendViewController : UIViewController, Subscriber, ModalPresentable {

    //MARK - Public
    var presentScan: PresentScan?
    var presentVerifyPin: ((String, @escaping VerifyPinCallback)->Void)?
    var onPublishSuccess: (()->Void)?
    var parentView: UIView? //ModalPresentable
    var initialAddress: String?
    var isPresentedFromLock = false

    init(store: Store, sender: Sender, walletManager: WalletManager, initialAddress: String? = nil, initialRequest: PaymentRequest? = nil) {
        self.store = store
        self.sender = sender
        self.walletManager = walletManager
        self.initialAddress = initialAddress
        self.initialRequest = initialRequest
        self.currency = ShadowButton(title: S.Symbols.currencyButtonTitle(maxDigits: store.state.maxDigits), type: .tertiary)
        amountView = AmountViewController(store: store, isPinPadExpandedAtLaunch: false)

        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
    }

    //MARK - Private
    deinit {
        store.unsubscribe(self)
        NotificationCenter.default.removeObserver(self)
    }

    private let store: Store
    private let sender: Sender
    private let walletManager: WalletManager
    private let amountView: AmountViewController
    private let to = LabelSendCell(label: S.Send.toLabel)
    private let descriptionCell = DescriptionSendCell(placeholder: S.Send.descriptionLabel)
    private let sendButton = ShadowButton(title: S.Send.sendLabel, type: .primary)
    private let paste = ShadowButton(title: S.Send.pasteLabel, type: .tertiary)
    private let scan = ShadowButton(title: S.Send.scanLabel, type: .tertiary)
    private let currency: ShadowButton
    private let currencyBorder = UIView(color: .secondaryShadow)
    private var currencySwitcherHeightConstraint: NSLayoutConstraint?
    private var pinPadHeightConstraint: NSLayoutConstraint?
    private var balance: UInt64 = 0
    private var amount: Satoshis?
    private var didIgnoreUsedAddressWarning = false
    private var didIgnoreIdentityNotCertified = false
    private let initialRequest: PaymentRequest?

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(to)
        view.addSubview(descriptionCell)
        view.addSubview(sendButton)

        to.accessoryView.addSubview(paste)
        to.accessoryView.addSubview(scan)
        to.constrainTopCorners(height: SendCell.defaultHeight)

        addChildViewController(amountView, layout: {
            amountView.view.constrain([
                amountView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                amountView.view.topAnchor.constraint(equalTo: to.bottomAnchor),
                amountView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
        })

        descriptionCell.constrain([
            descriptionCell.widthAnchor.constraint(equalTo: amountView.view.widthAnchor),
            descriptionCell.topAnchor.constraint(equalTo: amountView.view.bottomAnchor),
            descriptionCell.leadingAnchor.constraint(equalTo: amountView.view.leadingAnchor),
            descriptionCell.heightAnchor.constraint(equalTo: descriptionCell.textView.heightAnchor, constant: C.padding[4]) ])

        descriptionCell.accessoryView.constrain([
                descriptionCell.accessoryView.constraint(.width, constant: 0.0) ])

        sendButton.constrain([
            sendButton.constraint(.leading, toView: view, constant: C.padding[2]),
            sendButton.constraint(.trailing, toView: view, constant: -C.padding[2]),
            sendButton.constraint(toBottom: descriptionCell, constant: verticalButtonPadding),
            sendButton.constraint(.height, constant: C.Sizes.buttonHeight),
            sendButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[2]) ])
        scan.constrain([
            scan.constraint(.centerY, toView: to.accessoryView),
            scan.constraint(.trailing, toView: to.accessoryView, constant: -C.padding[2]),
            scan.constraint(.height, constant: buttonSize.height) ])
        paste.constrain([
            paste.constraint(.centerY, toView: to.accessoryView),
            paste.constraint(toLeading: scan, constant: -C.padding[1]),
            paste.constraint(.height, constant: buttonSize.height) ])

        preventCellContentOverflow()
        addButtonActions()

        store.subscribe(self, selector: { $0.walletState.balance != $1.walletState.balance },
                        callback: {
                            if let balance = $0.walletState.balance {
                                self.balance = balance
                            }
        })
        sendButton.isEnabled = false
    }

    private func preventCellContentOverflow() {
        to.contentLabel.constrain([
            to.contentLabel.trailingAnchor.constraint(lessThanOrEqualTo: paste.leadingAnchor, constant: -C.padding[2]) ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if initialAddress != nil {
            to.content = initialAddress
            amountView.expandPinPad()
        } else if let initialRequest = initialRequest {
            handleRequest(initialRequest)
        }
    }

    private func addButtonActions() {
        paste.addTarget(self, action: #selector(SendViewController.pasteTapped), for: .touchUpInside)
        scan.addTarget(self, action: #selector(SendViewController.scanTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        descriptionCell.didReturn = { textView in
            textView.resignFirstResponder()
        }
        descriptionCell.didBeginEditing = { [weak self] in
            self?.amountView.closePinPad()
        }
        amountView.balanceTextForAmount = { [weak self] amount, rate in
            return self?.balanceTextForAmount(amount: amount, rate: rate)
        }

        amountView.didUpdateAmount = { [weak self] amount in
            self?.amount = amount
        }

        amountView.didChangeFirstResponder = { [weak self] isFirstResponder in
            if isFirstResponder {
                self?.descriptionCell.textView.resignFirstResponder()
            }
        }
    }

    private func balanceTextForAmount(amount: Satoshis?, rate: Rate?) -> NSAttributedString? {
        let balanceText = NumberFormatter.formattedString(amount: Satoshis(rawValue: balance), rate: rate, minimumFractionDigits: nil, maxDigits: store.state.maxDigits)
        var output = ""
        var color: UIColor = .grayTextTint
        if let amount = amount, amount.rawValue > 0 {
            let fee = sender.feeForTx(amount: amount.rawValue)
            let feeText = NumberFormatter.formattedString(amount: Satoshis(rawValue: fee), rate: rate, minimumFractionDigits: nil, maxDigits: store.state.maxDigits)
            output = String(format: S.Send.balanceWithFee, balanceText, feeText)
            if (balance >= fee) && amount.rawValue > (balance - fee) {
                sendButton.isEnabled = false
                color = .cameraGuideNegative
            } else {
                sendButton.isEnabled = true
            }
        } else {
            output = String(format: S.Send.balance, balanceText)
            sendButton.isEnabled = false
        }

        let attributes: [String: Any] = [
            NSFontAttributeName: UIFont.customBody(size: 14.0),
            NSForegroundColorAttributeName: color
        ]

        return NSAttributedString(string: output, attributes: attributes)
    }

    @objc private func pasteTapped() {
        store.subscribe(self, selector: {$0.pasteboard != $1.pasteboard}, callback: {
            if let address = $0.pasteboard {
                if address.isValidAddress {
                    self.to.content = address
                } else {
                    self.showError(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressMessage, buttonLabel: S.Button.ok)
                }
            }
            //TODO - this should be a granular unsubscribe
            //just for pasteboard
            self.store.unsubscribe(self)
        })
    }

    @objc private func scanTapped() {
        descriptionCell.textView.resignFirstResponder()
        presentScan? { [weak self] paymentRequest in
            guard let request = paymentRequest else { return }
            self?.handleRequest(request)
        }
    }

    @objc private func sendTapped() {
        if sender.transaction != nil {
            send()
        } else {
            guard let address = to.content else {
                return showError(title: S.Alert.error, message: S.Send.noAddress, buttonLabel: S.Button.ok)
            }
            guard address.isValidAddress else {
                return showError(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressMessage, buttonLabel: S.Button.ok)
            }
            guard let amount = amount else {
                return showError(title: S.Alert.error, message: S.Send.noAmount, buttonLabel: S.Button.ok)
            }
            if let minOutput = walletManager.wallet?.minOutputAmount {
                guard amount.rawValue >= minOutput else {
                    let minOutputAmount = Amount(amount: minOutput, rate: Rate.empty, maxDigits: store.state.maxDigits)
                    let message = String(format: S.PaymentProtocol.Errors.smallPayment, minOutputAmount.string(isBtcSwapped: store.state.isBtcSwapped))
                    return showError(title: S.Alert.error, message: message, buttonLabel: S.Button.ok)
                }
            }
            guard !(walletManager.wallet?.containsAddress(address) ?? false) else {
                return showError(title: S.Alert.error, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
            }
            guard sender.createTransaction(amount: amount.rawValue, to: address) else {
                return showError(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
            }
            send()
        }
    }

    private func handleRequest(_ request: PaymentRequest) {
        switch request.type {
        case .local:
            to.content = request.toAddress
            if let amount = request.amount {
                amountView.forceUpdateAmount(amount: amount)
            }
            if request.label != nil {
                descriptionCell.content = request.label
            }
        case .remote:
            request.fetchRemoteRequest(completion: { [weak self] request in
                if let paymentProtocolRequest = request?.paymentProtoclRequest {
                    DispatchQueue.main.async {
                        self?.confirmProtocolRequest(protoReq: paymentProtocolRequest)
                    }
                }
            })
        }
    }

    private var sendMessage: String {
        let feeText = NumberFormatter.formattedString(amount: Satoshis(sender.fee), rate: amountView.selectedRate, minimumFractionDigits: nil, maxDigits: store.state.maxDigits)
        let totalText = NumberFormatter.formattedString(amount: Satoshis(sender.fee + (amount?.rawValue ?? 0)), rate: amountView.selectedRate, minimumFractionDigits: nil, maxDigits: store.state.maxDigits)

        func shrink(_ string: String) -> String {
            let start = string.substring(to: string.index(string.startIndex, offsetBy: 6))
            let end = string.substring(from: string.index(string.endIndex, offsetBy: -6))
            return start + "..." + end
        }

        var address = to.content ?? ""
        if address.isValidAddress {
            address = shrink(address)
        }

        let toLine = String(format: S.VerifyPin.to, address)
        let amountLine = String(format: S.VerifyPin.amount, amountView.currentOutput)
        let feeLine = String(format: S.VerifyPin.fee, feeText)
        let total = String(format: S.VerifyPin.total, totalText)
        return "\(toLine)\n\(amountLine)\n\(feeLine)\n\(total)"
    }

    private func send() {
        guard let rate = store.state.currentRate else { return }
        guard let feePerKb = walletManager.wallet?.feePerKb else { return }

        sender.send(touchIdMessage: sendMessage,
                    rate: rate,
                    comment: descriptionCell.textView.text,
                    feePerKb: feePerKb,
                    verifyPinFunction: { [weak self] pinValidationCallback in
                        guard let myself = self else { return }
                        self?.presentVerifyPin?(myself.sendMessage) { [weak self] pin, vc in
                            if pinValidationCallback(pin) {
                                vc.dismiss(animated: true, completion: {
                                    self?.parent?.view.isFrameChangeBlocked = false
                                })
                                return true
                            } else {
                                return false
                            }
                        }
            }, completion: { [weak self] result in
                switch result {
                case .success:
                    self?.dismiss(animated: true, completion: {
                        guard let myself = self else { return }
                        myself.store.trigger(name: .showStatusBar)
                        if myself.isPresentedFromLock {
                            myself.store.trigger(name: .loginFromSend)
                        }
                        myself.onPublishSuccess?()
                    })
                case .creationError(let message):
                    self?.showError(title: S.Send.createTransactionError, message: message, buttonLabel: S.Button.ok)
                case .publishFailure(let error):
                    if case .posixError(let code, let description) = error {
                        self?.showError(title: S.Alerts.sendFailure, message: "\(description) (\(code))", buttonLabel: S.Button.ok)
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
            return showError(title: S.PaymentProtocol.Errors.badPaymentRequest, message: errorMessage, buttonLabel: S.Button.ok)
        }

        //TODO: check for duplicates of already paid requests
        var requestAmount = Satoshis(0)
        protoReq.details.outputs.forEach { output in
            if output.amount > 0 && output.amount < wallet.minOutputAmount {
                isOutputTooSmall = true
            }
            requestAmount += output.amount
        }

        if wallet.containsAddress(address) {
            return showError(title: S.Alert.warning, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
        } else if wallet.addressIsUsed(address) {
            let message = "\(S.Send.UsedAddress.title)\n\n\(S.Send.UsedAddress.firstLine)\n\n\(S.Send.UsedAddress.secondLine)"
            return showError(title: S.Alert.warning, message: message, ignore: { [weak self] in
                self?.didIgnoreUsedAddressWarning = true
                self?.confirmProtocolRequest(protoReq: protoReq)
            })
        } else if let message = protoReq.errorMessage, message.utf8.count > 0 && (protoReq.commonName?.utf8.count)! > 0 {
            return showError(title: S.Send.identityNotCertified, message: message, ignore: { [weak self] in
                self?.didIgnoreUsedAddressWarning = true
                self?.confirmProtocolRequest(protoReq: protoReq)
            })
        } else if requestAmount < wallet.minOutputAmount {
            let amount = Amount(amount: wallet.minOutputAmount, rate: Rate.empty, maxDigits: store.state.maxDigits)
            let message = String(format: S.PaymentProtocol.Errors.smallPayment, amount.bits)
            return showError(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
        } else if isOutputTooSmall {
            let amount = Amount(amount: wallet.minOutputAmount, rate: Rate.empty, maxDigits: store.state.maxDigits)
            let message = String(format: S.PaymentProtocol.Errors.smallTransaction, amount.bits)
            return showError(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
        }

        if let name = protoReq.commonName {
            to.content = protoReq.pkiType != "none" ? "\(S.Symbols.lock) \(name.sanitized)" : name.sanitized
        }

        if requestAmount > 0 {
            amountView.forceUpdateAmount(amount: requestAmount)
        }
        descriptionCell.content = protoReq.details.memo

        if requestAmount == 0 {
            if let amount = amount {
                guard sender.createTransaction(amount: amount.rawValue, to: address) else {
                    return showError(title: S.Alert.error, message: S.Send.createTransactionError, buttonLabel: S.Button.ok)
                }
            }
        } else {
            sender.createTransaction(forPaymentProtocol: protoReq)
        }
    }

    private func showError(title: String, message: String, buttonLabel: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
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
        return ArticleIds.send
    }

    var modalTitle: String {
        return S.Send.title
    }
}
