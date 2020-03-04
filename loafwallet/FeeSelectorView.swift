//
//  FeeSelectorView.swift
//  loafwallet
//
//  Created by Kerry Washington on 3/4/20.
//  Copyright © 2020 Litecoin Foundation. All rights reserved.
//

import Foundation
import UIKit


class FeeSelector : UIView {

    init(store: Store) {
        self.store = store
        super.init(frame: .zero)
        setupViews()
    }

    var didUpdateFee: ((FeeType) -> Void)?

    func removeIntrinsicSize() {
        guard let bottomConstraint = bottomConstraint else { return }
        NSLayoutConstraint.deactivate([bottomConstraint])
    }

    func addIntrinsicSize() {
        guard let bottomConstraint = bottomConstraint else { return }
        NSLayoutConstraint.activate([bottomConstraint])
    }

    private let store: Store
    private let header = UILabel(font: .barlowMedium(size: 16.0), color: .darkText)
    private let subheader = UILabel(font: .barlowRegular(size: 14.0), color: .grayTextTint)
    private let feeMessageLabel = UILabel.wrapping(font: .barlowSemiBold(size: 14.0), color: .red)
    private let control = UISegmentedControl(items: [S.FeeSelector.regular, S.FeeSelector.economy, S.FeeSelector.luxury])
    private var bottomConstraint: NSLayoutConstraint?

    private func setupViews() {
        addSubview(control)
        addSubview(header)
        addSubview(subheader)
        addSubview(feeMessageLabel)
        
        control.tintColor = .liteWalletBlue
        
        header.constrain([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            header.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[1]) ])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subheader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            subheader.topAnchor.constraint(equalTo: header.bottomAnchor) ])

        bottomConstraint = feeMessageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1])
        feeMessageLabel.constrain([
            feeMessageLabel.leadingAnchor.constraint(equalTo: subheader.leadingAnchor),
            feeMessageLabel.topAnchor.constraint(equalTo: control.bottomAnchor, constant: 4.0),
            feeMessageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]) ])
        header.text = S.FeeSelector.title
        subheader.text = S.FeeSelector.regularLabel
        control.constrain([
            control.leadingAnchor.constraint(equalTo: feeMessageLabel.leadingAnchor),
            control.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: 4.0),
            control.widthAnchor.constraint(equalTo: widthAnchor, constant: -C.padding[4]) ])

        control.valueChanged = strongify(self) { myself in
            
            switch myself.control.selectedSegmentIndex {
            case 0:
                myself.didUpdateFee?(.regular)
                myself.subheader.text = S.FeeSelector.regularLabel
                myself.feeMessageLabel.text = ""
            case 1:
                myself.didUpdateFee?(.economy)
                myself.subheader.text = S.FeeSelector.economyLabel
                myself.feeMessageLabel.text = S.FeeSelector.economyWarning
                myself.feeMessageLabel.textColor = .red
            case 2:
                myself.didUpdateFee?(.luxury)
                myself.subheader.text = S.FeeSelector.luxuryLabel
                myself.feeMessageLabel.text = S.FeeSelector.luxuryMessage
                myself.feeMessageLabel.textColor = .grayTextTint
            default:
                myself.didUpdateFee?(.regular)
                myself.subheader.text = S.FeeSelector.regularLabel
                myself.feeMessageLabel.text = ""
                LWAnalytics.logEventWithParameters(itemName: ._20200112_ERR, properties: ["FEE_MANAGER":"DID_USE_DEFAULT"])
            }
        }

        control.selectedSegmentIndex = 0
        clipsToBounds = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
