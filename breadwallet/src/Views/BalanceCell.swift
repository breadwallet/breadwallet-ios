//
//  BalanceCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-07-01.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import UIKit

private let largeFontSize: CGFloat = 28.0
private let smallFontSize: CGFloat = 14.0

class BalanceCell: UIView, Subscriber {
    
    private let currency: Currency
    private let balanceLabel = UILabel(font: .customBody(size: 14.0))
    private let primaryBalance: UpdatingLabel
    private let secondaryBalance: UpdatingLabel
    private let conversionSymbol = UIImageView(image: #imageLiteral(resourceName: "conversion"))
    private let currencyTapView = UIView()
    private var regularConstraints: [NSLayoutConstraint] = []
    private var swappedConstraints: [NSLayoutConstraint] = []
    private var hasInitialized = false
    
    private var exchangeRate: Rate? {
        didSet {
            DispatchQueue.main.async {
                self.setBalances()
            }
        }
    }
    
    private var balance: Amount {
        didSet {
            DispatchQueue.main.async {
                self.setBalances()
            }
        }
    }
    
    private var showFiatAmounts: Bool {
        didSet {
            DispatchQueue.main.async {
                self.setBalances()
            }
        }
    }
    
    init(currency: Currency) {
        self.currency = currency
        self.balance = Amount.zero(currency)
        self.showFiatAmounts = Store.state.showFiatAmounts
        if let rate = currency.state?.currentRate {
            let placeholderAmount = Amount.zero(currency, rate: rate)
            self.exchangeRate = rate
            self.secondaryBalance = UpdatingLabel(formatter: placeholderAmount.localFormat)
            self.primaryBalance = UpdatingLabel(formatter: placeholderAmount.tokenFormat)
        } else {
            self.secondaryBalance = UpdatingLabel(formatter: NumberFormatter())
            self.primaryBalance = UpdatingLabel(formatter: NumberFormatter())
        }
        super.init(frame: .zero)
        addSubviews()
        addConstraints()
        setInitialData()
        addSubscriptions()
    }
    
    private func addSubscriptions() {
        Store.lazySubscribe(self,
                            selector: { $0.showFiatAmounts != $1.showFiatAmounts },
                            callback: { [weak self] state in
                                self?.showFiatAmounts = state.showFiatAmounts
        })
        Store.lazySubscribe(self,
                            selector: { [weak self] oldState, newState in
                                guard let `self` = self else { return false }
                                return oldState[self.currency]?.currentRate != newState[self.currency]?.currentRate },
                            callback: {
                                [weak self] in
                                guard let `self` = self else { return }
                                if let rate = $0[self.currency]?.currentRate {
                                    let placeholderAmount = Amount.zero(self.currency, rate: rate)
                                    self.secondaryBalance.formatter = placeholderAmount.localFormat
                                    self.primaryBalance.formatter = placeholderAmount.tokenFormat
                                }
                                self.exchangeRate = $0[self.currency]?.currentRate
        })
        
        Store.subscribe(self,
                        selector: { [weak self] oldState, newState in
                            guard let `self` = self else { return false }
                            return oldState[self.currency]?.balance != newState[self.currency]?.balance },
                        callback: { [weak self] state in
                            guard let `self` = self else { return }
                            if let balance = state[self.currency]?.balance {
                                self.balance = balance
                            } })
    }
    
    private func addSubviews() {
        addSubview(balanceLabel)
        addSubview(primaryBalance)
        addSubview(secondaryBalance)
        addSubview(conversionSymbol)
        addSubview(currencyTapView)
    }
    
    private func addConstraints() {
        balanceLabel.constrain([
            balanceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            balanceLabel.centerYAnchor.constraint(equalTo: centerYAnchor)])
        primaryBalance.constrain([
            primaryBalance.firstBaselineAnchor.constraint(equalTo: balanceLabel.firstBaselineAnchor)])
        secondaryBalance.constrain([
            secondaryBalance.firstBaselineAnchor.constraint(equalTo: balanceLabel.firstBaselineAnchor)])
        conversionSymbol.constrain([
            conversionSymbol.heightAnchor.constraint(equalToConstant: 12.0),
            conversionSymbol.heightAnchor.constraint(equalTo: conversionSymbol.widthAnchor),
            conversionSymbol.bottomAnchor.constraint(equalTo: primaryBalance.firstBaselineAnchor)])
        currencyTapView.constrain([
            currencyTapView.topAnchor.constraint(equalTo: topAnchor),
            currencyTapView.trailingAnchor.constraint(equalTo: trailingAnchor),
            currencyTapView.bottomAnchor.constraint(equalTo: bottomAnchor),
            currencyTapView.widthAnchor.constraint(equalToConstant: 150.0)])
        regularConstraints = [
            primaryBalance.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            primaryBalance.leadingAnchor.constraint(equalTo: conversionSymbol.trailingAnchor, constant: C.padding[1]),
            conversionSymbol.leadingAnchor.constraint(equalTo: secondaryBalance.trailingAnchor, constant: C.padding[1])
        ]
        swappedConstraints = [
            secondaryBalance.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            secondaryBalance.leadingAnchor.constraint(equalTo: conversionSymbol.trailingAnchor, constant: C.padding[1]),
            conversionSymbol.leadingAnchor.constraint(equalTo: primaryBalance.trailingAnchor, constant: C.padding[1])
        ]
        NSLayoutConstraint.activate(showFiatAmounts ? self.swappedConstraints : self.regularConstraints)
    }
    
    private func setInitialData() {
        balanceLabel.textColor = .transparentWhiteText
        balanceLabel.text = S.Account.balance
        
        primaryBalance.textAlignment = .right
        secondaryBalance.textAlignment = .right
        
        swapLabels()
        
        let gr = UITapGestureRecognizer(target: self, action: #selector(currencySwitchTapped))
        currencyTapView.addGestureRecognizer(gr)
        
        conversionSymbol.tintColor = .whiteTint
    }
    
    private func setBalances() {
        guard let rate = exchangeRate else {
            setCryptoOnlyBalance()
            return
        }
        
        let amount = Amount(amount: balance, rate: rate)
        
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
        NSLayoutConstraint.deactivate(showFiatAmounts ? regularConstraints : swappedConstraints)
        NSLayoutConstraint.activate(showFiatAmounts ? swappedConstraints : regularConstraints)
        if showFiatAmounts {
            primaryBalance.makeSecondary()
            secondaryBalance.makePrimary()
        } else {
            primaryBalance.makePrimary()
            secondaryBalance.makeSecondary()
        }
    }
    
    @objc private func currencySwitchTapped() {
        layoutIfNeeded()
        UIView.spring(0.7, animations: {
            self.primaryBalance.toggle()
            self.secondaryBalance.toggle()
            NSLayoutConstraint.deactivate(!self.showFiatAmounts ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(!self.showFiatAmounts ? self.swappedConstraints : self.regularConstraints)
            self.layoutIfNeeded()
        }, completion: { _ in })
        
        Store.perform(action: CurrencyChange.Toggle())
    }
    
    private func setCryptoOnlyBalance() {
        primaryBalance.text = balance.description
        secondaryBalance.isHidden = true
        conversionSymbol.isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

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
