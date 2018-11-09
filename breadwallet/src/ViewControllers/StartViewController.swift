//
//  StartViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartViewController: UIViewController {

    // MARK: - Public
    init(didTapCreate: @escaping () -> Void, didTapRecover: @escaping () -> Void) {
        self.didTapRecover = didTapRecover
        self.didTapCreate = didTapCreate
        super.init(nibName: nil, bundle: nil)
    }

    // MARK: - Private
    private let logoBackground = MotionGradientView()
    private let messageBackground = MotionGradientView()
    private let message = CutoutLabel(font: .customMedium(size: 18.0), color: .whiteTint)
    private let create = BRDButton(title: S.StartViewController.createButton, type: .primary)
    private let recover = BRDButton(title: S.StartViewController.recoverButton, type: .secondaryTransparent)
    private let didTapRecover: () -> Void
    private let didTapCreate: () -> Void
    private let background = UIView()
    private var logo = UIImageView(image: #imageLiteral(resourceName: "LogoCutout").withRenderingMode(.alwaysTemplate))
    private let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.startView)
    
    override func viewDidLoad() {
        view.backgroundColor = .darkBackground
        setData()
        addSubviews()
        addConstraints()
        addButtonActions()
        logo.tintColor = .darkBackground
    }

    private func setData() {
        message.text = S.StartViewController.message
        message.lineBreakMode = .byWordWrapping
        message.numberOfLines = 0
        message.textAlignment = .center
        faqButton.tintColor = .navigationTint
    }

    private func addSubviews() {
        view.addSubview(background)
        view.addSubview(logoBackground)
        logoBackground.addSubview(logo)
        view.addSubview(messageBackground)
        messageBackground.addSubview(message)
        view.addSubview(create)
        view.addSubview(recover)
        view.addSubview(faqButton)
    }

    private func addConstraints() {
        background.constrain(toSuperviewEdges: nil)
        let yConstraint = NSLayoutConstraint(item: logoBackground,
                                             attribute: .centerY,
                                             relatedBy: .equal,
                                             toItem: view,
                                             attribute: .centerY,
                                             multiplier: 0.5,
                                             constant: 0.0)
        logoBackground.constrain([
            logoBackground.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.38, constant: 1.0),
            logoBackground.heightAnchor.constraint(equalTo: logoBackground.widthAnchor, multiplier: logo.image!.size.height/logo.image!.size.width, constant: 1.0),
            logoBackground.constraint(.centerX, toView: view, constant: nil),
            yConstraint])
        logo.constrain(toSuperviewEdges: nil)
        messageBackground.constrain([
            messageBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            messageBackground.topAnchor.constraint(equalTo: logoBackground.bottomAnchor, constant: C.padding[1]),
            messageBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        message.constrain(toSuperviewEdges: nil)
        recover.constrain([
            recover.constraint(.leading, toView: view, constant: C.padding[2]),
            recover.constraint(.bottom, toView: view, constant: -C.padding[3]),
            recover.constraint(.trailing, toView: view, constant: -C.padding[2]),
            recover.constraint(.height, constant: C.Sizes.buttonHeight) ])
        create.constrain([
            create.constraint(toTop: recover, constant: -C.padding[2]),
            create.constraint(.centerX, toView: recover, constant: nil),
            create.constraint(.width, toView: recover, constant: nil),
            create.constraint(.height, constant: C.Sizes.buttonHeight) ])
        faqButton.constrain([
            faqButton.topAnchor.constraint(equalTo: safeTopAnchor, constant: C.padding[2]),
            faqButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            faqButton.widthAnchor.constraint(equalToConstant: 44.0),
            faqButton.heightAnchor.constraint(equalToConstant: 44.0)
            ])
    }

    private func addButtonActions() {
        recover.tap = didTapRecover
        create.tap = didTapCreate
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
