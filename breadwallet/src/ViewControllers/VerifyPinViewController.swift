//
//  VerifyPinViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

typealias VerifyPinCallback = (String, UIViewController) -> Void

class VerifyPinViewController : UIViewController {

    init(callback: @escaping VerifyPinCallback) {
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }

    private let callback: VerifyPinCallback
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let box = UIView()
    private let pinPad = PinPadViewController(style: .white, keyboardType: .pinPad)
    private let titleLabel = UILabel(font: .customBold(size: 17.0), color: .darkText)
    private let body = UILabel(font: .customBody(size: 14.0), color: .darkText)
    private let pinView = PinView(style: .create, length: 6)

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setupSubviews()
    }

    private func addSubviews() {
        view.addSubview(blurView)
        view.addSubview(box)
        box.addSubview(titleLabel)
        box.addSubview(body)
        box.addSubview(pinView)
        addChildViewController(pinPad, layout: {
            pinPad.view.constrain([
                pinPad.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                pinPad.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                pinPad.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height) ])
        })
    }

    private func addConstraints() {
        blurView.constrain(toSuperviewEdges: nil)
        box.constrain([
            box.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            box.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[12]),
            box.widthAnchor.constraint(equalToConstant: 256.0),
            box.heightAnchor.constraint(equalToConstant: 148.0) ])
        titleLabel.constrainTopCorners(sidePadding: C.padding[2], topPadding: C.padding[2])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            body.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            body.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor) ])
        pinView.constrain([
            pinView.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            pinView.centerXAnchor.constraint(equalTo: body.centerXAnchor),
            pinView.widthAnchor.constraint(equalToConstant: pinView.width),
            pinView.heightAnchor.constraint(equalToConstant: pinView.itemSize) ])
    }

    private func setupSubviews() {
        box.backgroundColor = .white
        box.layer.cornerRadius = 8.0
        box.layer.borderWidth = 1.0
        box.layer.borderColor = UIColor.secondaryShadow.cgColor
        box.layer.shadowColor = UIColor.black.cgColor
        box.layer.shadowOpacity = 0.15
        box.layer.shadowRadius = 4.0
        box.layer.shadowOffset = .zero

        titleLabel.text = S.VerifyPin.title
        body.text = S.VerifyPin.body
        body.numberOfLines = 0
        body.lineBreakMode = .byWordWrapping

        pinPad.ouputDidUpdate = { output in
            self.pinView.fill(output.utf8.count)
            if output.utf8.count == 6 {
                self.callback(output, self)
            }
        }

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
