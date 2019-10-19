//
//  DonationCell.swift
//  loafwallet
//
//  Created by Kerry Washington on 10/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation
import  UIKit

class DonationCell: UIView {
    
    static let defaultHeight: CGFloat = 72.0

    init(store: Store, wantsToDonate: Bool, didSwitchToDonate: @escaping () -> Void) {
       self.store = store
       self.didSwitchToDonate = didSwitchToDonate
       self.donationSwitch.isOn = wantsToDonate
       super.init(frame: .zero)
        setupViews()
    }
    
    let border = UIView(color: .secondaryShadow)
    private var wantsToDonate = true
    private var titleLabel = UILabel(font: .customBody(size: 16.0), color: .grayTextTint)
    private var descriptionLabel = UILabel(font: .customBody(size: 14.0), color: .darkText)
    private var donationAmountLabel = UILabel(font: .customBody(size: 15.0), color: .darkText)

    var donationSwitch = UISwitch()
    private let didSwitchToDonate: () -> Void
    private let store: Store

    private func setupViews() {
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(donationAmountLabel)
        addSubview(donationSwitch)
        addSubview(border)
        
        descriptionLabel.numberOfLines = 0
        donationAmountLabel.textAlignment = .center
        donationAmountLabel.numberOfLines = 0
        donationAmountLabel.lineBreakMode = .byWordWrapping
        donationSwitch.onTintColor = .primaryButton
        titleLabel.text = S.Donate.title
        descriptionLabel.text = S.Donate.message
        donationSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        
        if let rate = store.state.currentRate {
            self.donationAmountLabel.text = "0.009 Ł"
        }
          
        titleLabel.constrain([
            titleLabel.constraint(.leading, toView: self, constant: C.padding[2]),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 50.0)])
        
        donationSwitch.constrain([
        donationSwitch.centerYAnchor.constraint(equalTo: centerYAnchor),
        donationSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2])])
        
        descriptionLabel.constrain([
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 5.0),
            descriptionLabel.topAnchor.constraint(equalTo: topAnchor, constant:  5.0),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant:  -5.0),
            descriptionLabel.trailingAnchor.constraint(equalTo: donationAmountLabel.leadingAnchor, constant: -10)])
        donationAmountLabel.constrain([
            donationAmountLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0.0 ),
            donationAmountLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0.0 ),
            donationAmountLabel.widthAnchor.constraint(equalToConstant: 70.0),
            donationAmountLabel.trailingAnchor.constraint(equalTo: donationSwitch.leadingAnchor, constant: 0.0)])
        border.constrainBottomCorners(height: 1.0)
    }
    
    
    @objc func switchChanged() {
        
        if self.donationSwitch.isOn {
            self.donationAmountLabel.textColor = .darkText
            wantsToDonate = true
        } else {
           self.donationAmountLabel.textColor = .grayTextTint
            wantsToDonate = false
        }
    }
    
//    private func updateAmountLabel() {
//        guard let amount = amount else { amountLabel.text = ""; return }
//        let displayAmount = DisplayAmount(amount: amount, state: store.state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
//        var output = displayAmount.description
//        if hasTrailingDecimal {
//            output = output.appending(NumberFormatter().currencyDecimalSeparator)
//        }
//        amountLabel.text = output
//        placeholder.isHidden = output.utf8.count > 0 ? true : false
//    }
//
//    func updateBalanceLabel() {
//        if let (balance, fee) = balanceTextForAmount?(amount, selectedRate) {
//            balanceLabel.attributedText = balance
//            feeLabel.attributedText = fee
//            if let amount = amount, amount > 0, !isRequesting {
//                editFee.isHidden = false
//            } else {
//                editFee.isHidden = true
//            }
//            balanceLabel.isHidden = cursor.isHidden
//        }
//    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
 
