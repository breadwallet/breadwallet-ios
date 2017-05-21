//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

typealias PresentScan = ((@escaping ScanCompletion) -> Void)

private let verticalButtonPadding: CGFloat = 32.0
private let buttonSize = CGSize(width: 52.0, height: 32.0)
//private let currencyButtonWidth: CGFloat = 64.0

class SendViewController : UIViewController, Subscriber, ModalPresentable {

    //MARK - Public
    var presentScan: PresentScan?
    var presentVerifyPin: ((@escaping VerifyPinCallback)->Void)?
    var onPublishSuccess: (()->Void)?
    var onPublishFailure: (()->Void)?
    var parentView: UIView? //ModalPresentable
    var initialAddress: String?
    var isPresentedFromLock = false

    init(store: Store, sender: Sender, initialAddress: String? = nil) {
        self.store = store
        self.sender = sender
        self.initialAddress = initialAddress
        self.currencySlider = CurrencySlider(rates: store.state.rates,
                                             defaultCode: store.state.defaultCurrencyCode,
                                             isBtcSwapped: store.state.isBtcSwapped)
        if LAContext.canUseTouchID && store.state.isTouchIdEnabled {
            self.send = ShadowButton(title: S.Send.sendLabel, type: .primary, image: #imageLiteral(resourceName: "TouchId"))
        } else {
            self.send = ShadowButton(title: S.Send.sendLabel, type: .primary, image: #imageLiteral(resourceName: "PinForSend"))
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
    private let currencySlider: CurrencySlider
    private let amountView: AmountViewController
    private let to = LabelSendCell(label: S.Send.toLabel)
    private let descriptionCell = DescriptionSendCell(placeholder: S.Send.descriptionLabel)
    private let send: ShadowButton
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

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(to)
        view.addSubview(descriptionCell)
        view.addSubview(send)

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
        send.constrain([
            send.constraint(.leading, toView: view, constant: C.padding[2]),
            send.constraint(.trailing, toView: view, constant: -C.padding[2]),
            send.constraint(toBottom: descriptionCell, constant: verticalButtonPadding),
            send.constraint(.height, constant: C.Sizes.buttonHeight),
            send.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[2]) ])
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
        send.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
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
                send.isEnabled = false
                color = .cameraGuideNegative
            } else {
                send.isEnabled = true
            }
        } else {
            output = String(format: S.Send.balance, balanceText)
            send.isEnabled = false
        }

        let attributes: [String: Any] = [
            NSFontAttributeName: UIFont.customBody(size: 14.0),
            NSForegroundColorAttributeName: color
        ]

        return NSAttributedString(string: output, attributes: attributes)
    }

    private func setSendButton() {
        guard let amount = amount else { send.image = nil; return }
        if sender.maybeCanUseTouchId(forAmount: amount.rawValue) {
            send.image = #imageLiteral(resourceName: "TouchId")
        } else {
            send.image = #imageLiteral(resourceName: "PinForSend")
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
                //if let amount = request.amount {
                    //self?.amount.content = String(amount/100) //TODO - implement
                //}
            case .remote:
                print("remote request")
            }
        }
    }

    @objc private func sendTapped() {
        guard let address = to.content else { return }
        guard let amount = amount else { return }
        sender.createTransaction(amount: amount.rawValue, to: address)
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
