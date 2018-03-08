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
    private let titleLabel = UILabel.wrapping(font: .customBold(size: 16.0), color: .darkText)
    private let body = UILabel.wrapping(font: .customBody(size: 16.0), color: .darkText)
    private let buttonAction = ShadowButton(title: S.Button.home, type: .primary)
    private let buttonDismiss = ShadowButton(title: S.Button.dismiss, type: .tertiary)

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
        contentBox.addSubview(buttonAction)
        contentBox.addSubview(buttonDismiss)
    }

    private func addConstraints() {
        contentBox.constrain([
            contentBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentBox.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentBox.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[6] ) ])
        header.constrainTopCorners(height: 44.0)
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            titleLabel.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])

        body.constrain([
            body.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            body.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])

        buttonDismiss.constrain([
            buttonDismiss.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            buttonDismiss.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            buttonDismiss.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -C.padding[2]),
            buttonDismiss.widthAnchor.constraint(equalTo: buttonAction.widthAnchor)
            ])
        
        buttonAction.constrain([
            buttonAction.leadingAnchor.constraint(equalTo: buttonDismiss.trailingAnchor, constant: C.padding[2]),
            buttonAction.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            buttonAction.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            buttonAction.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -C.padding[2]) ])
    }

    private func setInitialData() {
        view.backgroundColor = .clear
        contentBox.layer.cornerRadius = 6.0
        contentBox.layer.masksToBounds = true
        titleLabel.text = S.Welcome.title
        body.text = S.Welcome.body
        buttonDismiss.tap = { [unowned self] in
            self.dismiss(animated: true, completion: nil)
        }
        buttonAction.tap = { [unowned self] in
            let nc = self.presentingViewController as? RootNavigationController
            self.dismiss(animated: true, completion: {
                nc?.popToRootViewController(animated: true)
            })
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

}
