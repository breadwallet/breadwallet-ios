//
//  AccountHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let largeFontSize: CGFloat = 26.0
private let smallFontSize: CGFloat = 13.0
private let logoWidth: CGFloat = 0.22 //percentage of width

class AccountHeaderView : UIView, GradientDrawable, Subscriber {

    //MARK: - Public
    init(store: Store) {
        self.store = store
        self.isBtcSwapped = store.state.isBtcSwapped
        super.init(frame: CGRect())
        setup()
    }

    let search = UIButton(type: .system)

    //MARK: - Private
    private let name = UILabel(font: UIFont.boldSystemFont(ofSize: 17.0))
    private let manage = UIButton(type: .system)
    private let primaryBalance = UpdatingLabel(formatter: Amount.btcFormat)
    private let secondaryBalance = UpdatingLabel(formatter: Amount.localFormat)
    private let currencyTapView = UIView()
    private let store: Store
    private let equals = UILabel(font: .customBody(size: smallFontSize), color: .darkText)
    private var regularConstraints: [NSLayoutConstraint] = []
    private var swappedConstraints: [NSLayoutConstraint] = []
    private var hasInitialized = false
    private var exchangeRate: Rate? {
        didSet { setBalances() }
    }
    private var logo: UIImageView = {
        let image = UIImageView(image: #imageLiteral(resourceName: "Logo"))
        image.contentMode = .scaleAspectFit
        return image
    }()
    private var balance: UInt64 = 0 {
        didSet { setBalances() }
    }
    private var isBtcSwapped: Bool {
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
        name.textColor = .white

        manage.setTitle(S.AccountHeader.manageButtonName, for: .normal)
        manage.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17.0)
        manage.tintColor = .white
        manage.tap = {
            self.store.perform(action: RootModalActions.Present(modal: .manageWallet))
        }
        primaryBalance.textColor = .white
        primaryBalance.font = UIFont.customBody(size: largeFontSize)

        secondaryBalance.textColor = .darkText
        secondaryBalance.font = UIFont.customBody(size: largeFontSize)

        search.setImage(#imageLiteral(resourceName: "SearchIcon"), for: .normal)
        search.tintColor = .white

        if isTestnet {
            name.textColor = .red
        }

        equals.text = S.AccountHeader.equals

        manage.isHidden = true
        name.isHidden = true
    }

    private func addSubviews() {
        addSubview(name)
        addSubview(manage)
        addSubview(primaryBalance)
        addSubview(secondaryBalance)
        addSubview(search)
        addSubview(currencyTapView)
        addSubview(equals)
        addSubview(logo)
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
            search.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[4]),
            search.constraint(.width, constant: 24.0),
            search.constraint(.height, constant: 24.0) ])

        currencyTapView.constrain([
            currencyTapView.leadingAnchor.constraint(equalTo: name.leadingAnchor, constant: -C.padding[1]),
            currencyTapView.trailingAnchor.constraint(equalTo: manage.leadingAnchor, constant: C.padding[1]),
            currencyTapView.topAnchor.constraint(equalTo: primaryBalance.topAnchor, constant: -C.padding[1]),
            currencyTapView.bottomAnchor.constraint(equalTo: primaryBalance.bottomAnchor, constant: C.padding[1]) ])

        let gr = UITapGestureRecognizer(target: self, action: #selector(currencySwitchTapped))
        currencyTapView.addGestureRecognizer(gr)

        logo.constrain([
            logo.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            logo.topAnchor.constraint(equalTo: topAnchor, constant: 30.0),
            logo.heightAnchor.constraint(equalTo: logo.widthAnchor, multiplier: C.Sizes.logoAspectRatio),
            logo.widthAnchor.constraint(equalTo: widthAnchor, multiplier: logoWidth) ])
    }

    private func transform(forView: UIView) ->  CGAffineTransform {
        let scaleFactor: CGFloat = smallFontSize/largeFontSize
        let deltaX = forView.frame.width * (1-scaleFactor)
        let deltaY = forView.frame.height * (1-scaleFactor)
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        return scale.translatedBy(x: -deltaX, y: deltaY/2.0)
    }

    private func addShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 8.0
    }

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.isBtcSwapped != $1.isBtcSwapped },
                        callback: { self.isBtcSwapped = $0.isBtcSwapped })
        store.subscribe(self,
                        selector: { $0.currentRate != $1.currentRate},
                        callback: { self.exchangeRate = $0.currentRate })
        store.subscribe(self,
                        selector: { $0.walletState.name != $1.walletState.name },
                        callback: { self.name.text = $0.walletState.name })
        store.subscribe(self,
                        selector: {$0.walletState.balance != $1.walletState.balance },
                        callback: { state in
                            self.balance = state.walletState.balance })
    }

    private func setBalances() {
        guard let rate = exchangeRate else { return }
        let amount = Amount(amount: balance, rate: rate)

        primaryBalance.setValue(amount.bitsAmount, completion: { [weak self] in
            guard let myself = self else { return }
            myself.layoutIfNeeded()
            if !myself.isBtcSwapped {
                myself.primaryBalance.transform = .identity
            } else {
                if myself.primaryBalance.transform == .identity {
                    myself.primaryBalance.transform = myself.transform(forView: myself.primaryBalance)
                }
            }
        })
        secondaryBalance.setValue(amount.localAmount, completion: { [weak self] in
            guard let myself = self else { return }
            myself.layoutIfNeeded()
            if myself.isBtcSwapped {
                myself.secondaryBalance.transform = .identity
            } else {
                if myself.secondaryBalance.transform == .identity {
                    myself.secondaryBalance.transform = myself.transform(forView: myself.secondaryBalance)
                }
            }
        })

        if !hasInitialized {
            NSLayoutConstraint.deactivate(isBtcSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(isBtcSwapped ? self.swappedConstraints : self.regularConstraints)
            self.primaryBalance.textColor = isBtcSwapped ? .darkText : .white
            self.secondaryBalance.textColor = isBtcSwapped ? .white : .darkText
            layoutIfNeeded()
            hasInitialized = true
        }
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }

    @objc private func currencySwitchTapped() {
        layoutIfNeeded()
        self.primaryBalance.textColor = !isBtcSwapped ? .darkText : .white
        self.secondaryBalance.textColor = !isBtcSwapped ? .white : .darkText
        UIView.spring(0.7, animations: {
            self.primaryBalance.transform = self.primaryBalance.transform.isIdentity ? self.transform(forView: self.primaryBalance) : .identity
            self.secondaryBalance.transform = self.secondaryBalance.transform.isIdentity ? self.transform(forView: self.secondaryBalance) : .identity
            NSLayoutConstraint.deactivate(!self.isBtcSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(!self.isBtcSwapped ? self.swappedConstraints : self.regularConstraints)
            self.layoutIfNeeded()
        }) { _ in
        }

        self.store.perform(action: CurrencyChange.toggle())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
