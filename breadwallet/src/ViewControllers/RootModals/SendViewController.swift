//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

typealias PresentScan = ((@escaping ScanCompletion) -> Void)

private let currencyHeight: CGFloat = 80.0
private let verticalButtonPadding: CGFloat = 32.0
private let buttonSize = CGSize(width: 52.0, height: 32.0)
private let currencyButtonWidth: CGFloat = 64.0

class SendViewController : UIViewController, Subscriber, ModalPresentable {

    //MARK - Public
    var presentScan: PresentScan?
    var presentVerifyPin: ((@escaping VerifyPinCallback)->Void)?
    var onPublishSuccess: (()->Void)?
    var onPublishFailure: (()->Void)?
    var parentView: UIView? //ModalPresentable
    var initialAddress: String?

    init(store: Store, sender: Sender, initialAddress: String? = nil) {
        self.store = store
        self.sender = sender
        self.initialAddress = initialAddress
        self.currencySlider = CurrencySlider(rates: store.state.rates)
        
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
    private let to = LabelSendCell(label: S.Send.toLabel)
    private let amount = SendAmountCell(placeholder: S.Send.amountLabel)
    private let currencySwitcher = InViewAlert(type: .secondary)
    private let pinPad = PinPadViewController(style: .white, keyboardType: .decimalPad)
    private let descriptionCell = DescriptionSendCell(placeholder: S.Send.descriptionLabel)
    private let send = ShadowButton(title: S.Send.sendLabel, type: .primary, image: #imageLiteral(resourceName: "TouchId"))
    private let paste = ShadowButton(title: S.Send.pasteLabel, type: .tertiary)
    private let scan = ShadowButton(title: S.Send.scanLabel, type: .tertiary)
    private let currency = ShadowButton(title: S.Send.defaultCurrencyLabel, type: .tertiary)
    private let currencyBorder = UIView(color: .secondaryShadow)
    private var currencySwitcherHeightConstraint: NSLayoutConstraint?
    private var pinPadHeightConstraint: NSLayoutConstraint?
    private var currencyOverlay = CurrencyOverlay()
    private var balance: UInt64 = 0
    private var rate: Rate?
    private let currencySlider: CurrencySlider

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(to)
        view.addSubview(amount)
        view.addSubview(currencySwitcher)
        view.addSubview(currencyBorder)
        view.addSubview(pinPad.view)
        view.addSubview(descriptionCell)
        view.addSubview(send)

        to.accessoryView.addSubview(paste)
        to.accessoryView.addSubview(scan)
        amount.addSubview(currency)
        currency.isToggleable = true
        to.constrainTopCorners(height: SendCell.defaultHeight)

        amount.constrain([
            amount.widthAnchor.constraint(equalTo: to.widthAnchor),
            amount.topAnchor.constraint(equalTo: to.bottomAnchor),
            amount.leadingAnchor.constraint(equalTo: to.leadingAnchor) ])

        //amount.pinToBottom(to: to, height: SendCell.defaultHeight)
        amount.clipsToBounds = false

        currencySwitcherHeightConstraint = currencySwitcher.constraint(.height, constant: 0.0)
        currencySwitcher.constrain([
            currencySwitcher.constraint(toBottom: amount, constant: 0.0),
            currencySwitcher.constraint(.leading, toView: view),
            currencySwitcher.constraint(.trailing, toView: view),
            currencySwitcherHeightConstraint ])
        currencySwitcher.arrowXLocation = view.bounds.width - currencyButtonWidth/2.0 - C.padding[2]

        amount.border.isHidden = true //Hide the default border because it needs to stay below the currency switcher when it gets expanded
        currencyBorder.constrain([
            currencyBorder.constraint(.height, constant: 1.0),
            currencyBorder.constraint(.leading, toView: view),
            currencyBorder.constraint(.trailing, toView: view),
            currencyBorder.constraint(toBottom: currencySwitcher, constant: 0.0) ])

        pinPadHeightConstraint = pinPad.view.constraint(.height, constant: 0.0)
        addChildViewController(pinPad, layout: {
            pinPad.view.constrain([
                pinPad.view.constraint(toBottom: currencyBorder, constant: 0.0),
                pinPad.view.constraint(.leading, toView: view),
                pinPad.view.constraint(.trailing, toView: view),
                pinPadHeightConstraint ])
        })
        descriptionCell.pinToBottom(to: pinPad.view, height: SendCell.defaultHeight)
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
            scan.constraint(.height, constant: buttonSize.height),
            scan.constraint(.width, constant: buttonSize.width) ])
        paste.constrain([
            paste.constraint(.centerY, toView: to.accessoryView),
            paste.constraint(toLeading: scan, constant: -C.padding[1]),
            paste.constraint(.height, constant: buttonSize.height),
            paste.constraint(.width, constant: buttonSize.width),
            paste.constraint(.leading, toView: to.accessoryView) ]) //This constraint is needed because it gives the accessory view an intrinsic horizontal size
        currency.constrain([
            currency.constraint(.centerY, toView: amount.accessoryView),
            currency.constraint(.trailing, toView: amount, constant: -C.padding[2]),
            currency.constraint(.height, constant: buttonSize.height),
            currency.constraint(.width, constant: 64.0),
            currency.constraint(.leading, toView: amount.accessoryView, constant: C.padding[2]) ]) //This constraint is needed because it gives the accessory view an intrinsic horizontal size
        
