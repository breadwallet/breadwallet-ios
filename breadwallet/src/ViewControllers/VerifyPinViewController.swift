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

    init(bodyText: String, callback: @escaping VerifyPinCallback) {
        self.bodyText = bodyText
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }

    let blurView = UIVisualEffectView()
    let effect = UIBlurEffect(style: .dark)
    let contentBox = UIView()
    private let callback: VerifyPinCallback
    private let pinPad = PinPadViewController(style: .white, keyboardType: .pinPad)
    private let titleLabel = UILabel(font: .customBold(size: 17.0), color: .darkText)
    private let body = UILabel(font: .customBody(size: 14.0), color: .darkText)
    private let pinView = PinView(style: .create, length: 6)
    private let toolbar = UIView(color: .whiteTint)
    private let cancel = UIButton(type: .system)
    private let bodyText: String

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setupSubviews()
    }

    private func addSubviews() {
        view.addSubview(contentBox)
        view.addSubview(toolbar)
        toolbar.addSubview(cancel)

        contentBox.addSubview(titleLabel)
        contentBox.addSubview(body)
        contentBox.addSubview(pinView)
        addChildViewController(pinPad, layout: {
            pinPad.view.constrain([
                pinPad.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                pinPad.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                pinPad.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                pinPad.view.heightAnchor.constraint(equalToConstant: pinPad.height) ])
        })
    }

    private func addConstraints() {
        contentBox.constrain([
            contentBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentBox.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor, constant: -C.padding[12]),
            contentBox.widthAnchor.constraint(equalToConstant: 256.0),
            contentBox.heightAnchor.constraint(equalToConstant: 148.0) ])
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
        toolbar.constrain([
            toolbar.leadingAnchor.constraint(equalTo: pinPad.view.leadingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: pinPad.view.topAnchor),
            toolbar.trailingAnchor.constraint(equalTo: pinPad.view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44.0) ])
        cancel.constrain([
            cancel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            cancel.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -C.padding[2]) ])
    }

    private func setupSubviews() {
        contentBox.backgroundColor = .white
        contentBox.layer.cornerRadius = 8.0
        contentBox.layer.borderWidth = 1.0
        contentBox.layer.borderColor = UIColor.secondaryShadow.cgColor
        contentBox.layer.shadowColor = UIColor.black.cgColor
        contentBox.layer.shadowOpacity = 0.15
        contentBox.layer.shadowRadius = 4.0
        contentBox.layer.shadowOffset = .zero

        titleLabel.text = S.VerifyPin.title
        body.text = bodyText
        body.numberOfLines = 0
        body.lineBreakMode = .byWordWrapping

        pinPad.ouputDidUpdate = { output in
            self.pinView.fill(output.utf8.count)
            if output.utf8.count == 6 {
                self.callback(output, self)
            }
        }
        cancel.tap = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
        cancel.setTitle(S.Button.cancel, for: .normal)
        view.backgroundColor = .clear
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
