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
    private let actionButton = ShadowButton(title: S.Button.home, type: .primary)
    private let dismissButton = ShadowButton(title: S.Button.dismiss, type: .tertiary)
    private let supportButton = UIButton.buildFaqButton(articleId: "bitcoin-cash")

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
        contentBox.addSubview(actionButton)
        contentBox.addSubview(dismissButton)
        header.addSubview(supportButton)
    }

    private func addConstraints() {
        contentBox.constrain([
            contentBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentBox.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentBox.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[6] ) ])
        header.constrainTopCorners(height: 44.0)
        supportButton.constrain([
            supportButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            supportButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            supportButton.heightAnchor.constraint(equalToConstant: 44.0),
            supportButton.widthAnchor.constraint(equalToConstant: 44.0) ])
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            titleLabel.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])

        body.constrain([
            body.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            body.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])

        dismissButton.constrain([
            dismissButton.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            dismissButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            dismissButton.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -C.padding[2]),
            dismissButton.widthAnchor.constraint(equalTo: actionButton.widthAnchor)
            ])
        
        actionButton.constrain([
            actionButton.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: C.padding[2]),
            actionButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            actionButton.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            actionButton.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -C.padding[2]) ])
    }

    private func setInitialData() {
        view.backgroundColor = .clear
        contentBox.layer.cornerRadius = 6.0
        contentBox.layer.masksToBounds = true
        supportButton.tintColor = .white
        titleLabel.text = S.Welcome.title
        body.text = S.Welcome.body
        dismissButton.tap = { [unowned self] in
            self.dismiss(animated: true, completion: nil)
        }
        actionButton.tap = { [unowned self] in
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
