//
//  BuyPartnerCell.swift
//  breadwallet
//
//  Created by Kerry Washington on 9/25/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

private let buttonSize: CGFloat = 25.0

protocol BuyPartnerCellDelegate: class {
  func didTapCell(partnerTitle:String)
}

class BuyPartnerCell : UIControl {
  
  
  init(partnerTitle: String, financialDetailsText: String, logo: UIImage) {
    super.init(frame: .zero)
    partnerLogo.image = logo
    self.partnerTitle = partnerTitle
    financialDetailsLabel.text = financialDetailsText
    selectButton.setImage(#imageLiteral(resourceName: "RightArrow"), for: .normal)
    selectButton.addTarget(self, action: #selector(BuyPartnerCell.didTapSelectButton(_:)), for: .touchUpInside)
    setup()
  }
 
 
  //MARK: - Private
  private func setup() {
    addSubview(financialDetailsLabel)
    addSubview(partnerLogo)
    addSubview(separator)
    addSubview(selectButton)
    financialDetailsLabel.constrain([
      financialDetailsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
      financialDetailsLabel.centerYAnchor.constraint(equalTo:centerYAnchor),
      financialDetailsLabel.widthAnchor.constraint(equalToConstant: 160),
      financialDetailsLabel.heightAnchor.constraint(equalToConstant: 30) ])
    partnerLogo.constrain([
      partnerLogo.leadingAnchor.constraint(equalTo:financialDetailsLabel.trailingAnchor, constant: 20),
      partnerLogo.centerYAnchor.constraint(equalTo:centerYAnchor),
      partnerLogo.widthAnchor.constraint(equalToConstant: 120),
      partnerLogo.heightAnchor.constraint(equalToConstant: 40)
      ])
    selectButton.constrain([
      selectButton.leadingAnchor.constraint(equalTo:partnerLogo.trailingAnchor, constant: 10),
      selectButton.centerYAnchor.constraint(equalTo:centerYAnchor),
      selectButton.widthAnchor.constraint(equalToConstant: buttonSize),
      selectButton.heightAnchor.constraint(equalToConstant: buttonSize)
      ])
    separator.constrain([
      separator.topAnchor.constraint(equalTo: financialDetailsLabel.bottomAnchor,constant: C.padding[3]),
      separator.leadingAnchor.constraint(equalTo: leadingAnchor),
      separator.trailingAnchor.constraint(equalTo: trailingAnchor),
      separator.heightAnchor.constraint(equalToConstant: 1.0),
      separator.bottomAnchor.constraint(equalTo: bottomAnchor) ])
    
    financialDetailsLabel.numberOfLines = 1
    financialDetailsLabel.lineBreakMode = .byWordWrapping
  }

  @objc func didTapSelectButton(_ sender: UIControl) {
    
    if let s = self.delegate {
      s.didTapCell(partnerTitle: self.partnerTitle)
    }
  }
  
  
  private let partnerLogo = UIImageView()
  private let financialDetailsLabel = UILabel(font: .customBody(size: 13.0))
  private let separator = UIView(color: .secondaryShadow)
  private let selectButton = UIButton(type: .custom)
  var partnerTitle : String = ""

  weak var delegate : BuyPartnerCellDelegate?
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}


