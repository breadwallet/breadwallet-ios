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
    var presentVerifyPin: ((@escaping VerifyPinCallback)->Void)?
    var onPublishSuccess: (()->Void)?
    var onPublishFailure: (()->Void)?
    var parentView: UIView? //ModalPresentable
    var initialAddress: String?
    var isPresentedFromLock = false

    init(store: Store, sender: Sender, walletManager: WalletManager, initialAddress: String? = nil) {
        self.store = store
        self.sender = sender
        self.walletManager = walletManager
        self.initialAddress = initialAddress
        if LAContext.canUseTouchID && store.state.isTouchIdEnabled {
            self.sendButton = ShadowButton(title: S.Send.sendLabel, type: .primary, image: #imageLiteral(resourceName: "TouchId"))
        } else {
            self.sendButton = ShadowButton(title: S.Send.sendLabel, type: .primary, image: #imageLiteral(resourceName: "PinForSend"))
        }

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
    private let sendButton: ShadowButton
    private let paste = ShadowButton(title: S.Send.pasteLabel, type: .tertiary)
    private let scan = ShadowButton(title: S.Send.scanLabel, type: .tertiary)
    private let currency = ShadowButton(title: S.Send.defaultCurrencyLabel, type: .tertiary)
    private let currencyBorder = UIView(color: .secondaryShadow)
    private var currencySwitcherHeightConstraint: NSLayoutConstraint?
    private var pinPadHeightConstraint: NSLayoutConstraint?
    private var balance: UInt64 = 0
    private var amount: Satoshis? {
        didSet {
            setSendButton()
        }
    }
    private var didIgnoreUsedAddressWarning = false
    private var didIgnoreIdentityNotCertified = false

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

        descriptionCell.pinToBottom(to: amountView.view, height: SendCell.defaultHeight)
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
                            self.balance = $0.walletState.balance
        })
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
        }
    }

    private func addButtonActions() {
        paste.addTarget(self, action: #selector(SendViewController.pasteTapped), for: .touchUpInside)
        scan.addTarget(self, action: #selector(SendViewController.scanTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        descriptionCell.textFieldDidReturn = { textField in
            textField.resignFirstResponder()
        }
        amountView.balanceTextForAmount = { [weak self] amount, rate in
            return self?.balanceTextForAmount(amount: amount, rate: rate)
        }

        amountView.didUpdateAmount = { [weak self] amount in
            self?.amount = amount
        }
    }

    private func balanceTextForAmount(amount: Satoshis?, rate: Rate?) -> NSAttributedString? {
        let balanceText = NumberFormatter.formattedString(amount: Satoshis(rawValue: balance), rate: rate, minimumFractionDigits: nil)
        var output = ""
        var color: UIColor = .grayTextTint
        if let amount = amount, amount.rawValue > 0 {
            let fee = sender.feeForTx(amount: amount.rawValue)
            let feeText = NumberFormatter.formattedString(amount: Satoshis(rawValue: fee), rate: rate, minimumFractionDigits: nil)
            output = String(format: S.Send.balanceWithFee, balanceText, feeText)
            if amount.rawValue > (balance - fee) {
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

    private func setSendButton() {
        guard let amount = amount else { sendButton.image = nil; return }
        if sender.maybeCanUseTouchId(forAmount: amount.rawValue) {
            sendButton.image = #imageLiteral(resourceName: "TouchId")
        } else {
            sendButton.image = #imageLiteral(resourceName: "PinForSend")
        }
    }

    @objc private func pasteTapped() {
        store.subscribe(self, selector: {$0.pasteboard != $1.pasteboard}, callback: {
            if let address = $0.pasteboard {
                if address.isValidAddress {
                    self.to.content = address
                } else {
                    self.invalidAddressAlert()
                }
            }
            //TODO - this should be a granular unsubscribe
            //just for pasteboard
            self.store.unsubscribe(self)
        })
    }

    @objc private func scanTapped() {
        descriptionCell.textField.resignFirstResponder()
        presentScan? { [weak self] paymentRequest in
            guard let request = paymentRequest else { return }
            switch request.type {
            case .local:
                self?.to.content = request.toAddress
                if let amount = request.amount {
                    self?.amountView.forceUpdateAmount(amount: amount)
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
    }

    @objc private func sendTapped() {
        if sender.transaction != nil {
            send()
        } else {
            guard let address = to.content else { return }
            guard let amount = amount else { return }
            sender.createTransaction(amount: amount.rawValue, to: address)
            send()
        }
    }

    private func send() {
        sender.send(verifyPinFunction: { [weak self] pinValidationCallback in
            self?.presentVerifyPin? { [weak self] pin, vc in
                if pinValidationCallback(pin) {
                    vc.dismiss(animated: true, completion: {
                        self?.parent?.view.isFrameChangeBlocked = false
                    })
                }
            }
            }, completion: { [weak self] result in
                switch result {
                case .success:
                    self?.dismiss(animated: true, completion: {
                        guard let myself = self else { return }
                        if myself.isPresentedFromLock {
                            myself.store.trigger(name: .loginFromSend)
                        }
                        myself.onPublishSuccess?()
                    })
                case .creationError(let message):
                    print("creation error: \(message)")
                case .publishFailure(_): //TODO -add error messages here
                    self?.onPublishFailure?()
                }
        })
    }

    private func confirmProtocolRequest(protoReq: PaymentProtocolRequest) {
        guard let firstOutput = protoReq.details.outputs.first else { return }
        guard let wallet = walletManager.wallet else { return }

        let address = firstOutput.swiftAddress
        let isValid = protoReq.isValid()
        var isOutputTooSmall = false

        if let errorMessage = protoReq.errorMessage, errorMessage == S.PaymentProtocol.Errors.requestExpired, !isValid {
            return showProtocolError(title: S.PaymentProtocol.Errors.badPaymentRequest, message: errorMessage, buttonLabel: S.Button.ok)
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
            return showProtocolError(title: S.Alert.warning, message: S.Send.containsAddress, buttonLabel: S.Button.ok)
        } else if wallet.addressIsUsed(address) {
            let message = "\(S.Send.UsedAddress.title)\n\n\(S.Send.UsedAddress.firstLine)\n\n\(S.Send.UsedAddress.secondLine)"
            return showProtocolError(title: S.Alert.warning, message: message, ignore: { [weak self] in
                self?.didIgnoreUsedAddressWarning = true
                self?.confirmProtocolRequest(protoReq: protoReq)
            })
        } else if let message = protoReq.errorMessage, message.utf8.count > 0 && (protoReq.commonName?.utf8.count)! > 0 {
            return showProtocolError(title: S.Send.identityNotCertified, message: message, ignore: { [weak self] in
                self?.didIgnoreUsedAddressWarning = true
                self?.confirmProtocolRequest(protoReq: protoReq)
            })
        } else if requestAmount < wallet.minOutputAmount {
            let message = String(format: S.PaymentProtocol.Errors.smallPayment, "\(Amount.bitsFormatter.string(from: Double(wallet.minOutputAmount)/100.0 as NSNumber) ?? "")")
            return showProtocolError(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
        } else if isOutputTooSmall {
            let message = String(format: S.PaymentProtocol.Errors.smallTransaction, "\(Amount.bitsFormatter.string(from: Double(wallet.minOutputAmount)/100.0 as NSNumber) ?? "")")
            return showProtocolError(title: S.PaymentProtocol.Errors.smallOutputErrorTitle, message: message, buttonLabel: S.Button.ok)
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
                sender.createTransaction(amount: amount.rawValue, to: address)
            }
        } else {
            sender.createTransaction(forPaymentProtocol: protoReq)
        }
    }

    private func showProtocolError(title: String, message: String, buttonLabel: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    private func showProtocolError(title: String, message: String, ignore: @escaping () -> Void) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.ignore, style: .default, handler: { _ in
            ignore()
        }))
        alertController.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    private func invalidAddressAlert() {
        let alertController = UIAlertController(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
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
        return S.Send.modalTitle
    }
}
