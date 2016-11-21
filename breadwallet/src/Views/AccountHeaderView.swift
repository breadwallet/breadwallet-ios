//
//  AccountHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AccountHeaderView: UIView {

    private let name = UILabel(font: UIFont.boldSystemFont(ofSize: 17.0))
    private let manage = UIButton(type: .system)
    private let primaryBalance = UILabel()
    private let secondaryBalance = UILabel()
    private let info = UILabel()

    init() {
        super.init(frame: CGRect())
        setupSubviews()
    }

    private func setupSubviews() {
        setData()
        addSubviews()
        addConstraints()
    }

    private func setData() {
        name.text = "My Bread"
        name.textColor = .white

        manage.setTitle("MANAGE", for: .normal)
        manage.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17.0)
        manage.tintColor = .white

        primaryBalance.text = "b0.0844"
        primaryBalance.textColor = .white
        primaryBalance.font = UIFont.customBody(size: 26.0)

        secondaryBalance.text = "= $514.98"
        secondaryBalance.textColor = .secondaryText
        secondaryBalance.font = UIFont.customBody(size: 13.0)

        info.text = "Bitcoin price +3.4% today"
        info.textColor = .secondaryText
        info.font = UIFont.customBody(size: 13.0)
    }

    private func addSubviews() {
        addSubview(name)
        addSubview(manage)
        addSubview(primaryBalance)
        addSubview(secondaryBalance)
        addSubview(info)
    }

    private func addConstraints() {
        name.constrain([
                name.constraint(.leading, toView: self, constant: C.padding[2]),
                name.constraint(.top, toView: self, constant: 30.0)
            ])
        manage.constrain([
                manage.constraint(.trailing, toView: self, constant: -C.padding[2]),
                NSLayoutConstraint(item: manage.titleLabel!, attribute: .firstBaseline, relatedBy: .equal, toItem: name, attribute: .firstBaseline, multiplier: 1.0, constant: 0.0)
            ])
        primaryBalance.constrain([
                primaryBalance.constraint(.leading, toView: self, constant: C.padding[2]),
                primaryBalance.constraint(toBottom: name, constant: C.padding[2])
            ])
        secondaryBalance.constrain([
                secondaryBalance.constraint(toTrailing: primaryBalance, constant: C.padding[1]/2.0),
                secondaryBalance.constraint(.firstBaseline, toView: primaryBalance, constant: 0.0)
            ])
        info.constrain([
                info.constraint(.leading, toView: self, constant: C.padding[2]),
                info.constraint(toBottom: secondaryBalance, constant: C.padding[1]/2.0)
            ])
    }

    override func draw(_ rect: CGRect) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor.gradientStart.cgColor, UIColor.gradientEnd.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)

        let context = UIGraphicsGetCurrentContext()
        context?.drawLinearGradient(gradient!, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: rect.width, y: 0.0), options: [])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
