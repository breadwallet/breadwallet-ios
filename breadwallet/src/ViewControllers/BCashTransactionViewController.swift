//
//  BCashTransactionViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-08-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class BCashTransactionViewController : UIViewController {

    private let titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)
    private let body = UILabel.wrapping(font: .customBody(size: 14.0), color: .darkText)
    private let topBorder = UIView(color: .secondaryShadow)
    private let addressCell = AddressCell()
    private let send = ShadowButton(title: "Send", type: .primary)
    private let walletManager: WalletManager
    private let store: Store
    private let txHash = UIButton(type: .system)
    private let txHashHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let verifyPinTransitionDelegate = PinTransitioningDelegate()

    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(body)
        view.addSubview(topBorder)
        view.addSubview(addressCell)
        view.addSubview(send)
        view.addSubview(txHash)
        view.addSubview(txHashHeader)
    }

    private func addConstraints() {
        titleLabel.pinTopLeft(padding: C.padding[2])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            body.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        topBorder.constrain([
            topBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBorder.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            topBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1.0) ])
        addressCell.constrain([
            addressCell.leadingAnchor.constraint(equalTo: topBorder.leadingAnchor),
            addressCell.topAnchor.constraint(equalTo: topBorder.bottomAnchor),
            addressCell.trailingAnchor.constraint(equalTo: topBorder.trailingAnchor),
            addressCell.heightAnchor.constraint(equalToConstant: SendCell.defaultHeight) ])
        send.constrain([
            send.leadingAnchor.constraint(equalTo: addressCell.leadingAnchor, constant: C.padding[2]),
            send.topAnchor.constraint(equalTo: addressCell.bottomAnchor, constant: C.padding[2]),
            send.trailingAnchor.constraint(equalTo: addressCell.trailingAnchor, constant: -C.padding[2]),
            send.heightAnchor.constraint(equalToConstant: 44.0) ])
        txHashHeader.constrain([
            txHashHeader.leadingAnchor.constraint(equalTo: send.leadingAnchor),
            txHashHeader.topAnchor.constraint(equalTo: send.bottomAnchor, constant: C.padding[4])])
        txHash.constrain([
            txHash.leadingAnchor.constraint(equalTo: txHashHeader.leadingAnchor),
            txHash.topAnchor.constraint(equalTo: txHashHeader.bottomAnchor),
            txHash.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
    }

    private func setInitialData() {
        view.backgroundColor = .whiteTint
        titleLabel.text = "Withdraw Bitcoin Cash"
        let amount = DisplayAmount(amount: Satoshis(rawValue: walletManager.bCashBalance), state: store.state, selectedRate: nil, minimumFractionDigits: 0)
        body.text = "Send your entire BCash balance. You have \(amount.description) bCash"
        addressCell.paste.tap = strongify(self) { $0.pasteTapped() }
        addressCell.scan.tap = strongify(self) { $0.scanTapped() }
        send.tap = strongify(self) { $0.presentConfirm() }

        txHash.titleLabel?.font = .customBody(size: 13.0)
        txHash.titleLabel?.numberOfLines = 0
        txHash.titleLabel?.lineBreakMode = .byCharWrapping
        txHash.tintColor = .darkText
        txHash.contentHorizontalAlignment = .left
        txHash.tap = { [weak self] in
            self?.store.trigger(name: .lightWeightAlert("Tx Hash Copied"))
            UIPasteboard.general.string = self?.txHash.titleLabel?.text
        }
        setPreviousTx()
    }

    private func setPreviousTx() {
        if let previousHash = UserDefaults.standard.string(forKey: "bCashTxHashKey") {
            txHashHeader.text = "Bitcoin Cash Transaction ID"
            txHash.setTitle(previousHash, for: .normal)
        }
    }

    private func pasteTapped() {
        if let address = store.state.pasteboard {
            if address.isValidAddress {
                addressCell.setContent(address)
            } else {
                showError(title: S.Send.invalidAddressTitle, message: S.Send.invalidAddressMessage, buttonLabel: S.Button.ok)
            }
        }
    }

    private func scanTapped() {
        guard ScanViewController.isCameraAllowed else {
            guard ScanViewController.isCameraAllowed else {
                ScanViewController.presentCameraUnavailableAlert(fromRoot: self)
                return
            }
            return
        }
        let vc = ScanViewController(completion: { [weak self] paymentRequest in
            guard let myself = self else { return }
            myself.handlePaymentRequest(paymentRequest)
            myself.view.isFrameChangeBlocked = false
        }, isValidURI: { address in
            return address.isValidAddress
        })
        view.isFrameChangeBlocked = true
        present(vc, animated: true, completion: {})
    }

    private func handlePaymentRequest(_ request: PaymentRequest?) {
        guard let request = request else { return }
        guard request.type == .local else { return showErrorMessage("Payment Protocol Requests are not supported for BCash transactions") }
        addressCell.setContent(request.toAddress)
    }

    private func presentConfirm() {
        let amount = DisplayAmount(amount: Satoshis(rawValue: walletManager.bCashBalance), state: store.state, selectedRate: nil, minimumFractionDigits: 0)
        guard let address = addressCell.address else { return showErrorMessage("Please enter an address") }
        body.text = "Send your entire BCash balance. You have \(amount.description) bCash"
        let alert = UIAlertController(title: "Confirmation", message: "Confirm sending \(amount.description) to \(address)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: { _ in
            self.send(toAddress: address)
        }))
        present(alert, animated: true, completion: nil)
    }

    private func send(toAddress: String) {
        let verify = VerifyPinViewController(bodyText: "Authenticate this transaction", pinLength: walletManager.pinLength, callback: { [weak self] pin, vc in
                guard let myself = self else { return false }
                if myself.walletManager.authenticate(pin: pin) {
                    vc.dismiss(animated: true, completion: {
                        myself.walletManager.sweepBCash(toAddress: toAddress, pin: pin, callback: { errorMessage in
                            guard let errorMessage = errorMessage else {
                                return myself.showError(title: "BCash Sent", message: "BCash was successfull sent to \(toAddress)", buttonLabel: S.Button.ok)
                            }
                            myself.setPreviousTx()
                            return myself.showErrorMessage(errorMessage)
                        })
                    })
                    return true
                } else {
                    return false
                }
        })
        verify.transitioningDelegate = verifyPinTransitionDelegate
        verify.modalPresentationStyle = .overFullScreen
        verify.modalPresentationCapturesStatusBarAppearance = true
        present(verify, animated: true, completion: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
