//
//  BuyCenterTableViewCell.swift
//  breadwallet
//
//  Created by Kerry Washington on 9/30/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit


protocol BuyCenterTableViewCellDelegate : class {
  func didClickPartnerCell(partner: String)
}

class BuyCenterTableViewCell : UITableViewCell {
  
  private let colorFrameView = UIView()
  private let selectButton = UIButton()
  
  var logoImageView = UIImageView()
  var partnerLabel = UILabel()
  var financialDetailsLabel = UILabel()
  var frameView = UIView()
  weak var delegate : BuyCenterTableViewCellDelegate?
  
  override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    self.selectionStyle = .none
    self.backgroundColor = UIColor.clear
    configureViews()
    layoutCustomViews()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  
  func configureViews() {
    
    self.addSubview(frameView)
    frameView.addSubview(colorFrameView)
    colorFrameView.addSubview(logoImageView)
    frameView.addSubview(partnerLabel)
    frameView.addSubview(financialDetailsLabel)
    frameView.addSubview(selectButton)
    
    frameView.translatesAutoresizingMaskIntoConstraints = false
    frameView.layer.cornerRadius = 5
    frameView.clipsToBounds = true
    
    colorFrameView.backgroundColor = UIColor.white
    
    logoImageView.translatesAutoresizingMaskIntoConstraints = false
    logoImageView.contentMode = .scaleAspectFit
    
    partnerLabel.translatesAutoresizingMaskIntoConstraints = false
    partnerLabel.font = UIFont.customBold(size: 20)
    partnerLabel.textColor = UIColor.white
    
    financialDetailsLabel.translatesAutoresizingMaskIntoConstraints = false
    financialDetailsLabel.font = UIFont.customMedium(size: 13)
    financialDetailsLabel.textColor = UIColor.white
    financialDetailsLabel.textAlignment = .left
    financialDetailsLabel.numberOfLines = 0
    financialDetailsLabel.lineBreakMode = .byWordWrapping
    
    selectButton.setImage(#imageLiteral(resourceName: "whiteRightArrow"), for: .normal)
    selectButton.imageView?.contentMode = .scaleAspectFit
    selectButton.imageEdgeInsets = UIEdgeInsetsMake(20, 10, 20, 8)
    selectButton.addTarget(self, action: #selector(selectButtonPressed), for: .touchUpInside)
    
  }
  
  func layoutCustomViews() {
    let margins = self.layoutMarginsGuide
    
    frameView.constrain([
      frameView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 2),
      frameView.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: -5),
      frameView.topAnchor.constraint(equalTo: margins.topAnchor, constant: 10),
      frameView.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: 10)
      ])
    
    colorFrameView.constrain([
      colorFrameView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
      colorFrameView.widthAnchor.constraint(equalToConstant: 80),
      colorFrameView.topAnchor.constraint(equalTo: frameView.topAnchor),
      colorFrameView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor)
      ])
    
    logoImageView.constrain([
      logoImageView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 8),
      logoImageView.trailingAnchor.constraint(equalTo: colorFrameView.trailingAnchor, constant: -8),
      logoImageView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),
      logoImageView.centerYAnchor.constraint(equalTo: frameView.centerYAnchor)
      ])
    
    partnerLabel.constrain([
      partnerLabel.leadingAnchor.constraint(equalTo: colorFrameView.trailingAnchor, constant: 10),
      partnerLabel.widthAnchor.constraint(equalToConstant: 160),
      partnerLabel.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 10),
      partnerLabel.heightAnchor.constraint(equalToConstant: 25)
      ])
    
    financialDetailsLabel.constrain([
      financialDetailsLabel.leadingAnchor.constraint(equalTo: colorFrameView.trailingAnchor, constant: 10),
      financialDetailsLabel.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
      financialDetailsLabel.topAnchor.constraint(equalTo: partnerLabel.bottomAnchor),
      financialDetailsLabel.heightAnchor.constraint(equalToConstant: 80)
      ])
    
    selectButton.constrain([
      selectButton.widthAnchor.constraint(equalToConstant: 40),
      selectButton.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
      selectButton.topAnchor.constraint(equalTo: frameView.topAnchor),
      selectButton.bottomAnchor.constraint(equalTo: frameView.bottomAnchor)
      ])
    
  }
  
  @objc func selectButtonPressed(selector: UIButton) {
    if let partner = partnerLabel.text {
      delegate?.didClickPartnerCell(partner: partner)
    }
  }
  
  
}

