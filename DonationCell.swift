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

    init(store: Store, wantsToDonate: Bool) {
       self.store = store
       self.donationSwitch.isOn = wantsToDonate
          
        if let rate  = store.state.currentRate, store.state.isLtcSwapped {
            let donationAmount = rate.rate * 0.009
            self.donationAmountLabel.text = String(format:"%.2f", donationAmount) +  "\n\(rate.code) (\(rate.currencySymbol))"
        } else {
            self.donationAmountLabel.text = "0.009\n" + S.Symbols.currencyButtonTitle(maxDigits: store.state.maxDigits)
        }
             
       super.init(frame: .zero)
       setupViews()
    }
    
    let border = UIView(color: .secondaryShadow)
    private var wantsToDonate = true
    private var titleLabel = UILabel(font: .customBody(size: 16.0), color: .grayTextTint)
    private var descriptionLabel = UILabel(font: .customBody(size: 14.0), color: .darkText)
    var donationAmountLabel = UILabel(font: .customBody(size: 14.0), color: .darkText)
    var isLTCSwapped: Bool?
    var donationSwitch = UISwitch()
    var didSwitchToDonate: ((_ donationSwitchIsOn: Bool) -> ())?
    private let store: Store

    private func setupViews() {
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(donationAmountLabel)
        addSubview(donationSwitch)
        addSubview(border)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        donationAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        donationSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        descriptionLabel.numberOfLines = 0
        donationAmountLabel.textAlignment = .center
        donationAmountLabel.numberOfLines = 0
        donationAmountLabel.lineBreakMode = .byWordWrapping
        donationSwitch.onTintColor = .primaryButton
        titleLabel.text = S.Donate.title
        descriptionLabel.text = self.donationSwitch.isOn ? S.Donate.willDonateMessage : S.Donate.considerDonateMessage

        donationSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        
        
        let viewsDictionary = ["titleLabel": titleLabel, "descriptionLabel": descriptionLabel, "donationAmountLabel": donationAmountLabel, "donationSwitch": donationSwitch, "border": border]
        var viewConstraints = [NSLayoutConstraint]()
    
        let constraintsHorizontal = NSLayoutConstraint.constraints(withVisualFormat: "H:|-16-[titleLabel(50.0)]-5-[descriptionLabel(<=160)]-5-[donationAmountLabel(70)]-15-[donationSwitch]-5-|", options: [], metrics: nil, views: viewsDictionary)
        viewConstraints += constraintsHorizontal
         
        let titleConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[titleLabel]-10-|", options: [], metrics: nil, views: viewsDictionary)

        viewConstraints += titleConstraintVertical
        
        let descriptionConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-[descriptionLabel(60)]-|", options: [], metrics: nil, views: viewsDictionary)

        viewConstraints += descriptionConstraintVertical
        
        let amountConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[donationAmountLabel]-10-|", options: [], metrics: nil, views: viewsDictionary)

        viewConstraints += amountConstraintVertical
        
        let switchConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-19-[donationSwitch]-19-|", options: [.alignAllCenterY], metrics: nil, views: viewsDictionary)

        viewConstraints += switchConstraintVertical
        border.constrainBottomCorners(height: 1.0)

         NSLayoutConstraint.activate(viewConstraints)
//        titleLabel.constrain([
//            titleLabel.constraint(.leading, toView: self, constant: C.padding[2]),
//            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
//            titleLabel.widthAnchor.constraint(equalToConstant: 50.0)])
//
//        donationSwitch.constrain([
//        donationSwitch.centerYAnchor.constraint(equalTo: centerYAnchor),
//        donationSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2])])
//
//        descriptionLabel.constrain([
//            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 5.0),
//            descriptionLabel.topAnchor.constraint(equalTo: topAnchor, constant:  5.0),
//            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant:  -5.0),
//            descriptionLabel.trailingAnchor.constraint(equalTo: donationAmountLabel.leadingAnchor, constant: -10)])
//        donationAmountLabel.constrain([
//            donationAmountLabel.topAnchor.constraint(equalTo: topAnchor, constant: 0.0 ),
//            donationAmountLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0.0 ),
//            donationAmountLabel.widthAnchor.constraint(equalToConstant: 70.0),
//            donationAmountLabel.trailingAnchor.constraint(equalTo: donationSwitch.leadingAnchor, constant: 0.0)])
//        border.constrainBottomCorners(height: 1.0)
    }
    
    
    @objc func switchChanged() {
        
        if self.donationSwitch.isOn {
            self.donationAmountLabel.textColor = .darkText
            self.descriptionLabel.textColor = .darkText
            self.descriptionLabel.text = S.Donate.willDonateMessage
            wantsToDonate = true
        } else {
           self.donationAmountLabel.textColor = .grayTextTint
            self.descriptionLabel.textColor = .grayTextTint
            self.descriptionLabel.text = S.Donate.considerDonateMessage
            wantsToDonate = false
        }
        
        self.didSwitchToDonate?(wantsToDonate)

    }
     
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
 
