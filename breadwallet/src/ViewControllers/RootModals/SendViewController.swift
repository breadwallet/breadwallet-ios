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
private let cellHeight: CGFloat = 72.0
private let verticalButtonPadding: CGFloat = 32.0
private let buttonSize = CGSize(width: 52.0, height: 32.0)
private let currencyButtonWidth: CGFloat = 64.0

class SendViewController: UIViewController, Subscriber, ModalPresentable {

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    var presentScan: PresentScan?

    private let store: Store
    private let to = LabelSendCell(label: S.Send.toLabel)
    private let amount = TextFieldSendCell(placeholder: S.Send.amountLabel)
    private let currencySwitcher = InViewAlert(type: .secondary)
    private let pinPad = PinPadViewController()
    private let descriptionCell = LabelSendCell(label: S.Send.descriptionLabel)
    private let send = ShadowButton(title: S.Send.sendLabel, type: .primary, image: #imageLiteral(resourceName: "TouchId"))
    private let paste = ShadowButton(title: S.Send.pasteLabel, type: .tertiary)
    private let scan = ShadowButton(title: S.Send.scanLabel, type: .tertiary)
    private let currency = ShadowButton(title: S.Send.currencyLabel, type: .tertiary)
    private let currencyBorder = UIView(color: .secondaryShadow)
    private var currencySwitcherHeightConstraint: NSLayoutConstraint?
    private var pinPadHeightConstraint: NSLayoutConstraint?
    private var currencyOverlay = CurrencyOverlay()
    var parentView: UIView?

    override func viewDidLoad() {
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
        to.constrainTopCorners(height: cellHeight)
        amount.pinToBottom(to: to, height: cellHeight)
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

        descriptionCell.pinToBottom(to: pinPad.view, height: cellHeight)
        send.constrain([
            send.constraint(.leading, toView: view, constant: C.padding[2]),
            send.constraint(.trailing, toView: view, constant: -C.padding[2]),
            send.constraint(toBottom: descriptionCell, constant: verticalButtonPadding),
            send.constraint(.height, constant: C.Sizes.buttonHeight) ])
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
            currency.constraint(.centerY, toView: amount),
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
    }

    private func addButtonActions() {
        paste.addTarget(self, action: #selector(SendViewController.pasteTapped), for: .touchUpInside)
        scan.addTarget(self, action: #selector(SendViewController.scanTapped), for: .touchUpInside)
        currency.addTarget(self, action: #selector(SendViewController.currencySwitchTapped), for: .touchUpInside)
        pinPad.ouputDidUpdate = { output in
            self.amount.content = output
        }
        amount.textFieldDidBeginEditing = {
            self.amountTapped()
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
            self.store.unsubscribe(self)
        })
    }

    @objc private func scanTapped() {
        presentScan? { address in
            self.to.content = address
        }
    }

    @objc private func amountTapped() {
        guard let parentView = parentView else { return }
        UIView.spring(C.animationDuration, animations: {
            if self.pinPadHeightConstraint?.constant == 0.0 {
                self.pinPadHeightConstraint?.constant = PinPadViewController.height
                parentView.frame = parentView.frame.expandVertically(PinPadViewController.height)
            } else {
                self.pinPadHeightConstraint?.constant = 0.0
                parentView.frame = parentView.frame.expandVertically(-PinPadViewController.height)
            }
            self.parent?.view.layoutIfNeeded()
        }, completion: {_ in })
    }

    @objc private func currencySwitchTapped() {
        guard let parentView = parentView else { return }
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
                parentView.frame = parentView.frame.expandVertically(currencyHeight)
            } else {
                self.currencySwitcherHeightConstraint?.constant = 0.0
                parentView.frame = parentView.frame.expandVertically(-currencyHeight)
            }
            if isPresenting {
                self.currencyOverlay.alpha = 1.0
            }
            parentView.layoutIfNeeded()
        }, completion: {_ in })
    }

    private func addCurrencyOverlay() {
        guard let parentView = parentView else { return }
        guard let parentSuperView = parentView.superview else { return }

        amount.addSubview(currencyOverlay.middle)
        parentSuperView.addSubview(currencyOverlay.bottom)
        parentSuperView.insertSubview(currencyOverlay.top, belowSubview: parentView)
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
        currencyOverlay.alpha = 0.0
        self.amount.bringSubview(toFront: self.currency)
    }

    private func invalidAddressAlert() {
        let alertController = UIAlertController(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
        alertController.view.tintColor = C.defaultTintColor
        present(alertController, animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SendViewController: ModalDisplayable {
    var modalTitle: String {
        return NSLocalizedString("Send Money", comment: "Send modal title")
    }

    var modalSize: CGSize {
        return CGSize(width: view.frame.width, height: cellHeight*3 + verticalButtonPadding*2 + C.Sizes.buttonHeight)
    }

    var isFaqHidden: Bool {
        return false
    }
}
