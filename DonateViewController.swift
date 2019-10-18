//
//  DonateViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 10/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation
import UIKit

class DonateViewController : UIViewController, Trackable {
    
    private let store: Store
  
    private let donationToggle = ShadowButton(title: S.Donate.title, type: .tertiary)
    private let border = UIView(color: .secondaryShadow)
    private let bottomBorder = UIView(color: .secondaryShadow)
    private let tapView = UIView()
    
    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }
 
    init(store: Store) {
        self.store = store
//        if let rate = store.state.currentRate, store.state.isLtcSwapped {
//            self.currencyToggle = ShadowButton(title: "\(rate.code) (\(rate.currencySymbol))", type: .tertiary)
//        } else {
//            self.currencyToggle = ShadowButton(title: S.Symbols.currencyButtonTitle(maxDigits: store.state.maxDigits), type: .tertiary)
//        }
         
        super.init(nibName: nil, bundle: nil)
    }
     
    private func addSubviews() {
        view.addSubview(donationToggle)
        view.addSubview(border)
        view.addSubview(tapView)
        view.addSubview(bottomBorder)
    }

    private func addConstraints() {
        
        donationToggle.constrain([
                   donationToggle.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[2]),
                   donationToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        
        border.constrain([
            border.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            border.topAnchor.constraint(equalTo: donationToggle.bottomAnchor, constant: C.padding[2]),
            border.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1.0) ])
    }

    private func setInitialData() {
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
