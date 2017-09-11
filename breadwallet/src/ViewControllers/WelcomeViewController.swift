//
//  WelcomeViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-09-10.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class WelcomeViewController : UIViewController, ContentBoxPresenter {

    let blurView = UIVisualEffectView()
    let effect = UIBlurEffect(style: .dark)
    let contentBox = UIView(color: .white)

    private let header = GradientView()
    private let titleLabel = UILabel.wrapping(font: .customBody(size: 26.0), color: .darkText)
    private let body = UILabel.wrapping(font: .customBody(size: 16.0), color: .darkText)
    private let button = ShadowButton(title: "OK", type: .primary)

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(contentBox)
        contentBox.addSubview(header)
        contentBox.addSubview(titleLabel)
        contentBox.addSubview(body)
        contentBox.addSubview(button)
    }

    private func addConstraints() {
        contentBox.constrain([
            contentBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentBox.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentBox.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[6] ) ])
        header.constrainTopCorners(height: 8.0)
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            titleLabel.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])

        body.constrain([
            body.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            body.topAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            body.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])

        button.constrain([
            button.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            button.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            button.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -C.padding[2]) ])
    }

    private func setInitialData() {
        view.backgroundColor = .clear
        contentBox.layer.cornerRadius = 6.0
        contentBox.layer.masksToBounds = true

        titleLabel.text = "Welcome to the new Bread"
        body.text = "•Narwhal ut activated charcoal bespoke, copper mug hell of kogi shoreditch lomo consectetur you probably haven't heard of them post-ironic.\n\n•Live-edge esse la croix photo booth, williamsburg raw denim YOLO laborum.\n\n•Poke gluten-free schlitz tofu et quinoa iceland fugiat trust fund typewriter tbh non 90's.\n\n•Man bun vice ad, beard selvage dreamcatcher tattooed ethical typewriter excepteur est in."
        button.tap = strongify(self) { myself in
            myself.dismiss(animated: true, completion: nil)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

}
