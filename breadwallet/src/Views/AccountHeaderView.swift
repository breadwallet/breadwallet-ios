//
//  AccountHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

private let largeFontSize: CGFloat = 28.0
private let smallFontSize: CGFloat = 14.0

class AccountHeaderView: UIView, GradientDrawable, Subscriber {

    // MARK: - Views
    
    private let currencyName = UILabel(font: .customBody(size: 18.0))
    private let exchangeRateLabel = UILabel(font: .customBody(size: 14.0))
    private let balanceLabel = UILabel(font: .customBody(size: 14.0))
    private let primaryBalance: UpdatingLabel
    private let secondaryBalance: UpdatingLabel
    private let conversionSymbol = UIImageView(image: #imageLiteral(resourceName: "conversion"))
    private let currencyTapView = UIView()
    private let syncView: SyncingHeaderView
    private let modeLabel = UILabel(font: .customBody(size: 12.0), color: .transparentWhiteText) // debug info
    private var regularConstraints: [NSLayoutConstraint] = []
    private var swappedConstraints: [NSLayoutConstraint] = []
    private var syncViewHeight: NSLayoutConstraint?
    private var delistedTokenView: DelistedTokenView?

    // MARK: Properties
    private let currency: Currency
    private var hasInitialized = false
    private var hasSetup = false
    
    private var isSyncIndicatorVisible: Bool = false {
        didSet {
            if isSyncIndicatorVisible {
                showSyncView()
            } else {
                hideSyncView()
            }
        }
    }

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
        didSet {
            DispatchQueue.main.async {
                self.setBalances()
            }
        }
    }
    
    private var balance: UInt256 = 0 {
        didSet {
            DispatchQueue.main.async {
                self.setBalances()
            }
        }
    }
    
    private var isBtcSwapped: Bool {
        didSet {
            DispatchQueue.main.async {
                self.setBalances()
            }
        }
    }

    // MARK: -
    
    init(currency: Currency) {
        self.currency = currency
        self.syncView =  SyncingHeaderView(currency: currency)
        self.isBtcSwapped = Store.state.isBtcSwapped
        if let rate = currency.state?.currentRate {
            let placeholderAmount = Amount(amount: 0, currency: currency, rate: rate)
            self.exchangeRate = rate
            self.secondaryBalance = UpdatingLabel(formatter: placeholderAmount.localFormat)
            self.primaryBalance = UpdatingLabel(formatter: placeholderAmount.tokenFormat)
        } else {
            self.secondaryBalance = UpdatingLabel(formatter: NumberFormatter())
            self.primaryBalance = UpdatingLabel(formatter: NumberFormatter())
        }
        if let token = currency as? ERC20Token, token.isSupported == false {
            self.delistedTokenView = DelistedTokenView(currency: currency)
        }
        super.init(frame: CGRect())
        
        setup()
    }

    // MARK: Private
    
    private func setup() {
        addSubviews()
        addConstraints()
        setData()
        addSubscriptions()
    }