        addButtonActions()

        currencySlider.didSelectCurrency = { [weak self] currency in
            //TODO add real currency logic here
            self?.currency.title = "\(currency.substring(to: currency.index(currency.startIndex, offsetBy: 3))) \u{25BC}"
        }
        currencySwitcher.contentView = currencySlider

        store.subscribe(self, selector: { $0.walletState.balance != $1.walletState.balance },
                        callback: {
                            self.balance = $0.walletState.balance
        })

        store.subscribe(self, selector: { $0.currentRate != $1.currentRate },
                        callback: {
                            self.rate = $0.currentRate
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if initialAddress != nil {
            to.content = initialAddress
            amount.textField.becomeFirstResponder()
        }
    }

    private func addButtonActions() {
        paste.addTarget(self, action: #selector(SendViewController.pasteTapped), for: .touchUpInside)
        scan.addTarget(self, action: #selector(SendViewController.scanTapped), for: .touchUpInside)
        currency.addTarget(self, action: #selector(SendViewController.currencySwitchTapped), for: .touchUpInside)
        pinPad.ouputDidUpdate = { [weak self] output in
            self?.amount.content = output
        }
        amount.textFieldDidBeginEditing = { [weak self] in
            guard let myself = self else { return }
            self?.amountTapped()

            guard let rate = myself.rate else { return }
            let amount = Amount(amount: myself.balance, rate: rate.rate)
            myself.amount.setLabel(text: "Balance: \(amount.bits)", color: .grayTextTint)

        }

        //TODO - send multiple currencies
        amount.textFieldDidChange = { [weak self] text in
            guard let myself = self else { return }
            guard let rate = myself.rate else { return }
            let balanceAmount = Amount(amount: myself.balance, rate: rate.rate)

            //Set amount label
            let formatter = myself.bitsFormatter
            if let value = Double(text) {

                let numberFormatter = NumberFormatter()
                if let decimalLocation = text.range(of: numberFormatter.currencyDecimalSeparator)?.upperBound {
                    let locationValue = text.distance(from: text.endIndex, to: decimalLocation)
                    if locationValue == -2 {
                        formatter.minimumFractionDigits = 2
                    } else if locationValue == -1 {
                        formatter.minimumFractionDigits = 1
                    }
                }

                var output = formatter.string(from: value as NSNumber)

                //If trailing decimal, append the decimal to the output
                if let decimalLocation = text.range(of: numberFormatter.currencyDecimalSeparator)?.upperBound {
                    if text.endIndex == decimalLocation {
                        output = output?.appending(".")
                    }
                }

                myself.amount.setAmountLabel(text: output!)
            } else {
                myself.amount.setAmountLabel(text: "")
            }

            //Set balance text
            var data: (String, UIColor) = ("Balance: \(balanceAmount.bits)", .grayTextTint)
            if let value = Double(text) {

                let fee = myself.sender.feeForTx(amount: UInt64(value * 100.0))
                let feeString = ", Fee: \(formatter.string(from: fee/100 as NSNumber)!)"

                if Int(value * 100.0) > Int(myself.balance) {
                    data = ("Balance: \(balanceAmount.bits)\(feeString)", .red)
                    myself.send.isEnabled = false
                } else {
                    data = ("Balance: \(balanceAmount.bits)\(feeString)", .grayTextTint)
                    myself.send.isEnabled = true
                }

                myself.amount.setLabel(text: data.0, color: data.1)
            } else {
                myself.amount.setLabel(text: "Balance: \(balanceAmount.bits)", color: .grayTextTint)
            }

        }
        descriptionCell.textFieldDidReturn = { textField in
            textField.resignFirstResponder()
        }
        send.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    }

    private var bitsFormatter: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencyCode = "XBT"
        format.currencySymbol = "\(S.Symbols.bits)\(S.Symbols.narrowSpace)"
        format.maximumFractionDigits = 2
        format.minimumFractionDigits = 0 // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
        format.maximum = C.maxMoney as NSNumber
        return format
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
                    self?.amount.content = String(amount/100)
                }
            case .remote:
                print("remote request")
            }
        }
    }

