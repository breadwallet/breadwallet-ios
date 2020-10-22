// 
//  StakingCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-10-17.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class StakingCell: UIView {
    
    private let iconContainer = UIView(color: .transparentIconBackground)
    private let icon = UIImageView()
    private let currency: Currency
    private let title = UILabel(font: .customBody(size: 14), color: .rewardsViewNormalTitle)
    private var indicatorView = UIImageView()
    private let topPadding = UIView(color: .whiteTint)
    private let bottomPadding = UIView(color: .whiteTint)
    
    init(currency: Currency) {
        self.currency = currency
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        addSubviews()
        setupConstraints()
        setInitialData()
    }
    
    private func addSubviews() {
        addSubview(topPadding)
        addSubview(bottomPadding)
        addSubview(iconContainer)
        iconContainer.addSubview(icon)
        addSubview(title)
        addSubview(indicatorView)
    }
    
    private func setupConstraints() {
        let containerPadding = C.padding[2]
        topPadding.constrainTopCorners(height: containerPadding)
        bottomPadding.constrainBottomCorners(height: containerPadding)
        iconContainer.constrain([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: containerPadding),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            iconContainer.widthAnchor.constraint(equalTo: iconContainer.heightAnchor)])
        icon.constrain(toSuperviewEdges: .zero)
        title.constrain([
            title.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: C.padding[1]),
            title.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])
        indicatorView.constrain([
            indicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -21)])
    }
    
    private func setInitialData() {
        //clipsToBounds = true
        icon.image = currency.imageNoBackground
        icon.tintColor = .white
        iconContainer.layer.cornerRadius = C.Sizes.homeCellCornerRadius
        iconContainer.backgroundColor = currency.colors.0
        title.text = S.Staking.stakingTitle
        indicatorView.image = UIImage(named: "RightArrow")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
