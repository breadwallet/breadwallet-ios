//
//  AmountViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-19.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

private let currencyHeight: CGFloat = 80.0

class AmountViewController : UIViewController {

    init(store: Store, isPinPadExpandedAtLaunch: Bool) {
        self.store = store
        self.isPinPadExpandedAtLaunch = isPinPadExpandedAtLaunch
        self.currencySlider = CurrencySlider(rates: store.state.rates,
                                             defaultCode: store.state.defaultCurrencyCode,
                                             isBtcSwapped: store.state.isBtcSwapped)
        self.currencyToggle = ShadowButton(title: S.Symbols.currencyButtonTitle(maxDigits: store.state.maxDigits), type: .tertiary)
        super.init(nibName: nil, bundle: nil)
    }

    var balanceTextForAmount: ((Satoshis?, Rate?) -> NSAttributedString?)?
    var didUpdateAmount: ((Satoshis?) -> Void)?
    var didChangeFirstResponder: ((Bool) -> Void)?

    var currentOutput: String {
        return amountLabel.text ?? ""
    }
    var selectedRate: Rate? {
        didSet {
            fullRefresh()
        }
    }
    func forceUpdateAmount(amount: Satoshis) {
        self.amount = amount
        fullRefresh()
    }

    func expandPinPad() {
        if pinPadHeight?.constant == 0.0 {
            togglePinPad()
        }
    }

    private let store: Store
    private let isPinPadExpandedAtLaunch: Bool
    private var minimumFractionDigits = 0
    private var hasTrailingDecimal = false
    private var pinPadHeight: NSLayoutConstraint?
    private var currencyContainerHeight: NSLayoutConstraint?
    private var currencyContainterTop: NSLayoutConstraint?
    private let placeholder = UILabel(font: .customBody(size: 16.0), color: .grayTextTint)
    private let amountLabel = UILabel(font: .customBody(size: 26.0), color: .darkText)
    private let pinPad = PinPadViewController(style: .white, keyboardType: .decimalPad)
    private let currencyToggle: ShadowButton
    private let border = UIView(color: .secondaryShadow)
    private let bottomBorder = UIView(color: .secondaryShadow)
    private let cursor = BlinkingView(blinkColor: C.defaultTintColor)
    private let balanceLabel = UILabel()
    private let currencyContainer = InViewAlert(type: .secondary)
    private let tapView = UIView()
    private let currencySlider: CurrencySlider

    private var amount: Satoshis? {
        didSet {
            updateAmountLabel()
            updateBalanceLabel()
            didUpdateAmount?(amount)
        }
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(amountLabel)
        view.addSubview(placeholder)
        view.addSubview(currencyToggle)
        view.addSubview(currencyContainer)
        view.addSubview(border)
        view.addSubview(cursor)
        view.addSubview(balanceLabel)
        view.addSubview(tapView)
        view.addSubview(bottomBorder)
    }