    @objc private func amountTapped() {
        descriptionCell.textField.resignFirstResponder()
        UIView.spring(C.animationDuration, animations: {
            if self.pinPadHeightConstraint?.constant == 0.0 {
                self.pinPadHeightConstraint?.constant = self.pinPad.height
            } else {
                self.pinPadHeightConstraint?.constant = 0.0
            }
            self.parent?.view.layoutIfNeeded()
        }, completion: {_ in })
    }

    @objc private func currencySwitchTapped() {
        func isCurrencySwitcherCollapsed() -> Bool {
            return self.currencySwitcherHeightConstraint?.constant == 0.0
        }

        var isPresenting = false
        if isCurrencySwitcherCollapsed() {
            addCurrencyOverlay()
            isPresenting = true
        } else {
            UIView.animate(withDuration: 0.1, animations: {
                self.currencyOverlay.alpha = 0.0
            }, completion: { _ in
                self.currencyOverlay.removeFromSuperview()
            })
        }

        amount.layoutIfNeeded()
        UIView.spring(C.animationDuration, animations: {
            if isCurrencySwitcherCollapsed() {
                self.currencySwitcherHeightConstraint?.constant = currencyHeight
            } else {
                self.currencySwitcherHeightConstraint?.constant = 0.0
            }
            if isPresenting {
                self.currencyOverlay.alpha = 1.0
            }
            self.view.superview?.layoutIfNeeded()
        }, completion: {_ in })
    }

    @objc private func sendTapped() {
        guard let text = amount.textField.text else { return }
        guard let amount = UInt64(text) else { return }
        guard let address = to.content else { return }
        sender.createTransaction(amount: amount*100, to: address)
        sender.send(verifyPin: { pinValidationCallback in
                        presentVerifyPin? { [weak self] pin, vc in
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
                                self?.onPublishSuccess?()
                            })
                        case .creationError(let message):
                            print("creation error: \(message)")
                        case .publishFailure(_): //TODO -add error messages here
                            self?.onPublishFailure?()
                        }
                    })
    }

    private func addCurrencyOverlay() {
        guard let parentView = parentView else { return }
        guard let parentSuperView = parentView.superview else { return }

        amount.addSubview(currencyOverlay.middle)
        parentSuperView.addSubview(currencyOverlay.bottom)
        parentSuperView.insertSubview(currencyOverlay.top, belowSubview: parentView)
        parentView.addSubview(currencyOverlay.blocker)
        currencyOverlay.top.constrain(toSuperviewEdges: nil)
        currencyOverlay.middle.constrain([
            currencyOverlay.middle.constraint(.leading, toView: parentSuperView),
            currencyOverlay.middle.constraint(.trailing, toView: parentSuperView),
            currencyOverlay.middle.constraint(.bottom, toView: amount, constant: InViewAlert.arrowSize.height),
            currencyOverlay.middle.constraint(toBottom: to, constant: -1000.0) ])
        currencyOverlay.bottom.constrain([
            currencyOverlay.bottom.constraint(.leading, toView: parentSuperView),
            currencyOverlay.bottom.constraint(.bottom, toView: parentSuperView),
            currencyOverlay.bottom.constraint(.trailing, toView: parentSuperView),
            currencyOverlay.bottom.constraint(toBottom: currencyBorder, constant: 0.0)])
        currencyOverlay.blocker.constrain([
            currencyOverlay.blocker.constraint(.leading, toView: parentView),
            currencyOverlay.blocker.constraint(.top, toView: parentView),
            currencyOverlay.blocker.constraint(.trailing, toView: parentView),
            currencyOverlay.blocker.constraint(toTop: amount, constant: 0.0) ])
        currencyOverlay.alpha = 0.0
        self.amount.bringSubview(toFront: self.currency)
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
        return "send"
    }

    var modalTitle: String {
        return NSLocalizedString("Send Money", comment: "Send modal title")
    }
}
