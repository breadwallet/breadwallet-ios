//
//  BuyCenterViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 9/23/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit
import LocalAuthentication

class BuyCenterHeader : UIView, GradientDrawable {
  override func draw(_ rect: CGRect) {
    drawGradient(rect)
  }
}

private let headerHeight: CGFloat = 120.0
private let fadeStart: CGFloat = 185.0
private let fadeEnd: CGFloat = 160.0


enum PartnerName : String {
  case simplex = "Simplex"
  case changelly = "Changelly"
}


class BuyCenterViewController : UIViewController, Subscriber, BuyPartnerCellDelegate {
 
  func didTapCell(partnerTitle: String) {
    
    switch partnerTitle {
      case "Simplex":
        presentPartnerPortal(partner: PartnerName.simplex)
      case "Changelly":
        presentPartnerPortal(partner: PartnerName.changelly)
      default:
        break
    }
    
  }
  
  init(store: Store, walletManager: WalletManager, mountPoint: String, bundleName: String?) {
    self.store = store
    self.walletManager = walletManager
    self.mountPoint = mountPoint
    self.bundleName = bundleName ?? ""
    self.header = ModalHeaderView(title: S.BuyCenter.title, style: .light, faqInfo: (store, ArticleIds.buyCenter))
    self.buyContainerView = UIView()
    self.placeholderview = UIView()
    super.init(nibName: nil, bundle: nil)
  }
  
  fileprivate var headerBackgroundHeight: NSLayoutConstraint?
  private let headerBackground = BuyCenterHeader()
  private let header: ModalHeaderView
  private let buyContainerView: UIView
  private var placeholderview: UIView
  private let scrollView = UIScrollView()
  private let simplexCell = BuyPartnerCell(partnerTitle: S.BuyCenter.Cells.simplexTitle, financialDetailsText: S.BuyCenter.Cells.simplexFinancialDetails, logo: UIImage(named: "subduedSimplexLogo")!)
  fileprivate let litecoinLogo = UIImageView(image:#imageLiteral(resourceName: "litecoinLogo"))
 
  private let separator = UIView(color: .secondaryShadow)
  private let store: Store
  private let walletManager: WalletManager
  private let mountPoint: String
  private let bundleName: String
  fileprivate var didViewAppear = false
  
  deinit {
    store.unsubscribe(self)
  }

  override func viewDidLoad() {
    setupSubviewProperties()
    addSubviews()
    addConstraints()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    didViewAppear = false
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    didViewAppear = true
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    didViewAppear = false
  }
  
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  private func setupSubviewProperties() {
    view.backgroundColor = .white
    headerBackgroundHeight?.constant = headerHeight
    header.closeCallback = {
      self.dismiss(animated: true, completion: nil)
    }
    header.backgroundColor = .clear
    litecoinLogo.bounds = CGRect(x: 0, y: 0, width: 60, height: 60)
    self.simplexCell.delegate = self

  }
  
  private func presentPartnerPortal(partner:PartnerName) {
    
     //add childViewController
    let webViewController = BRWebViewController(partner: partner.rawValue, bundleName: self.bundleName, mountPoint: self.mountPoint, walletManager: self.walletManager, store: self.store)
    
      addChildViewController(webViewController)
      placeholderview = webViewController.view
    self.buyContainerView.addSubview(self.placeholderview)

    placeholderview.constrain([
      placeholderview.leadingAnchor.constraint(equalTo: buyContainerView.leadingAnchor),
      placeholderview.topAnchor.constraint(equalTo: buyContainerView.topAnchor),
      placeholderview.trailingAnchor.constraint(equalTo: buyContainerView.trailingAnchor),
      placeholderview.bottomAnchor.constraint(equalTo: buyContainerView.bottomAnchor)])
    simplexCell.removeFromSuperview()
  }
  
  private func resetPartnerPortal() {
    self.buyContainerView.addSubview(self.simplexCell)

    simplexCell.constrain([
      simplexCell.leadingAnchor.constraint(equalTo: buyContainerView.leadingAnchor),
      simplexCell.topAnchor.constraint(equalTo: buyContainerView.topAnchor),
      simplexCell.trailingAnchor.constraint(equalTo: buyContainerView.trailingAnchor)])
  }

  private func addSubviews() {
    buyContainerView.addSubview(simplexCell)
    view.addSubview(headerBackground)
    view.addSubview(buyContainerView)
    headerBackground.addSubview(header)
    headerBackground.addSubview(litecoinLogo)
  }
  
  private func addConstraints() {
    headerBackground.constrain([
      headerBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      headerBackground.topAnchor.constraint(equalTo: view.topAnchor),
      headerBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
    headerBackgroundHeight = headerBackground.heightAnchor.constraint(equalToConstant: headerHeight)
    headerBackground.constrain([headerBackgroundHeight])
    header.constrain([
      header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      header.topAnchor.constraint(equalTo: headerBackground.topAnchor, constant: E.isIPhoneX ? 30.0 : 20.0),
      header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      header.heightAnchor.constraint(equalToConstant: C.Sizes.headerHeight)])
    litecoinLogo.constrain([
      litecoinLogo.widthAnchor.constraint(equalToConstant: 40),
      litecoinLogo.heightAnchor.constraint(equalToConstant: 40),
      litecoinLogo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      litecoinLogo.centerYAnchor.constraint(equalTo: headerBackground.centerYAnchor, constant: C.padding[3]) ])
    buyContainerView.constrain([
      buyContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      buyContainerView.topAnchor.constraint(equalTo: headerBackground.bottomAnchor),
      buyContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      buyContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
    simplexCell.constrain([
      simplexCell.leadingAnchor.constraint(equalTo: buyContainerView.leadingAnchor),
      simplexCell.topAnchor.constraint(equalTo: buyContainerView.topAnchor),
      simplexCell.trailingAnchor.constraint(equalTo: buyContainerView.trailingAnchor) ])
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
}

