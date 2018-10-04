//
//  BuyCenterHeaderView.swift
//  breadwallet
//
//  Created by Kerry Washington on 9/30/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit

class BuyCenterHeader : UIView, GradientDrawable {
  override func draw(_ rect: CGRect) {
    drawGradient(rect)
  }
}

class BuyCenterHeaderView : UIView {
  
  private let header = BuyCenterHeader()
  private let titleLabel = UILabel()
  private let currentPriceLabel = UILabel()
  private let dismissButton = UIButton.close
  private let buttonSize: CGFloat = 44.0
  
  var closeCallback: (() -> Void)? {
    didSet { dismissButton.tap = closeCallback }
  }
  
  init(frame: CGRect, height: CGFloat) {

    super.init(frame: frame)
    header.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: height)
    configureViews()
    layoutCustomViews()
    
   // , constant: E.isIPhoneX ? 0 : 0.0
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func configureViews() {
    self.addSubview(header)
    header.addSubview(titleLabel)
    header.addSubview(currentPriceLabel)
    header.addSubview(dismissButton)
    
    header.translatesAutoresizingMaskIntoConstraints = false
    
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.font = UIFont.customBold(size: 30)
    titleLabel.text = S.BuyCenter.title
    titleLabel.textColor = UIColor.white
    
    currentPriceLabel.translatesAutoresizingMaskIntoConstraints = false
    currentPriceLabel.font = UIFont.customBody(size: 18)
    
    dismissButton.translatesAutoresizingMaskIntoConstraints = false
    dismissButton.setImage(#imageLiteral(resourceName: "Close"), for: .normal)
    dismissButton.imageView?.contentMode = .scaleAspectFit
    dismissButton.tintColor = UIColor.white
  }
  
  private func layoutCustomViews() {
    
    header.constrain([
      header.leadingAnchor.constraint(equalTo: self.leadingAnchor),
      header.trailingAnchor.constraint(equalTo: self.trailingAnchor),
      header.topAnchor.constraint(equalTo: self.topAnchor, constant: E.isIPhoneX ? -45 : -20.0),
      header.bottomAnchor.constraint(equalTo: self.bottomAnchor)
      ])
 
    titleLabel.constrain([
      titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 15),
      titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor),
      titleLabel.heightAnchor.constraint(equalToConstant: 50),
      titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -20)
      ])
    
    currentPriceLabel.constrain([
      currentPriceLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
      currentPriceLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor),
      currentPriceLabel.heightAnchor.constraint(equalToConstant: 40),
      currentPriceLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 30)
      ])
    
    dismissButton.constrain([
      dismissButton.leadingAnchor.constraint(equalTo: header.leadingAnchor),
      dismissButton.widthAnchor.constraint(equalToConstant: buttonSize),
      dismissButton.heightAnchor.constraint(equalToConstant: buttonSize),
      dismissButton.topAnchor.constraint(equalTo: header.topAnchor, constant: E.isIPhoneX ? 45 : 20)
      ])
  }
}
