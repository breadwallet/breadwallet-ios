//
//  ManageWalletViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-11.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class ManageWalletViewController : UIViewController {

    private let textFieldLabel = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let textField = UITextField()
    private let separator = UIView(color: .secondaryShadow)
    fileprivate let body = UILabel.wrapping(font: .customBody(size: 13.0), color: .secondaryGrayText)

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        view.addSubview(textFieldLabel)
        view.addSubview(textField)
        view.addSubview(separator)
        view.addSubview(body)
    }

    private func addConstraints() {
        textFieldLabel.constrain([
            textFieldLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            textFieldLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[2]),
            textFieldLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        textField.constrain([
            textField.leadingAnchor.constraint(equalTo: textFieldLabel.leadingAnchor),
            textField.topAnchor.constraint(equalTo: textFieldLabel.bottomAnchor),
            textField.trailingAnchor.constraint(equalTo: textFieldLabel.trailingAnchor) ])
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            separator.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: C.padding[2]),
            separator.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: separator.leadingAnchor),
            body.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: separator.trailingAnchor) ])
    }

    private func setData() {
        view.backgroundColor = .white
        textField.textColor = .darkText
        textField.font = .customBody(size: 14.0)
        textFieldLabel.text = S.ManageWallet.textFieldLabel
        textField.text = "My Bread"
        body.text = "\(S.ManageWallet.description) February 21, 2014"
    }
}

extension ManageWalletViewController : ModalDisplayable {
    var modalTitle: String {
        return S.ManageWallet.title
    }

    var modalSize: CGSize {
        view.layoutIfNeeded()
        return CGSize(width: view.frame.width, height: body.frame.maxY + C.padding[4])
    }

    var isFaqHidden: Bool {
        return false
    }
}
