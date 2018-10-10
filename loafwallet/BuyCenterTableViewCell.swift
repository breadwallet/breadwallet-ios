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
  private let selectImage = UIImageView()
  private let cellButton = UIButton()

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
    frameView.addSubview(selectImage)
    frameView.addSubview(cellButton)
    
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
    financialDetailsLabel.font = UIFont.customBody(size: 14)
    financialDetailsLabel.textColor = UIColor.white
    financialDetailsLabel.textAlignment = .left
    financialDetailsLabel.numberOfLines = 0
    financialDetailsLabel.lineBreakMode = .byWordWrapping
    
    selectImage.image = #imageLiteral(resourceName: "whiteRightArrow")
    selectImage.contentMode = .scaleAspectFit
    
    cellButton.setTitle(" ", for: .normal)
    cellButton.addTarget(self, action: #selector(cellButtonPressed), for: .touchUpInside)
    cellButton.addTarget(self, action: #selector(cellButtonImageChanged), for: .touchDown)
    cellButton.addTarget(self, action: #selector(cellButtonImageChanged), for: .touchUpOutside)

  }
  
  func layoutCustomViews() {
    let margins = self.layoutMarginsGuide
    
    frameView.constrain([
      frameView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: -3),
      frameView.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: 3),
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
      partnerLabel.heightAnchor.constraint(equalToConstant: 24)
      ])
    
    financialDetailsLabel.constrain([
      financialDetailsLabel.leadingAnchor.constraint(equalTo: colorFrameView.trailingAnchor, constant: 10),
      financialDetailsLabel.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
      financialDetailsLabel.topAnchor.constraint(equalTo: partnerLabel.bottomAnchor),
      financialDetailsLabel.heightAnchor.constraint(equalToConstant: 80)
      ])
    
    selectImage.constrain([
      selectImage.widthAnchor.constraint(equalToConstant: 18),
      selectImage.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant:-3),
      selectImage.heightAnchor.constraint(equalToConstant: 18),
      selectImage.centerYAnchor.constraint(equalTo: frameView.centerYAnchor)
      ])
    
    cellButton.constrain([
      cellButton.widthAnchor.constraint(equalTo: frameView.widthAnchor),
      cellButton.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
      cellButton.topAnchor.constraint(equalTo: frameView.topAnchor),
      cellButton.bottomAnchor.constraint(equalTo: frameView.bottomAnchor)
      ])
  }
  
  @objc func cellButtonPressed(selector: UIButton) {
    selectImage.image = #imageLiteral(resourceName: "whiteRightArrow")
    if let partnerName = partnerLabel.text {
      delegate?.didClickPartnerCell(partner: partnerName)
    }
  }
  
  @objc func cellButtonImageChanged(selector: UIButton) {
    selectImage.image = #imageLiteral(resourceName: "simplexRightArrow")
  }
  
  
  
}

