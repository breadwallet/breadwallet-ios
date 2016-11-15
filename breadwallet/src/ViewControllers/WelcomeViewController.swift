//
//  WelcomeViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-14.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class WelcomeViewController: UIViewController {

    private let store: Store
    private let icon =      UILabel()
    private let header =    UILabel()
    private let subheader = UILabel()
    private let body =      UILabel.wrapping(font: UIFont.customBody(size: 16.0))
    private let newUser =   UIButton.primary(title: NSLocalizedString("New User", comment: "New user button title"))
    private let existing =  UIButton.secondary(title: NSLocalizedString("Existing User", comment: "Existing user button title"))

    var newUserTappedCallback: (() -> Void)?
    var existingUserTappedCallback: (() -> Void)?

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        setData()
        addSubviews()
        addConstraints()
        addButtonActions()
    }

    private func setData() {
        icon.text = "👋"
        icon.font = UIFont.customBold(size: 50.0)

        header.text = NSLocalizedString("Oh heeey!", comment: "Welcome screen header")
        header.font = UIFont.customBold(size: 26.0)

        subheader.text = NSLocalizedString("Welcome to the Bread redesign.", comment: "Welcome screen subheader")
        subheader.font = UIFont.customBold(size: 16.0)

        body.text = NSLocalizedString("The purpose of this prototype is to examen our colors, shadows, and selection states. Let’s GO!", comment: "Welcome screen body")
    }

    private func addSubviews () {
        view.addSubview(icon)
        view.addSubview(header)
        view.addSubview(subheader)
        view.addSubview(body)
        view.addSubview(existing)
        view.addSubview(newUser)
    }

    private func addConstraints() {
        icon.constrain([
                icon.constraint(.leading, toView: view, constant: Constants.Padding.double),
                icon.constraint(.top, toView: view, constant: Constants.Padding.quad*2)
            ])
        header.constrain([
                header.constraint(toBottom: icon, constant: Constants.Padding.single),
                header.constraint(.leading, toView: icon, constant: nil)
            ])
        subheader.constrain([
                subheader.constraint(toBottom: header, constant: Constants.Padding.double),
                subheader.constraint(.leading, toView: header, constant: nil)
            ])
        body.constrain([
                body.constraint(toBottom: subheader, constant: Constants.Padding.double),
                body.constraint(.leading, toView: subheader, constant: nil),
                body.constraint(.trailing, toView: view, constant: -Constants.Padding.double)
            ])
        existing.constrainBottomCorners(sidePadding: Constants.Padding.double, bottomPadding: Constants.Padding.double)
        existing.constrain([
                existing.constraint(.height, constant: Constants.Sizes.buttonHeight)
            ])
        newUser.constrain([
                newUser.constraint(.leading, toView: existing, constant: nil),
                newUser.constraint(.trailing, toView: existing, constant: nil),
                newUser.constraint(.height, constant: Constants.Sizes.buttonHeight),
                newUser.constraint(toTop: existing, constant: -Constants.Padding.double)
            ])
    }

    private func addButtonActions() {
        newUser.addTarget(self, action: #selector(newUserTapped), for: .touchUpInside)
        existing.addTarget(self, action: #selector(existingUserTapped), for: .touchUpInside)
    }

    @objc private func newUserTapped() {
        newUserTappedCallback?()
    }

    @objc private func existingUserTapped() {
        existingUserTappedCallback?()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
