//
//  AlertView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

enum AlertType {
    case pinSet
    case paperKeySet

    var header: String {
        switch self {
        case .pinSet:
            return NSLocalizedString("PIN Set", comment: "Alert Header label")
        case .paperKeySet:
            return NSLocalizedString("Paper Key Set", comment: "Alert Header Label")
        }
    }

    var subheader: String {
        switch self {
        case .pinSet:
            return NSLocalizedString("Use your PIN to login and send money.", comment: "Alert Subheader label")
        case .paperKeySet:
            return NSLocalizedString("Awesome!", comment: "Alert Subheader label")
        }
    }

    var icon: UIView {
        return CheckView()
    }
}

class AlertView: UIView, GradientDrawable {

    private let type: AlertType
    private let header = UILabel()
    private let subheader = UILabel()
    private let separator = UIView()
    private let icon: UIView
    private let iconSize: CGFloat = 96.0
    private let separatorYOffset: CGFloat = 48.0

    init(type: AlertType) {
        self.type = type
        self.icon = type.icon

        super.init(frame: .zero)
        layer.cornerRadius = 6.0
        layer.masksToBounds = true
        setupSubviews()
    }

    func animate() {
        guard let animatableIcon = icon as? AnimatableIcon else { return }
        animatableIcon.animate()
    }

    private func setupSubviews() {
        addSubview(header)
        addSubview(subheader)
        addSubview(icon)
        addSubview(separator)

        setData()
        addConstraints()
    }

    private func setData() {
        header.text = type.header
        header.textAlignment = .center
        header.font = UIFont.customBold(size: 14.0)
        header.textColor = .white

        icon.backgroundColor = .clear
        separator.backgroundColor = UIColor(white: 1.0, alpha: 0.3)

        subheader.text = type.subheader
        subheader.textAlignment = .center
        subheader.font = UIFont.customBody(size: 14.0)
        subheader.textColor = .white
    }

    private func addConstraints() {

        //NB - In this alert view, constraints shouldn't be pinned to the bottom
        //of the view because the bottom actually extends off the bottom of the screen a bit.
        //It extends so that it still covers up the underlying view when it bounces on screen.

        header.constrainTopCorners(sidePadding: C.padding[2], topPadding: C.padding[2])
        separator.constrain([
            separator.constraint(.height, constant: 1.0),
            separator.constraint(.width, toView: self, constant: 0.0),
            separator.constraint(.top, toView: self, constant: separatorYOffset),
            separator.constraint(.leading, toView: self, constant: nil) ])
        icon.constrain([
            icon.constraint(.centerX, toView: self, constant: nil),
            icon.constraint(.centerY, toView: self, constant: nil),
            icon.constraint(.width, constant: iconSize),
            icon.constraint(.height, constant: iconSize) ])
        subheader.constrain([
            subheader.constraint(.leading, toView: self, constant: C.padding[2]),
            subheader.constraint(.trailing, toView: self, constant: -C.padding[2]),
            subheader.constraint(toBottom: icon, constant: C.padding[3]) ])
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
