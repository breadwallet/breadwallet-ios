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
    init(store: Store, didTapRecover: @escaping () -> Void) {
        self.store = store
        self.didTapRecover = didTapRecover
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let circle = GradientCircle()
    private let brand = UILabel()
    private let create = ShadowButton(title: NSLocalizedString("Create New Wallet", comment: "button label"), type: .primary)
    private let recover = ShadowButton(title: NSLocalizedString("Recover Wallet", comment: "button label"), type: .secondary)
    private let store: Store
    private let didTapRecover: () -> Void

    override func viewDidLoad() {
        view.backgroundColor = .white
        setData()
        addSubviews()
        addConstraints()
        addButtonActions()
    }

    private func setData() {
        brand.text = "Bread"
        brand.font = UIFont.customBold(size: 26.0)
    }

    private func addSubviews() {
        view.addSubview(circle)
        view.addSubview(brand)
        view.addSubview(create)
        view.addSubview(recover)
    }

    private func addConstraints() {
        circle.constrain([
            circle.constraint(.centerX, toView: view, constant: nil),
            circle.constraint(.top, toView: view, constant: 120.0),
            circle.constraint(.width, constant: Circle.defaultSize),
            circle.constraint(.height, constant: Circle.defaultSize) ])
        brand.constrain([
            brand.constraint(.centerX, toView: circle, constant: nil),
            brand.constraint(toBottom: circle, constant: C.padding[1]) ])
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
    }

    private func addButtonActions() {
        recover.tap = didTapRecover
        create.tap = { [weak self] in
            self?.store.perform(action: PinCreation.Start())
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
