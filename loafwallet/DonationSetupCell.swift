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
       donateButton = ShadowButton(title: S.Donate.title, type: .tertiary)
       super.init(frame: .zero)
       setupViews()
    }
    
    let border = UIView(color: .secondaryShadow)
    var isLTCSwapped: Bool?
    var donateButton: ShadowButton?
    var didTapToDonate:(() -> ())?
    private let store: Store

    private func setupViews() {
        
        guard  let donateButton = donateButton else {
            NSLog("ERROR: Donate button not initialized")
            return
        }
        addSubview(donateButton)
        addSubview(border)
        donateButton.translatesAutoresizingMaskIntoConstraints = false
        donateButton.addTarget(self, action: #selector(donateToLF), for: .touchUpInside)
        let viewsDictionary = ["donateButton": donateButton, "border": border]
        var viewConstraints = [NSLayoutConstraint]()
    
        let constraintsHorizontal = NSLayoutConstraint.constraints(withVisualFormat: "H:|-30-[donateButton(180)]-30-|", options: [], metrics: nil, views: viewsDictionary)
        viewConstraints += constraintsHorizontal
        
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
 