    private func setData() {
        currencyName.textColor = .white
        currencyName.textAlignment = .center
        currencyName.text = currency.name
        
        exchangeRateLabel.textColor = .transparentWhiteText
        exchangeRateLabel.textAlignment = .center
        
        balanceLabel.textColor = .transparentWhiteText
        balanceLabel.text = S.Account.balance
        conversionSymbol.tintColor = .whiteTint
        
        primaryBalance.textAlignment = .right
        secondaryBalance.textAlignment = .right
        
        swapLabels()

        modeLabel.isHidden = true
        
        let gr = UITapGestureRecognizer(target: self, action: #selector(currencySwitchTapped))
        currencyTapView.addGestureRecognizer(gr)
    }

    private func addSubviews() {
        addSubview(currencyName)
        addSubview(exchangeRateLabel)
        addSubview(balanceLabel)
        addSubview(primaryBalance)
        addSubview(secondaryBalance)
        addSubview(conversionSymbol)
        addSubview(modeLabel)
        addSubview(currencyTapView)
        addSubview(syncView)
        if let delistedTokenView = delistedTokenView {
            addSubview(delistedTokenView)
        }
    }

    private func showSyncView() {
        syncViewHeight?.constant = SyncingHeaderView.height
        UIView.spring(C.animationDuration, animations: {
            self.superview?.superview?.layoutIfNeeded()
            self.syncView.syncIndicator.isHidden = false
        }, completion: {_ in})
    }

    private func hideSyncView() {
        syncViewHeight?.constant = 0.0
        UIView.spring(C.animationDuration, animations: {
            self.superview?.superview?.layoutIfNeeded()
            self.syncView.syncIndicator.isHidden = true
        }, completion: {_ in})
    }

    private func addConstraints() {
        currencyName.constrain([
            currencyName.constraint(.leading, toView: self, constant: C.padding[2]),
            currencyName.constraint(.trailing, toView: self, constant: -C.padding[2]),
            currencyName.constraint(.top, toView: self, constant: E.isIPhoneX ? C.padding[5] : C.padding[3])])
        exchangeRateLabel.pinTo(viewAbove: currencyName)
        balanceLabel.constrain([
            balanceLabel.topAnchor.constraint(equalTo: exchangeRateLabel.bottomAnchor, constant: C.padding[4]),
            balanceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2])])
        primaryBalance.constrain([
            primaryBalance.firstBaselineAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 30.0)])
        secondaryBalance.constrain([
            secondaryBalance.firstBaselineAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 30.0)])
        conversionSymbol.constrain([
            conversionSymbol.heightAnchor.constraint(equalToConstant: 12.0),
            conversionSymbol.heightAnchor.constraint(equalTo: conversionSymbol.widthAnchor),
            conversionSymbol.bottomAnchor.constraint(equalTo: primaryBalance.firstBaselineAnchor)])
        currencyTapView.constrain([
            currencyTapView.trailingAnchor.constraint(equalTo: balanceLabel.trailingAnchor),
            currencyTapView.topAnchor.constraint(equalTo: primaryBalance.topAnchor, constant: -C.padding[1]),
            currencyTapView.bottomAnchor.constraint(equalTo: primaryBalance.bottomAnchor, constant: C.padding[1]) ])

        regularConstraints = [
            primaryBalance.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            primaryBalance.leadingAnchor.constraint(equalTo: conversionSymbol.trailingAnchor, constant: C.padding[1]),
            conversionSymbol.leadingAnchor.constraint(equalTo: secondaryBalance.trailingAnchor, constant: C.padding[1]),
            currencyTapView.leadingAnchor.constraint(equalTo: secondaryBalance.leadingAnchor)
        ]
        swappedConstraints = [
            secondaryBalance.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            secondaryBalance.leadingAnchor.constraint(equalTo: conversionSymbol.trailingAnchor, constant: C.padding[1]),
            conversionSymbol.leadingAnchor.constraint(equalTo: primaryBalance.trailingAnchor, constant: C.padding[1]),
            currencyTapView.leadingAnchor.constraint(equalTo: primaryBalance.leadingAnchor)
        ]
        NSLayoutConstraint.activate(isBtcSwapped ? self.swappedConstraints : self.regularConstraints)

        modeLabel.constrain([
            modeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            modeLabel.centerYAnchor.constraint(equalTo: balanceLabel.centerYAnchor)])
        syncViewHeight = syncView.heightAnchor.constraint(equalToConstant: 40.0)
        if let delistedTokenView = delistedTokenView {
            delistedTokenView.constrain([
                delistedTokenView.topAnchor.constraint(equalTo: primaryBalance.firstBaselineAnchor, constant: C.padding[2]),
                delistedTokenView.bottomAnchor.constraint(equalTo: bottomAnchor),
                delistedTokenView.widthAnchor.constraint(equalTo: widthAnchor),
                delistedTokenView.leadingAnchor.constraint(equalTo: leadingAnchor)])
        } else {
            syncView.constrain([
                syncView.topAnchor.constraint(equalTo: primaryBalance.firstBaselineAnchor, constant: C.padding[2]),
                syncView.bottomAnchor.constraint(equalTo: bottomAnchor),
                syncView.widthAnchor.constraint(equalTo: widthAnchor),
                syncView.leadingAnchor.constraint(equalTo: leadingAnchor),
                syncViewHeight])
        }
    }

    private func addSubscriptions() {
        Store.lazySubscribe(self,
                            selector: { $0.isBtcSwapped != $1.isBtcSwapped },
                            callback: { self.isBtcSwapped = $0.isBtcSwapped })
        Store.lazySubscribe(self,
                            selector: { $0[self.currency]?.currentRate != $1[self.currency]?.currentRate},
                            callback: {
                                if let rate = $0[self.currency]?.currentRate {
                                    let placeholderAmount = Amount(amount: 0, currency: self.currency, rate: rate)
                                    self.secondaryBalance.formatter = placeholderAmount.localFormat
                                    self.primaryBalance.formatter = placeholderAmount.tokenFormat
                                }
                                self.exchangeRate = $0[self.currency]?.currentRate
        })
        
        Store.lazySubscribe(self,
                            selector: { $0[self.currency]?.maxDigits != $1[self.currency]?.maxDigits},
                            callback: {
                                if let rate = $0[self.currency]?.currentRate {
                                    let placeholderAmount = Amount(amount: 0, currency: self.currency, rate: rate)
                                    self.secondaryBalance.formatter = placeholderAmount.localFormat
                                    self.primaryBalance.formatter = placeholderAmount.tokenFormat
                                    self.setBalances()
                                }
        })
        Store.subscribe(self,
                        selector: { $0[self.currency]?.balance != $1[self.currency]?.balance },
                        callback: { state in
                            if let balance = state[self.currency]?.balance {
                                self.balance = balance
                            } })
        
        Store.subscribe(self, selector: { $0[self.currency]?.syncState != $1[self.currency]?.syncState },
                        callback: { state in
                            guard let syncState = state[self.currency]?.syncState else { return }
                            switch syncState {
                            case .connecting:
                                self.isSyncIndicatorVisible = true
                            case .syncing:
                                self.isSyncIndicatorVisible = true
                            case .success:
                                self.isSyncIndicatorVisible = false
                            }
        })
        
        Store.subscribe(self, selector: {
            return $0[self.currency]?.lastBlockTimestamp != $1[self.currency]?.lastBlockTimestamp },
                        callback: { state in
                            if let progress = state[self.currency]?.syncProgress {
                                self.syncView.syncIndicator.progress = CGFloat(progress)
                            }
        })
    }

    private func setCryptoOnlyBalance() {
        let amount = Amount(amount: balance, currency: currency, rate: nil)
        primaryBalance.text = amount.description
        secondaryBalance.isHidden = true
        conversionSymbol.isHidden = true
    }

    func setBalances() {
        guard let rate = exchangeRate else {
            setCryptoOnlyBalance()
            return
        }
        
        exchangeRateLabel.text = String(format: S.AccountHeader.exchangeRate, rate.localString, currency.code)
        
        let amount = Amount(amount: balance, currency: currency, rate: rate)
        
        if !hasInitialized {
            primaryBalance.setValue(amount.tokenValue)
            secondaryBalance.setValue(amount.fiatValue)
            swapLabels()
            hasInitialized = true
        } else {
            if primaryBalance.isHidden {
                primaryBalance.isHidden = false
            }

            if secondaryBalance.isHidden {
                secondaryBalance.isHidden = false
            }
            
            primaryBalance.setValueAnimated(amount.tokenValue, completion: { [weak self] in
                self?.swapLabels()
            })
            secondaryBalance.setValueAnimated(amount.fiatValue, completion: { [weak self] in
                self?.swapLabels()
            })
        }
    }
    
    private func swapLabels() {
        NSLayoutConstraint.deactivate(isBtcSwapped ? regularConstraints : swappedConstraints)
        NSLayoutConstraint.activate(isBtcSwapped ? swappedConstraints : regularConstraints)
        if isBtcSwapped {
            primaryBalance.makeSecondary()
            secondaryBalance.makePrimary()
        } else {
            primaryBalance.makePrimary()
            secondaryBalance.makeSecondary()
        }
    }

    override func draw(_ rect: CGRect) {
        drawGradient(start: currency.colors.0, end: currency.colors.1, rect)
    }

    @objc private func currencySwitchTapped() {
        layoutIfNeeded()
        UIView.spring(0.7, animations: {
            self.primaryBalance.toggle()
            self.secondaryBalance.toggle()
            NSLayoutConstraint.deactivate(!self.isBtcSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(!self.isBtcSwapped ? self.swappedConstraints : self.regularConstraints)
            self.layoutIfNeeded()
        }, completion: { _ in })

        Store.perform(action: CurrencyChange.Toggle())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: -

private extension UILabel {
    func makePrimary() {
        font = UIFont.customBold(size: largeFontSize)
        textColor = .white
        reset()
    }
    
    func makeSecondary() {
        font = UIFont.customBody(size: largeFontSize)
        textColor = .transparentWhiteText
        shrink()
    }
    
    func shrink() {
        transform = .identity // must reset the view's transform before we calculate the next transform
        let scaleFactor: CGFloat = smallFontSize/largeFontSize
        let deltaX = frame.width * (1-scaleFactor)
        let deltaY = frame.height * (1-scaleFactor)
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        transform = scale.translatedBy(x: deltaX, y: deltaY/2.0)
    }
    
    func reset() {
        transform = .identity
    }
    
    func toggle() {
        if transform.isIdentity {
            makeSecondary()
        } else {
            makePrimary()
        }
    }
}
