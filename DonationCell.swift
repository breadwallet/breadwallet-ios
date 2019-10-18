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
    
    static let defaultHeight: CGFloat = 55.0

    init() {
       super.init(frame: .zero)
        setupViews()
    }
    
    let border = UIView(color: .secondaryShadow)
    private var didWantToDonate = true
    private var titleLabel = UILabel(font: .customBody(size: 16.0), color: .grayTextTint)
    private var descriptionLabel = UILabel(font: .customBody(size: 13.0), color: .darkText)
    private var donationAmountLabel = UILabel(font: .customBody(size: 13.0), color: .grayTextTint)

    private var donationSwitch = UISwitch()
      
    
    private func setupViews() {
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(donationAmountLabel)
        addSubview(donationSwitch)
        addSubview(border)
        
        descriptionLabel.numberOfLines = 0
        
        titleLabel.text = S.Donate.title
        descriptionLabel.text = S.Donate.message
        donationAmountLabel.text = "$0.25 / 0.0004Ł"
        titleLabel.constrain([
            titleLabel.constraint(.leading, toView: self, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]),
            titleLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30.0),
            titleLabel.widthAnchor.constraint(equalToConstant: 50.0)])
        descriptionLabel.constrain([
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: topAnchor, constant:  C.padding[1]),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[1]),
            descriptionLabel.widthAnchor.constraint(equalToConstant: 200.0)])
        donationAmountLabel.constrain([
            donationAmountLabel.leadingAnchor.constraint(equalTo: descriptionLabel.trailingAnchor),
            donationAmountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            donationAmountLabel.trailingAnchor.constraint(equalTo: donationSwitch.leadingAnchor)])
        
        donationSwitch.constrain([
                  donationSwitch.leadingAnchor.constraint(equalTo: donationAmountLabel.trailingAnchor),
                  donationSwitch.centerYAnchor.constraint(equalTo: centerYAnchor),
                  donationSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[4])])
        border.constrainBottomCorners(height: 1.0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
 
