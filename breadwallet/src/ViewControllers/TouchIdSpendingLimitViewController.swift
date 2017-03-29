//
//  TouchIdSpendingLimitViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TouchIdSpendingLimitViewController : UIViewController {

    private let titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)
    private let faq = UIButton.faq
    private let amount = UILabel(font: .customMedium(size: 26.0), color: .darkText)
    private let currencyButton = ShadowButton(title: S.Send.defaultCurrencyLabel, type: .tertiary)
    private let currencySwitcher = InViewAlert(type: .secondary)
    private let slider = UISlider()
    private let body = UILabel.wrapping(font: .customBody(size: 13.0), color: .darkText)
    private var currencySwitcherHeight: NSLayoutConstraint?

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(faq)
        view.addSubview(amount)
        view.addSubview(currencyButton)
        view.addSubview(currencySwitcher)
        view.addSubview(slider)
        view.addSubview(body)
    }

    private func addConstraints() {
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2]) ])
        faq.constrain([
            faq.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            faq.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor) ])
        amount.constrain([
            amount.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            amount.topAnchor.constraint(equalTo: titleLabel.bottomAnchor) ])
        currencyButton.constrain([
            currencyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            currencyButton.centerYAnchor.constraint(equalTo: amount.centerYAnchor),
            currencyButton.heightAnchor.constraint(equalToConstant: 32.0),
            currencyButton.widthAnchor.constraint(equalToConstant: 62.0) ])
        currencySwitcherHeight = currencySwitcher.heightAnchor.constraint(equalToConstant: 0.0)
        currencySwitcher.constrain([
            currencySwitcherHeight,
            currencySwitcher.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            currencySwitcher.topAnchor.constraint(equalTo: currencyButton.bottomAnchor, constant: C.padding[2]),
            currencyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
        slider.constrain([
            slider.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            slider.topAnchor.constraint(equalTo: currencySwitcher.bottomAnchor, constant: C.padding[2]),
            slider.trailingAnchor.constraint(equalTo: currencyButton.trailingAnchor),
            slider.heightAnchor.constraint(equalToConstant: 8.0)
            ])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            body.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: currencyButton.trailingAnchor) ])
        slider.addGradientTrack()
    }

    private func setData() {
        view.backgroundColor = .white
        titleLabel.text = S.TouchIdSpendingLimit.title
        amount.text = "$300"
        body.text = S.TouchIdSpendingLimit.body
        slider.minimumValue = 0.0
        slider.maximumValue = 300.0
        slider.value = 200.0
    }

}
