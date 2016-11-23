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

    let type: AlertType
    let header = UILabel()
    let subheader = UILabel()
    var icon: UIView

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

        header.constrainTopCorners(sidePadding: C.padding[2], topPadding: C.padding[4])

        header.text = type.header
        header.textAlignment = .center
        header.font = UIFont.customBold(size: 14.0)
        header.textColor = .white

        icon.backgroundColor = .clear
        icon.constrain([
                icon.constraint(.centerX, toView: self, constant: nil),
                icon.constraint(.centerY, toView: self, constant: nil),
                icon.constraint(.width, constant: 96.0),
                icon.constraint(.height, constant: 96.0)
            ])
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
