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
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
    }

    //MARK - Private
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private let store: Store
    private let sender: Sender
    private let to = LabelSendCell(label: S.Send.toLabel)
    private let amount = TextFieldSendCell(placeholder: S.Send.amountLabel, isKeyboardHidden: true)
    private let currencySwitcher = InViewAlert(type: .secondary)
    private let pinPad = PinPadViewController(style: .white, keyboardType: .decimalPad)
    private let descriptionCell = TextFieldSendCell(placeholder: S.Send.descriptionLabel, isKeyboardHidden: false)
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

        let currencySlider = CurrencySlider()
        currencySlider.didSelectCurrency = { currency in
            //TODO add real currency logic here
            self.currency.title = "\(currency.substring(to: currency.index(currency.startIndex, offsetBy: 3))) \u{25BC}"
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

        to.content = "mztqMM6JTZVrRubrU2K4xtiCjM96gzfYGz"
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
            self?.store.perform(action: ModalDismissal.block())

            guard let rate = myself.rate else { return }
            let amount = Amount(amount: myself.balance, rate: rate.rate)
            myself.amount.setLabel(text: "Current Balance: \(amount.bits)", color: .grayTextTint)

        }
        amount.textFieldDidReturn = { [weak self] _ in
            self?.store.perform(action: ModalDismissal.unBlock())
        }
        amount.textFieldDidChange = { text in
            guard let rate = self.rate else { return }
            let amount = Amount(amount: self.balance, rate: rate.rate)
            var data: (String, UIColor) = ("Current balance: \(amount.bits)", .grayTextTint)
            if let value = Int(text) {
                if value * 100 > Int(self.balance) {
                    data = ("Insufficient Funds. Max balance: \(amount.bits)", .red)
                    self.send.isEnabled = false
                } else {
                    self.send.isEnabled = true
                }
            }
            self.amount.setLabel(text: data.0, color: data.1)
        }
        descriptionCell.textFieldDidReturn = { textField in
            textField.resignFirstResponder()
        }
        send.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
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
            self.store.unsubscribe(self)
        })
    }

    @objc private func scanTapped() {
        descriptionCell.textField.resignFirstResponder()
        presentScan? { address in
            self.to.content = address
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
            store.perform(action: ModalDismissal.block())
            addCurrencyOverlay()
            isPresenting = true
        } else {
            UIView.animate(withDuration: 0.1, animations: {
                self.currencyOverlay.alpha = 0.0
            }, completion: { _ in
                self.currencyOverlay.removeFromSuperview()
            })
            store.perform(action: ModalDismissal.unBlock())
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
        guard let address = to.content else { return /*TODO - no address error*/ }
        guard let amount = amount.content else { return /*TODO - bad amount*/ }
        guard let numericAmount = UInt64(amount) else { return /*TODO - bad amount*/ }

        sender.send(amount: numericAmount,
                    to: address,
                    verifyPin: { pinValidationCallback in
                        presentVerifyPin? { pin, vc in
                            if pinValidationCallback(pin) {
                                vc.dismiss(animated: true, completion: {
                                    self.parent?.view.isFrameChangeBlocked = false
                                })
                            }
                        }
                    }, completion: { result in
                        switch result {
                        case .success:
                            self.dismiss(animated: true, completion: {
                                self.onPublishSuccess?()
                            })
                        case .creationError(let message):
                            print("creation error: \(message)")
                        case .publishFailure(_): //TODO -add error messages here
                            self.onPublishFailure?()
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
        alertController.view.tintColor = C.defaultTintColor
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
    var modalTitle: String {
        return NSLocalizedString("Send Money", comment: "Send modal title")
    }
    
    var isFaqHidden: Bool {
        return false
    }
}
