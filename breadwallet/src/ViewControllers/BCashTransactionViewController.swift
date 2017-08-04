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

    init(walletManager: WalletManager) {
        self.walletManager = walletManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        send.tap = strongify(self) {
            $0.presentConfirm()
        }
    }

    private func setInitialData() {
        view.backgroundColor = .whiteTint
        titleLabel.text = "Withdraw Bitcoin Cash"
        body.text = "Send your total Bread balance to a BCash address. blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah"
    }

//    private func send() {
//
//    }

    private func presentConfirm() {
        let alert = UIAlertController(title: "Confirmation", message: "Confirm the transaction of $1.00 to sa8vm89we98jf3829mv?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: { _ in
            //self.send()
        }))
        present(alert, animated: true, completion: nil)
    }

}
