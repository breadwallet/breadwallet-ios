//
//  AccountHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let largeFontSize: CGFloat = 28.0
private let smallFontSize: CGFloat = 13.0

class AccountHeaderView : UIView, GradientDrawable, Subscriber {

    //MARK: - Public
    init(store: Store) {
        self.store = store
        self.isLtcSwapped = store.state.isLtcSwapped
        if let rate = store.state.currentRate {
            self.exchangeRate = rate
            let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: store.state.maxDigits)
            let oneLTCPlaceholder = Amount(amount: 1000000, rate: rate, maxDigits: store.state.maxDigits)
            self.currentLTCValueLabel = UpdatingLabel(formatter: oneLTCPlaceholder.localFormat)
            self.secondaryBalance = UpdatingLabel(formatter: placeholderAmount.localFormat)
            self.primaryBalance = UpdatingLabel(formatter: placeholderAmount.ltcFormat)
        } else {
            self.secondaryBalance = UpdatingLabel(formatter: NumberFormatter())
            self.primaryBalance = UpdatingLabel(formatter: NumberFormatter())
            self.currentLTCValueLabel = UpdatingLabel(formatter: NumberFormatter())
        }
        super.init(frame: CGRect())
    }

    let search = UIButton(type: .system)

    //MARK: - Private
    private let name = UILabel(font: UIFont.boldSystemFont(ofSize: 17.0))
    private let manage = UIButton(type: .system)
    private let primaryBalance: UpdatingLabel
    private let secondaryBalance: UpdatingLabel
    private let currentLTCValueLabel: UpdatingLabel

    private let currencyTapView = UIView()
    private let priceTapView = UIView()
    private let store: Store
    private let equals = UILabel(font: .customBody(size: smallFontSize), color: .whiteTint)
    private var regularConstraints: [NSLayoutConstraint] = []
    private var swappedConstraints: [NSLayoutConstraint] = []
    private var hasInitialized = false
    private let modeLabel: UILabel = {
        let label = UILabel()
        label.font = .customBody(size: 12.0)
        return label
    }()
    var hasSetup = false

    var isWatchOnly: Bool = false {
        didSet {
            if E.isTestnet || isWatchOnly {
                if E.isTestnet && isWatchOnly {
                    modeLabel.text = "(Testnet - Watch Only)"
                } else if E.isTestnet {
                    modeLabel.text = "(Testnet)"
                } else if isWatchOnly {
                    modeLabel.text = "(Watch Only)"
                }
                modeLabel.isHidden = false
            }
            if E.isScreenshots {
                modeLabel.isHidden = true
            }
        }
    }
    private var exchangeRate: Rate? {
        didSet { setBalances() }
    }
    private var balance: UInt64 = 0 {
        didSet { setBalances() }
    }
    private var isLtcSwapped: Bool {
        didSet { setBalances() }
    }

    override func layoutSubviews() {
        guard !hasSetup else { return }
        setup()
        hasSetup = true
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
        primaryBalance.textColor = .whiteTint
        primaryBalance.font = UIFont.customBold(size: largeFontSize)
 
        secondaryBalance.textColor = .whiteTint
        secondaryBalance.font = UIFont.customBold(size: largeFontSize)
      
        currentLTCValueLabel.textColor = UIColor.init(red: 1, green: 1, blue: 1, alpha: 0.5)
        currentLTCValueLabel.font = UIFont.customBold(size: largeFontSize)
      
        search.setImage(#imageLiteral(resourceName: "SearchIcon"), for: .normal)
        search.tintColor = .white

        if E.isTestnet {
            name.textColor = .red
        }

        equals.text = S.AccountHeader.equals

        manage.isHidden = true
        name.isHidden = true
        modeLabel.isHidden = true
    }

    private func addSubviews() {
        addSubview(name)
        addSubview(manage)
        addSubview(primaryBalance)
        addSubview(secondaryBalance)
        addSubview(currentLTCValueLabel)
        addSubview(search)
        addSubview(currencyTapView)
        addSubview(priceTapView)
        addSubview(equals)
        addSubview(modeLabel)
    }

    private func addConstraints() {
        name.constrain([
            name.constraint(.leading, toView: self, constant: C.padding[2]),
            name.constraint(.top, toView: self, constant: 30.0) ])
        if let manageTitleLabel = manage.titleLabel {
            manage.constrain([
                manage.constraint(.trailing, toView: self, constant: -C.padding[2]),
                manageTitleLabel.firstBaselineAnchor.constraint(equalTo: name.firstBaselineAnchor) ])
        }
        secondaryBalance.constrain([
            secondaryBalance.constraint(.firstBaseline, toView: primaryBalance, constant: 0.0) ])

        equals.translatesAutoresizingMaskIntoConstraints = false
        primaryBalance.translatesAutoresizingMaskIntoConstraints = false

        currentLTCValueLabel.constrain([
        currentLTCValueLabel.constraint(.firstBaseline, toView: primaryBalance, constant: 0.0),
        currentLTCValueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]-10),
        ])
      
        regularConstraints = [
            primaryBalance.firstBaselineAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[2]),
            primaryBalance.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            equals.firstBaselineAnchor.constraint(equalTo: primaryBalance.firstBaselineAnchor),
            equals.leadingAnchor.constraint(equalTo: primaryBalance.trailingAnchor, constant: C.padding[1]/2.0),
            secondaryBalance.leadingAnchor.constraint(equalTo: equals.trailingAnchor, constant: C.padding[1]/2.0)
        ]

        swappedConstraints = [
            secondaryBalance.firstBaselineAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[2]),
            secondaryBalance.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            equals.firstBaselineAnchor.constraint(equalTo: secondaryBalance.firstBaselineAnchor),
            equals.leadingAnchor.constraint(equalTo: secondaryBalance.trailingAnchor, constant: C.padding[1]/2.0),
            primaryBalance.leadingAnchor.constraint(equalTo: equals.trailingAnchor, constant: C.padding[1]/2.0)
        ]

        NSLayoutConstraint.activate(isLtcSwapped ? self.swappedConstraints : self.regularConstraints)

        search.constrain([
            search.constraint(.trailing, toView: self, constant: -C.padding[2]),
            search.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            search.constraint(.width, constant: 40.0),
            search.constraint(.height, constant: 40.0) ])
            search.imageEdgeInsets = UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0)

        currencyTapView.constrain([
            currencyTapView.leadingAnchor.constraint(equalTo: name.leadingAnchor, constant: -C.padding[1]),
            currencyTapView.trailingAnchor.constraint(equalTo: manage.leadingAnchor, constant: C.padding[1]),
            currencyTapView.topAnchor.constraint(equalTo: primaryBalance.topAnchor, constant: -C.padding[1]),
            currencyTapView.bottomAnchor.constraint(equalTo: primaryBalance.bottomAnchor, constant: C.padding[1]) ])

        let gr = UITapGestureRecognizer(target: self, action: #selector(currencySwitchTapped))
        currencyTapView.addGestureRecognizer(gr)
    }

    private func transform(forView: UIView) ->  CGAffineTransform {
        forView.transform = .identity //Must reset the view's transform before we calculate the next transform
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
        store.lazySubscribe(self,
                        selector: { $0.isLtcSwapped != $1.isLtcSwapped },
                        callback: { self.isLtcSwapped = $0.isLtcSwapped })
        store.lazySubscribe(self,
                        selector: { $0.currentRate != $1.currentRate},
                        callback: {
                            if let rate = $0.currentRate {
                                let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: $0.maxDigits)
                                self.secondaryBalance.formatter = placeholderAmount.localFormat
                                self.primaryBalance.formatter = placeholderAmount.ltcFormat
                            }
                            self.exchangeRate = $0.currentRate
                        })

        store.lazySubscribe(self,
                        selector: { $0.maxDigits != $1.maxDigits},
                        callback: {
                            if let rate = $0.currentRate {
                                let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: $0.maxDigits)
                                self.secondaryBalance.formatter = placeholderAmount.localFormat
                                self.primaryBalance.formatter = placeholderAmount.ltcFormat
                                self.setBalances()
                            }
        })
        store.subscribe(self,
                        selector: { $0.walletState.name != $1.walletState.name },
                        callback: { self.name.text = $0.walletState.name })
        store.subscribe(self,
                        selector: {$0.walletState.balance != $1.walletState.balance },
                        callback: { state in
                            if let balance = state.walletState.balance {
                                self.balance = balance
                            } })
    }

    private func setBalances() {
        guard let rate = exchangeRate else { return }
        let amount = Amount(amount: balance, rate: rate, maxDigits: store.state.maxDigits)
        let singleLtcAmount = Amount(amount: 100000000, rate: rate, maxDigits: store.state.maxDigits)

        if !hasInitialized {
            let amount = Amount(amount: balance, rate: exchangeRate!, maxDigits: store.state.maxDigits)
            NSLayoutConstraint.deactivate(isLtcSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(isLtcSwapped ? self.swappedConstraints : self.regularConstraints)
            primaryBalance.setValue(amount.amountForLtcFormat)
            secondaryBalance.setValue(amount.localAmount)
            currentLTCValueLabel.setValue(singleLtcAmount.localAmount)
            if isLtcSwapped {
                primaryBalance.transform = transform(forView: primaryBalance)
            } else {
                secondaryBalance.transform = transform(forView: secondaryBalance)
            }
            hasInitialized = true
            hideExtraViews()
        } else {
            if primaryBalance.isHidden {
                primaryBalance.isHidden = false
            }

            if secondaryBalance.isHidden {
                secondaryBalance.isHidden = false
            }

            primaryBalance.setValueAnimated(amount.amountForLtcFormat, completion: { [weak self] in
                guard let myself = self else { return }
                if !myself.isLtcSwapped {
                    myself.primaryBalance.transform = .identity
                } else {
                    myself.primaryBalance.transform = myself.transform(forView: myself.primaryBalance)
                }
                myself.hideExtraViews()
            })
            secondaryBalance.setValueAnimated(amount.localAmount, completion: { [weak self] in
                guard let myself = self else { return }
                if myself.isLtcSwapped {
                    myself.secondaryBalance.transform = .identity
                } else {
                    myself.secondaryBalance.transform = myself.transform(forView: myself.secondaryBalance)
                }
                myself.hideExtraViews()
            })
        }
    }

    private func hideExtraViews() {
        var didHide = false
        if secondaryBalance.frame.maxX > search.frame.minX {
            secondaryBalance.isHidden = true
            didHide = true
        } else {
            secondaryBalance.isHidden = false
        }

        if primaryBalance.frame.maxX > search.frame.minX {
            primaryBalance.isHidden = true
            didHide = true
        } else {
            primaryBalance.isHidden = false
        }
        equals.isHidden = didHide
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }

    @objc private func currencySwitchTapped() {
        layoutIfNeeded()
        UIView.spring(0.7, animations: {
            self.primaryBalance.transform = self.primaryBalance.transform.isIdentity ? self.transform(forView: self.primaryBalance) : .identity
            self.secondaryBalance.transform = self.secondaryBalance.transform.isIdentity ? self.transform(forView: self.secondaryBalance) : .identity
            NSLayoutConstraint.deactivate(!self.isLtcSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(!self.isLtcSwapped ? self.swappedConstraints : self.regularConstraints)
            self.layoutIfNeeded()
        }) { _ in }

        self.store.perform(action: CurrencyChange.toggle())
    }
  
    @objc private func priceTapViewTapped() {
      layoutIfNeeded()
      ///TODO: write an update of the price
      setBalances()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
