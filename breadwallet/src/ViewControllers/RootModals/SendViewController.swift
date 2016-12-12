//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let toLabel = NSLocalizedString("To", comment: "Send money to label")
private let amountLabel = NSLocalizedString("Amount", comment: "Send money amount label")
private let descriptionLabel = NSLocalizedString("What's this for?", comment: "Description for sending money label")
private let sendLabel = NSLocalizedString("Send", comment: "Send button label")
private let pasteLabel = NSLocalizedString("Paste", comment: "Paste button label")
private let scanLabel = NSLocalizedString("Scan", comment: "Scan button label")
private let currencyLabel = NSLocalizedString("USD \u{25BC}", comment: "Currency Button label")

private let invalidAddressTitle = NSLocalizedString("Invalid Address", comment: "Invalid address alert title")
private let invalidAddressMessage = NSLocalizedString("Your clipboard does not have a valid bitcoin address.", comment: "Invalid address alert message")

class SendViewController: UIViewController, Subscriber {

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    private let store: Store
    fileprivate let cellHeight: CGFloat = 72.0
    fileprivate let verticalButtonPadding: CGFloat = 32.0
    private let buttonSize = CGSize(width: 52.0, height: 32.0)

    private let to = SendCell(label: toLabel)
    private let amount = SendCell(label: amountLabel)
    private let descriptionCell = SendCell(label: descriptionLabel)
    private let send = ShadowButton(title: sendLabel, type: .primary, image: #imageLiteral(resourceName: "TouchId"))
    private let paste = ShadowButton(title: pasteLabel, type: .tertiary)
    private let scan = ShadowButton(title: scanLabel, type: .tertiary)
    private let currency = ShadowButton(title: currencyLabel, type: .tertiary)

    override func viewDidLoad() {
        view.addSubview(to)
        view.addSubview(amount)
        view.addSubview(descriptionCell)
        view.addSubview(send)
        to.accessoryView.addSubview(paste)
        to.accessoryView.addSubview(scan)
        amount.addSubview(currency)

        to.constrainTopCorners(height: cellHeight)
        amount.pinToBottom(to: to, height: cellHeight)
        descriptionCell.pinToBottom(to: amount, height: cellHeight)
        send.constrain([
                send.constraint(.leading, toView: view, constant: C.padding[2]),
                send.constraint(.trailing, toView: view, constant: -C.padding[2]),
                send.constraint(toBottom: descriptionCell, constant: verticalButtonPadding),
                send.constraint(.height, constant: C.Sizes.buttonHeight)
            ])
        scan.constrain([
                scan.constraint(.centerY, toView: to.accessoryView),
                scan.constraint(.trailing, toView: to.accessoryView, constant: -C.padding[2]),
                scan.constraint(.height, constant: buttonSize.height),
                scan.constraint(.width, constant: buttonSize.width)
            ])
        paste.constrain([
                paste.constraint(.centerY, toView: to.accessoryView),
                paste.constraint(toLeading: scan, constant: -C.padding[1]),
                paste.constraint(.height, constant: buttonSize.height),
                paste.constraint(.width, constant: buttonSize.width),
                paste.constraint(.leading, toView: to.accessoryView) //This constraint is needed because it gives the accessory view an intrinsic horizontal size
            ])
        currency.constrain([
                currency.constraint(.centerY, toView: amount),
                currency.constraint(.trailing, toView: amount, constant: -C.padding[2]),
                currency.constraint(.height, constant: buttonSize.height),
                currency.constraint(.width, constant: 64.0)
            ])
        addButtonActions()
    }

    private func addButtonActions() {
        paste.addTarget(self, action: #selector(SendViewController.pasteTapped), for: .touchUpInside)
        scan.addTarget(self, action: #selector(SendViewController.scanTapped), for: .touchUpInside)
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

    }

    private func invalidAddressAlert() {
        let alertController = UIAlertController(title: invalidAddressTitle, message: invalidAddressMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
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
