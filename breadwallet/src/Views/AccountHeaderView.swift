//
//  AccountHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AccountHeaderView : UIView, GradientDrawable, Subscriber {

    //MARK: - Public
    var balance: UInt64 = 0 {
        didSet { setBalances() }
    }

    var currency: Currency = .bitcoin {
        didSet { setBalances() }
    }

    init(store: Store) {
        self.store = store
        super.init(frame: CGRect())
        setup()
    }

    //MARK: - Private
    private let name = UILabel(font: UIFont.boldSystemFont(ofSize: 17.0))
    private let manage = UIButton(type: .system)
    private let primaryBalance = UpdatingLabel(formatter: Amount.btcFormat)
    private let secondaryBalance = UpdatingLabel(formatter: Amount.localFormat)
    private let search = UIButton(type: .system)
    private let currencyTapView = UIView()
    private let store: Store
    private let equals = UILabel(font: .customBody(size: 13.0), color: .darkText)
    private var regularConstraints: [NSLayoutConstraint] = []
    private var swappedConstraints: [NSLayoutConstraint] = []
    private var exchangeRate: Rate? {
        didSet { setBalances() }
    }

    private func setup() {
        setData()
        addSubviews()
        addConstraints()
        addShadow()
        addSubscriptions()
    }

    private func setData() {
        store.subscribe(self, selector: { $0.walletState.name != $1.walletState.name }, callback: {
            self.name.text = $0.walletState.name
        })
        name.textColor = .white

        manage.setTitle(S.AccountHeader.manageButtonName, for: .normal)
        manage.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17.0)
        manage.tintColor = .white
        manage.tap = {
            self.store.perform(action: RootModalActions.Present(modal: .manageWallet))
        }
        primaryBalance.textColor = .white
        primaryBalance.font = UIFont.customBody(size: 26.0)

        secondaryBalance.textColor = .darkText
        secondaryBalance.font = UIFont.customBody(size: 13.0)

        search.setImage(#imageLiteral(resourceName: "SearchIcon"), for: .normal)
        search.tintColor = .white

        if isTestnet {
            name.textColor = .red
        }

        equals.text = S.AccountHeader.equals
    }

    private func addSubviews() {
        addSubview(name)
        addSubview(manage)
        addSubview(primaryBalance)
        addSubview(secondaryBalance)
        addSubview(search)
        addSubview(currencyTapView)
        addSubview(equals)
    }

    private func addConstraints() {
        name.constrain([
            name.constraint(.leading, toView: self, constant: C.padding[2]),
            name.constraint(.top, toView: self, constant: 30.0) ])
        if let manageTitleLabel = manage.titleLabel {
            manage.constrain([
                manage.constraint(.trailing, toView: self, constant: -C.padding[2]),
                manageTitleLabel.firstBaselineAnchor.constraint(equalTo: name.firstBaselineAnchor)
                ])
        }
        secondaryBalance.constrain([
            secondaryBalance.constraint(.firstBaseline, toView: primaryBalance, constant: 0.0) ])

        equals.translatesAutoresizingMaskIntoConstraints = false
        primaryBalance.translatesAutoresizingMaskIntoConstraints = false

        regularConstraints = [
            primaryBalance.firstBaselineAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[4]),
            primaryBalance.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            equals.firstBaselineAnchor.constraint(equalTo: primaryBalance.firstBaselineAnchor),
            equals.leadingAnchor.constraint(equalTo: primaryBalance.trailingAnchor, constant: C.padding[1]/2.0),
            secondaryBalance.leadingAnchor.constraint(equalTo: equals.trailingAnchor, constant: C.padding[1]/2.0)
        ]

        NSLayoutConstraint.activate(regularConstraints)

        swappedConstraints = [
            secondaryBalance.firstBaselineAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[4]),
            secondaryBalance.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            equals.firstBaselineAnchor.constraint(equalTo: secondaryBalance.firstBaselineAnchor),
            equals.leadingAnchor.constraint(equalTo: secondaryBalance.trailingAnchor, constant: C.padding[1]/2.0),
            primaryBalance.leadingAnchor.constraint(equalTo: equals.trailingAnchor, constant: C.padding[1]/2.0)
        ]

        search.constrain([
            search.constraint(.trailing, toView: self, constant: -C.padding[2]),
            search.topAnchor.constraint(equalTo: manage.bottomAnchor, constant: C.padding[1]),
            search.constraint(.width, constant: 24.0),
            search.constraint(.height, constant: 24.0) ])

        currencyTapView.constrain([
            currencyTapView.leadingAnchor.constraint(equalTo: name.leadingAnchor, constant: -C.padding[1]),
            currencyTapView.trailingAnchor.constraint(equalTo: manage.leadingAnchor, constant: C.padding[1]),
            currencyTapView.topAnchor.constraint(equalTo: primaryBalance.topAnchor, constant: -C.padding[1]),
            currencyTapView.bottomAnchor.constraint(equalTo: primaryBalance.bottomAnchor, constant: C.padding[1]) ])

        let gr = UITapGestureRecognizer(target: self, action: #selector(currencySwitchTapped))
        currencyTapView.addGestureRecognizer(gr)
    }

    private func addShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 8.0
    }

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.currency != $1.currency },
                        callback: { self.currency = $0.currency })
        store.subscribe(self,
                        selector: { $0.currentRate != $1.currentRate},
                        callback: { self.exchangeRate = $0.currentRate })
    }

    private func setBalances() {
        guard let rate = exchangeRate else { return }
        let amount = Amount(amount: balance, rate: rate.rate)

        primaryBalance.setValue(amount.bitsAmount)
        secondaryBalance.setValue(amount.localAmount)
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }

    @objc private func currencySwitchTapped() {
        layoutIfNeeded()
        let willSwap = currency == .bitcoin
        //TODO - add font animation with CATextLayer
        self.primaryBalance.textColor = willSwap ? .darkText : .white
        self.secondaryBalance.textColor = willSwap ? .white : .darkText
        UIView.spring(C.animationDuration, animations: {
            NSLayoutConstraint.deactivate(willSwap ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(willSwap ? self.swappedConstraints : self.regularConstraints)
            self.layoutIfNeeded()
        }) { _ in
        }

        self.store.perform(action: CurrencyChange.toggle())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
