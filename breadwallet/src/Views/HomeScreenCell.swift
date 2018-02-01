//
//  HomeScreenCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class Background : UIView, GradientDrawable {

    var currency: CurrencyDef?

    override func layoutSubviews() {
        let maskLayer = CAShapeLayer()
        let corners: UIRectCorner = .allCorners
        maskLayer.path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 4.0, height: 4.0)).cgPath
        layer.mask = maskLayer
    }

    override func draw(_ rect: CGRect) {
        guard let currency = currency else { return }
        drawGradient(start: currency.colors.0, end: currency.colors.1, rect)
    }
}

class HomeScreenCell : UITableViewCell {
    
    static let cellIdentifier = "CurrencyCell"

    private let currencyName = UILabel(font: .customBold(size: 18.0), color: .white)
    private let price = UILabel(font: .customBold(size: 14.0), color: .transparentWhiteText)
    private let fiatBalance = UILabel(font: .customBold(size: 18.0), color: .white)
    private let tokenBalance = UILabel(font: .customBold(size: 14.0), color: .transparentWhiteText)
    private let container = Background()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    func set(viewModel: AssetListViewModel) {
        self.container.currency = viewModel.currency
        self.currencyName.text = viewModel.currency.name
        self.price.text = viewModel.exchangeRate
        self.fiatBalance.text = viewModel.fiatBalance
        self.tokenBalance.text = viewModel.tokenBalance
        self.container.setNeedsDisplay()
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }

    private func addSubviews() {
        contentView.addSubview(container)
        container.addSubview(currencyName)
        container.addSubview(price)
        container.addSubview(fiatBalance)
        container.addSubview(tokenBalance)
    }

    private func addConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1]*0.5,
                                                           left: C.padding[2],
                                                           bottom: -C.padding[1],
                                                           right: -C.padding[2]))
        currencyName.constrain([
            currencyName.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            currencyName.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])
            ])
        price.constrain([
            price.leadingAnchor.constraint(equalTo: currencyName.leadingAnchor),
            price.topAnchor.constraint(equalTo: currencyName.bottomAnchor, constant: 0.0),
            price.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])
            ])
        fiatBalance.constrain([
            fiatBalance.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            fiatBalance.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2]),
            fiatBalance.leadingAnchor.constraint(greaterThanOrEqualTo: currencyName.trailingAnchor, constant: C.padding[1])
            ])
        tokenBalance.constrain([
            tokenBalance.trailingAnchor.constraint(equalTo: fiatBalance.trailingAnchor),
            tokenBalance.topAnchor.constraint(equalTo: fiatBalance.bottomAnchor, constant: 0.0),
            tokenBalance.leadingAnchor.constraint(greaterThanOrEqualTo: price.trailingAnchor, constant: C.padding[1]),
            price.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])
            ])
    }

    private func setupStyle() {
        selectionStyle = .none
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
