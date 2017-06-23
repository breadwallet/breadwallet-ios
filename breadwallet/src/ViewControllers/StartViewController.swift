//
//  StartViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartViewController : UIViewController {

    //MARK: - Public
    init(store: Store, didTapCreate: @escaping () -> Void, didTapRecover: @escaping () -> Void) {
        self.store = store
        self.didTapRecover = didTapRecover
        self.didTapCreate = didTapCreate
        self.faq = UIButton.buildFaqButton(store: store, articleId: ArticleIds.startView)
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let message = UILabel(font: .customMedium(size: 18.0), color: .whiteTint)
    private let create = ShadowButton(title: S.StartViewController.createButton, type: .primary)
    private let recover = ShadowButton(title: S.StartViewController.recoverButton, type: .secondary)
    private let store: Store
    private let didTapRecover: () -> Void
    private let didTapCreate: () -> Void
    private let background = LoginBackgroundView()
    private var logo: UIImageView = {
        let image = UIImageView(image: #imageLiteral(resourceName: "Logo"))
        image.contentMode = .scaleAspectFit
        return image
    }()
    private var faq: UIButton

    override func viewDidLoad() {
        view.backgroundColor = .white
        setData()
        addSubviews()
        addConstraints()
        addButtonActions()
    }

    private func setData() {
        message.text = S.StartViewController.message
        message.lineBreakMode = .byWordWrapping
        message.numberOfLines = 0
        message.textAlignment = .center
        faq.tintColor = .whiteTint
    }

    private func addSubviews() {
        view.addSubview(background)
        view.addSubview(logo)
        view.addSubview(message)
        view.addSubview(create)
        view.addSubview(recover)
        view.addSubview(faq)
    }

    private func addConstraints() {
        background.constrain(toSuperviewEdges: nil)
        let yConstraint = NSLayoutConstraint(item: logo, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 0.5, constant: 0.0)
        logo.constrain([
            logo.constraint(.centerX, toView: view, constant: nil),
            yConstraint])
        message.constrain([
            message.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            message.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: C.padding[3]),
            message.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
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
        faq.constrain([
            faq.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2]),
            faq.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            faq.widthAnchor.constraint(equalToConstant: 44.0),
            faq.heightAnchor.constraint(equalToConstant: 44.0) ])
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
