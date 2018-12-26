//
//  FeeSelector.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-07-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class FeeSelector: UIView {

    init() {
        super.init(frame: .zero)
        setupViews()
    }

    var didUpdateFee: ((FeeLevel) -> Void)?

    func removeIntrinsicSize() {
        guard let bottomConstraint = bottomConstraint else { return }
        NSLayoutConstraint.deactivate([bottomConstraint])
    }

    func addIntrinsicSize() {
        guard let bottomConstraint = bottomConstraint else { return }
        NSLayoutConstraint.activate([bottomConstraint])
    }

    private let header = UILabel(font: .customMedium(size: 16.0), color: .darkText)
    private let subheader = UILabel(font: .customBody(size: 14.0), color: .grayTextTint)
    private let warning = UILabel.wrapping(font: .customBody(size: 14.0), color: .red)
    private let control = UISegmentedControl(items: [S.FeeSelector.regular, S.FeeSelector.economy])
    private var bottomConstraint: NSLayoutConstraint?

    private func setupViews() {
        addSubview(control)
        addSubview(header)
        addSubview(subheader)
        addSubview(warning)

        header.constrain([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            header.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[1]) ])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subheader.topAnchor.constraint(equalTo: header.bottomAnchor) ])

        bottomConstraint = warning.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1])
        warning.constrain([
            warning.leadingAnchor.constraint(equalTo: subheader.leadingAnchor),
            warning.topAnchor.constraint(equalTo: control.bottomAnchor, constant: 4.0),
            warning.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]) ])
        header.text = S.FeeSelector.title
        subheader.text = String(format: S.FeeSelector.estimatedDelivery, S.FeeSelector.regularTime)
        control.constrain([
            control.leadingAnchor.constraint(equalTo: warning.leadingAnchor),
            control.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: 4.0),
            control.widthAnchor.constraint(equalTo: widthAnchor, constant: -C.padding[4]) ])

        control.valueChanged = strongify(self) { myself in
            if myself.control.selectedSegmentIndex == 0 {
                myself.didUpdateFee?(.regular)
                myself.subheader.text = String(format: S.FeeSelector.estimatedDelivery, S.FeeSelector.regularTime)
                myself.warning.text = ""
            } else {
                myself.didUpdateFee?(.economy)
                myself.subheader.text = String(format: S.FeeSelector.estimatedDelivery, S.FeeSelector.economyTime)
                myself.warning.text = S.FeeSelector.economyWarning
            }
        }

        control.selectedSegmentIndex = 0
        clipsToBounds = true

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