    private func addConstraints() {
        amountLabel.constrain([
            amountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            amountLabel.centerYAnchor.constraint(equalTo: currencyToggle.centerYAnchor) ])
        placeholder.constrain([
            placeholder.leadingAnchor.constraint(equalTo: amountLabel.leadingAnchor, constant: 2.0),
            placeholder.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor) ])
        cursor.constrain([
            cursor.leadingAnchor.constraint(equalTo: amountLabel.trailingAnchor, constant: 2.0),
            cursor.heightAnchor.constraint(equalToConstant: 24.0),
            cursor.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor),
            cursor.widthAnchor.constraint(equalToConstant: 2.0) ])
        currencyToggle.constrain([
            currencyToggle.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[2]),
            currencyToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        currencyContainerHeight = currencyContainer.constraint(.height, constant: 0.0)
        currencyContainterTop = currencyContainer.constraint(toBottom: currencyToggle, constant: C.padding[2])
        currencyContainer.constrain([
            currencyContainterTop,
            currencyContainer.constraint(.leading, toView: view),
            currencyContainer.constraint(.trailing, toView: view),
            currencyContainerHeight ])
        currencyContainer.arrowXLocation = view.bounds.width - 30.0 - C.padding[2]
        border.constrain([
            border.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            border.topAnchor.constraint(equalTo: currencyContainer.bottomAnchor),
            border.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1.0) ])
        balanceLabel.constrain([
            balanceLabel.leadingAnchor.constraint(equalTo: amountLabel.leadingAnchor),
            balanceLabel.topAnchor.constraint(equalTo: cursor.bottomAnchor) ])
        pinPadHeight = pinPad.view.heightAnchor.constraint(equalToConstant: 0.0)
        addChildViewController(pinPad, layout: {
            pinPad.view.constrain([
                pinPad.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                pinPad.view.topAnchor.constraint(equalTo: border.bottomAnchor),
                pinPad.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                pinPad.view.bottomAnchor.constraint(equalTo: bottomBorder.topAnchor),
                pinPadHeight ])
        })
        bottomBorder.constrain([
            bottomBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 1.0) ])
        tapView.constrain([
            tapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tapView.topAnchor.constraint(equalTo: view.topAnchor),
            tapView.trailingAnchor.constraint(equalTo: currencyToggle.leadingAnchor, constant: 4.0),
            tapView.bottomAnchor.constraint(equalTo: currencyContainer.topAnchor) ])
        preventAmountOverflow()
    }

    private func setInitialData() {
        cursor.isHidden = true
        cursor.startBlinking()
        amountLabel.text = ""
        placeholder.text = S.Send.amountLabel
        currencySlider.load()
        currencyContainer.contentView = currencySlider
        currencyToggle.isToggleable = true
        bottomBorder.isHidden = true
        if store.state.isBtcSwapped {
            if let rate = store.state.currentRate {
                selectedRate = rate
            }
        }
        pinPad.ouputDidUpdate = { [weak self] output in
            self?.handlePinPadUpdate(output: output)
        }
        currencySlider.didSelectCurrency = { [weak self] rate in
            self?.selectedRate = rate.code == C.btcCurrencyCode ? nil : rate
            self?.toggleCurrencyContainer()
        }
        currencyToggle.tap = { [weak self] in
            self?.toggleCurrencyContainer()
        }
        let gr = UITapGestureRecognizer(target: self, action: #selector(didTap))
        tapView.addGestureRecognizer(gr)
        tapView.isUserInteractionEnabled = true

        if isPinPadExpandedAtLaunch {
            didTap()
        }
    }

    private func preventAmountOverflow() {
        amountLabel.constrain([
            amountLabel.trailingAnchor.constraint(lessThanOrEqualTo: currencyToggle.leadingAnchor, constant: -C.padding[2]) ])
        amountLabel.minimumScaleFactor = 0.5
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.setContentCompressionResistancePriority(UILayoutPriorityDefaultLow, for: .horizontal)
    }

    private func handlePinPadUpdate(output: String) {
        placeholder.isHidden = output.utf8.count > 0 ? true : false
        minimumFractionDigits = 0 //set default
        if let decimalLocation = output.range(of: NumberFormatter().currencyDecimalSeparator)?.upperBound {
            let locationValue = output.distance(from: output.endIndex, to: decimalLocation)
            if locationValue == -2 {
                minimumFractionDigits = 2
            } else if locationValue == -1 {
                minimumFractionDigits = 1
            }
        }

        //If trailing decimal, append the decimal to the output
        hasTrailingDecimal = false //set default
        if let decimalLocation = output.range(of: NumberFormatter().currencyDecimalSeparator)?.upperBound {
            if output.endIndex == decimalLocation {
                hasTrailingDecimal = true
            }
        }

        var newAmount: Satoshis?
        if let rate = selectedRate {
            if let value = Double(output) {
                newAmount = Satoshis(value: value, rate: rate)
            }
        } else {
            if let bits = Bits(string: output) {
                newAmount = Satoshis(bits: bits)
            }
        }

        if let newAmount = newAmount {
            if newAmount > C.maxMoney {
                pinPad.removeLast()
            } else {
                amount = newAmount
            }
        } else {
            amount = nil
        }
    }

    private func updateAmountLabel() {
        guard let amount = amount else { amountLabel.text = ""; return }
        var output = NumberFormatter.formattedString(amount: amount, rate: selectedRate, minimumFractionDigits: minimumFractionDigits, maxDigits: store.state.maxDigits)
        if hasTrailingDecimal {
            output = output.appending(NumberFormatter().currencyDecimalSeparator)
        }
        amountLabel.text = output
        placeholder.isHidden = output.utf8.count > 0 ? true : false
    }

    private func updateBalanceLabel() {
        balanceLabel.attributedText = balanceTextForAmount?(amount, selectedRate)
    }

    @objc private func toggleCurrencyContainer() {
        let isCurrencySwitcherCollapsed: Bool = currencyContainerHeight?.constant == 0.0
        UIView.spring(C.animationDuration, animations: {
            if isCurrencySwitcherCollapsed {
                self.currencyContainerHeight?.constant = currencyHeight
                self.currencyContainterTop?.constant = 4.0
            } else {
                self.currencyContainerHeight?.constant = 0.0
                self.currencyContainterTop?.constant = C.padding[2]
            }
            self.parent?.parent?.view?.layoutIfNeeded()
        }, completion: {_ in })
    }

    @objc private func didTap() {
        UIView.spring(C.animationDuration, animations: {
            self.togglePinPad()
            self.parent?.parent?.view.layoutIfNeeded()
        }, completion: { completed in })
    }

    func closePinPad() {
        pinPadHeight?.constant = 0.0
        cursor.isHidden = true
        bottomBorder.isHidden = true
        if let amount = amount, amount.rawValue > 0 {
            balanceLabel.isHidden = false
        } else {
            balanceLabel.isHidden = cursor.isHidden
        }
        updateBalanceLabel()
    }

    private func togglePinPad() {
        let isCollapsed: Bool = pinPadHeight?.constant == 0.0
        pinPadHeight?.constant = isCollapsed ? pinPad.height : 0.0
        cursor.isHidden = isCollapsed ? false : true
        bottomBorder.isHidden = isCollapsed ? false : true
        if let amount = amount, amount.rawValue > 0 {
            balanceLabel.isHidden = false
        } else {
            balanceLabel.isHidden = cursor.isHidden
        }
        updateBalanceLabel()
        didChangeFirstResponder?(isCollapsed)
    }

    private func fullRefresh() {
        if let rate = selectedRate {
            currencyToggle.title = "\(rate.code) (\(rate.currencySymbol))"
        } else {
            currencyToggle.title = S.Symbols.currencyButtonTitle(maxDigits: store.state.maxDigits)
        }
        updateBalanceLabel()
        updateAmountLabel()

        //Update pinpad content to match currency change
        //This must be done AFTER the amount label has updated
        let currentOutput = amountLabel.text ?? ""
        var set = CharacterSet.decimalDigits
        set.formUnion(CharacterSet(charactersIn: NumberFormatter().currencyDecimalSeparator))
        pinPad.currentOutput = String(String.UnicodeScalarView(currentOutput.unicodeScalars.filter { set.contains($0) }))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
