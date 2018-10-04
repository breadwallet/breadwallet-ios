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
    private let button = ShadowButton(title: S.Button.ok, type: .primary)

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
        header.constrainTopCorners(height: 44.0)
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            titleLabel.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -C.padding[2]) ])

        body.constrain([
            body.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            body.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]),
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
        titleLabel.textAlignment = .center
        titleLabel.text = S.Welcome.title
        setBodyText()
        button.tap = strongify(self) { myself in
            myself.dismiss(animated: true, completion: nil)
        }
    }

    private func setBodyText() {
        let bodyText = S.Welcome.body
        let attributedString = NSMutableAttributedString(string: S.Welcome.body)
        let icon = NSTextAttachment()
        icon.image = #imageLiteral(resourceName: "Faq")
        icon.bounds = CGRect(x: 0, y: -3.0, width: body.font.pointSize, height: body.font.pointSize)
        let range = S.Welcome.body.range(of: "(?)")
        let nsRange = bodyText.nsRange(from: range!)
        attributedString.replaceCharacters(in: nsRange, with: NSAttributedString(attachment: icon))
        body.attributedText = attributedString
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

}
