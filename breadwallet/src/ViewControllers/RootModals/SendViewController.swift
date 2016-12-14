//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class SendViewController: UIViewController, Subscriber {

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    private let store: Store
    fileprivate let cellHeight: CGFloat = 72.0
    fileprivate let verticalButtonPadding: CGFloat = 32.0
    private let buttonSize = CGSize(width: 52.0, height: 32.0)

    private let to = SendCell(label: S.Send.toLabel)
    private let amount = SendCell(label: S.Send.amountLabel)
    private let descriptionCell = SendCell(label: S.Send.descriptionLabel)
    private let send = ShadowButton(title: S.Send.sendLabel, type: .primary, image: #imageLiteral(resourceName: "TouchId"))
    private let paste = ShadowButton(title: S.Send.pasteLabel, type: .tertiary)
    private let scan = ShadowButton(title: S.Send.scanLabel, type: .tertiary)
    private let currency = ShadowButton(title: S.Send.currencyLabel, type: .tertiary)

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
        guard ScanViewController.isCameraAllowed else {
            //TODO - add link to settings here
            let alertController = UIAlertController(title: S.Send.cameraUnavailableTitle, message: S.Send.cameraUnavailableMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: S.Button.ok, style: .cancel, handler: nil))
            alertController.view.tintColor = C.defaultTintColor
            present(alertController, animated: true, completion: nil)
            return
        }
        let vc = ScanViewController(completion: { address in
            self.to.content = address
        }, isValidURI: { address in
            return address.hasPrefix("bitcoin:")
        })
        present(vc, animated: true, completion: {})
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
