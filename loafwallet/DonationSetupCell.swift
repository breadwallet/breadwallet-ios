//
//  DonationSetupCell.swift
//  loafwallet
//
//  Created by Kerry Washington on 10/22/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation
import  UIKit

class DonationSetupCell: UIView {
    
    static let defaultHeight: CGFloat = 72.0

    init(store: Store, wantsToDonate: Bool) {
       self.store = store
       var buttonText = ""
        
        if let rate  = store.state.currentRate, store.state.isLtcSwapped {
            buttonText = String(format:"%.2f", rate.rate * kDonationAmountInDouble) + " \(rate.code)(\(rate.currencySymbol))"
        } else {
            buttonText = "\(kDonationAmountInDouble) "  + S.Symbols.currencyButtonTitle(maxDigits: store.state.maxDigits)
        }
         
        donateButton = ShadowButton(title: buttonText, type: .tertiary)
 
       super.init(frame: .zero)
       setupViews()
    }
    
    let border = UIView(color: .secondaryShadow)
    private var titleLabel = UILabel(font: .customBody(size: 16.0), color: .grayTextTint)
    var isLTCSwapped: Bool?
    var donateButton: ShadowButton?
    var didTapToDonate:(() -> ())?
    private let store: Store

    private func setupViews() {
        
        guard  let donateButton = donateButton else {
            NSLog("ERROR: Donate button not initialized")
            return
        }
         
        addSubview(titleLabel)
        addSubview(donateButton)
        addSubview(border)
         
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 2
        donateButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = S.Donate.title
 
         donateButton.addTarget(self, action: #selector(donateToLF), for: .touchUpInside)
        let viewsDictionary = ["titleLabel": titleLabel, "donateButton": donateButton, "border": border]
        var viewConstraints = [NSLayoutConstraint]()
    
        let constraintsHorizontal = NSLayoutConstraint.constraints(withVisualFormat: "H:|-16-[titleLabel]-(2)-[donateButton(120)]-16-|", options: [], metrics: nil, views: viewsDictionary)
        viewConstraints += constraintsHorizontal
          
        let titleConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[titleLabel]-10-|", options: [], metrics: nil, views: viewsDictionary)

        viewConstraints += titleConstraintVertical
        
        let descriptionConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-16-[donateButton]-16-|", options: [], metrics: nil, views: viewsDictionary)

        viewConstraints += descriptionConstraintVertical
            
        border.constrainBottomCorners(height: 1.0)

         NSLayoutConstraint.activate(viewConstraints)
    }
     
    @objc func donateToLF() {
        self.didTapToDonate?()
    }
     
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
 
