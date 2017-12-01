//
//  HomeScreenCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class Background : UIView, GradientDrawable {

    var store: Store?

    override func layoutSubviews() {
        let maskLayer = CAShapeLayer()
        let corners: UIRectCorner = .allCorners
        maskLayer.path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 4.0, height: 4.0)).cgPath
        layer.mask = maskLayer
    }

    override func draw(_ rect: CGRect) {
        guard let store = store else { return }

        if store.state.walletState.token?.code == "BRD" {
            drawGradient(start: .lightGray,
                         end: .darkGray,
                         rect)
        } else if store.state.currency == .bitcoin {
            drawGradient(rect)
        } else {
            drawGradient(start: store.state.currency.gradientColours.0,
                         end: store.state.currency.gradientColours.1,
                         rect)
        }
    }
}

class HomeScreenCell : UITableViewCell {

    private let currencyName = UILabel(font: .customBody(size: 16.0), color: .white)
    private let price = UILabel(font: .customBody(size: 14.0), color: .white)
    private let balance = UILabel(font: .customBody(size: 16.0), color: .white)
    private let container = Background()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    func setData(currencyName: String, price: String, balance: String, store: Store) {
        self.currencyName.text = currencyName
        self.price.text = price
        self.balance.text = balance
        self.container.store = store
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
        container.addSubview(balance)
    }

    private func addConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1], left: C.padding[2], bottom: -C.padding[1], right: -C.padding[2]))
        currencyName.constrain([
            currencyName.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            currencyName.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2]) ])
        price.constrain([
            price.leadingAnchor.constraint(equalTo: currencyName.leadingAnchor),
            price.topAnchor.constraint(equalTo: currencyName.bottomAnchor, constant: C.padding[2]),
            price.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])])
        balance.constrain([
            balance.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            balance.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])])
    }

    private func setupStyle() {
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
