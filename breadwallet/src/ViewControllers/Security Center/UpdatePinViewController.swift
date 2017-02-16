//
//  UpdatePinViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class UpdatePinViewController : UIViewController {

    //MARK: - Public
    init(store: Store, walletManager: WalletManager) {
        self.store = store
        self.walletManager = walletManager
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let header = UILabel.wrapping(font: .customBold(size: 26.0), color: .darkText)
    private let instruction = UILabel.wrapping(font: .customBody(size: 14.0), color: .darkText)
    private let caption = UILabel.wrapping(font: .customBody(size: 13.0), color: .secondaryGrayText)
    private let pinView = PinView(style: .create)
    private let pinPad = PinPadViewController(style: .white, keyboardType: .pinPad)
    private let store: Store
    private let walletManager: WalletManager

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(instruction)
        view.addSubview(caption)
        view.addSubview(pinView)
    }

    private func addConstraints() {
        header.constrain([
            header.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2]),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        instruction.constrain([
            instruction.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            instruction.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            instruction.trailingAnchor.constraint(equalTo: header.trailingAnchor) ])
        pinView.constrain([
            pinView.topAnchor.constraint(equalTo: instruction.bottomAnchor, constant: C.padding[6]),
            pinView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])

        addChildViewController(pinPad, layout: {
            pinPad.view.constrainBottomCorners(sidePadding: 0.0, bottomPadding: 0.0)
            pinPad.view.constrain([pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height) ])
        })

        caption.constrain([
            caption.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            caption.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[2]),
            caption.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
    }

    private func setData() {
        view.backgroundColor = .white

        header.text = S.UpdatePin.title
        instruction.text = S.UpdatePin.enterCurrent
        caption.text = S.UpdatePin.caption
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
