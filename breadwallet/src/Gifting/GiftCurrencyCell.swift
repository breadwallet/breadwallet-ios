// 
//  GiftCurrencyCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-12-08.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class GiftCurrencyCell: UIView {
    
    private let currency = Currencies.btc.instance!
    private let iconContainer = UIView(color: .transparentIconBackground)
    private let icon = UIImageView()
    private let currencyName = UILabel(font: Theme.body1Accent, color: Theme.primaryText)
    private let price = UILabel(font: Theme.body3, color: Theme.secondaryText)
    private let fiatBalance = UILabel(font: Theme.body1Accent, color: Theme.primaryText)
    private let tokenBalance = UILabel(font: Theme.body3, color: Theme.secondaryText)
    
    private let info: GiftInfo
    
    init(info: GiftInfo) {
        self.info = info
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        addSubview(iconContainer)
        iconContainer.addSubview(icon)
        addSubview(currencyName)
        addSubview(price)
        addSubview(fiatBalance)
        addSubview(tokenBalance)
    }
    
    private func addConstraints() {
        iconContainer.constrain([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[1]),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            iconContainer.widthAnchor.constraint(equalTo: iconContainer.heightAnchor)])
        icon.constrain(toSuperviewEdges: .zero)
        price.constrain([
            price.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: C.padding[1]),
            price.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor)])
        currencyName.constrain([
            currencyName.leadingAnchor.constraint(equalTo: price.leadingAnchor),
            currencyName.bottomAnchor.constraint(equalTo: price.topAnchor, constant: 0.0)])
        tokenBalance.constrain([
            tokenBalance.bottomAnchor.constraint(equalTo: price.bottomAnchor),
            tokenBalance.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2])])
        fiatBalance.constrain([
            fiatBalance.trailingAnchor.constraint(equalTo: tokenBalance.trailingAnchor),
            fiatBalance.bottomAnchor.constraint(equalTo: tokenBalance.topAnchor)])
    }
    
    private func setInitialData() {
        backgroundColor = currency.colors.0
        layer.cornerRadius = 8.0
        
        icon.image = currency.imageNoBackground
        iconContainer.layer.cornerRadius = C.Sizes.homeCellCornerRadius
        iconContainer.clipsToBounds = true
        icon.tintColor = .white
        
        price.text = "$\(info.rate.price)"
        currencyName.text = "Bitcoin"
        
        fiatBalance.text = info.sats.fiatDescription
        tokenBalance.text = info.sats.tokenDescription
    }
    
}
