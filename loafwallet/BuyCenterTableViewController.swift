//
//  BuyCenterTableViewController.swift
//  breadwallet
//
//  Created by Kerry Washington on 9/27/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

//let buyCellReuseIdentifier = "buyCell"

//class BuyCenterTableViewController: UITableViewController, BuyCenterTableViewCellDelegate {
//
//    fileprivate let litecoinLogo = UIImageView(image:#imageLiteral(resourceName: "litecoinLogo"))
//    private let store: Store
//    private let walletManager: WalletManager
//    private let mountPoint: String
//    private let partnerArray = Partner.dataArray()
//    private let headerHeight : CGFloat = 140
//
//    init(store: Store, walletManager: WalletManager, mountPoint: String) {
//      self.store = store
//      self.walletManager = walletManager
//      self.mountPoint = mountPoint
//      super.init(nibName: nil, bundle: nil)
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//      fatalError("init(coder:) has not been implemented")
//    }
//
//    override func viewDidLoad() {
//      super.viewDidLoad()
//      self.tableView.separatorColor = UIColor.clear
//      self.tableView.dataSource = self
//      self.tableView.delegate = self
//      self.tableView.register(BuyCenterTableViewCell.self, forCellReuseIdentifier: buyCellReuseIdentifier)
//      self.tableView.backgroundColor = #colorLiteral(red: 0.9529411765, green: 0.9529411765, blue: 0.9529411765, alpha: 1) // #colorLiteral(red: 0.9411764706, green: 0.9411764706, blue: 0.9411764706, alpha: 1)
//      self.clearsSelectionOnViewWillAppear = false
//      Mixpanel.mainInstance().track(event: K.MixpanelEvents._20191105_DTBT.rawValue, properties: nil)
//    }
//
//    override func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Dispose of any resources that can be recreated.
//    }
//
//    override var preferredStatusBarStyle: UIStatusBarStyle {
//      return .lightContent
//    }
//
//    // MARK: - Table view data source
//    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return 150 }
//
//    override func numberOfSections(in tableView: UITableView) -> Int { return 1 }
//
//    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { return partnerArray.count }
//
//    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//
//      let fr = CGRect(x: 0, y: 0, width: self.view.frame.width, height: headerHeight)
//      let buyCenterHeaderView = BuyCenterHeaderView(frame: fr, height: headerHeight)
//       buyCenterHeaderView.closeCallback = {
//        self.dismiss(animated: true, completion: nil)
//       }
//      return buyCenterHeaderView
//    }
//
//    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { return headerHeight }
//
//    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//      let cell = tableView.dequeueReusableCell(withIdentifier: buyCellReuseIdentifier, for: indexPath) as! BuyCenterTableViewCell
//      let partnerData = partnerArray[indexPath.row]
//        cell.partnerLabel.text = partnerData["title"] as? String
//
//        if let details = partnerData["details"] as? String,
//            let color = partnerData["baseColor"] as? UIColor {
//                cell.financialDetailsLabel.text = details
//                cell.frameView.backgroundColor = color
//        } else {
//                NSLog("ERROR: Unable to retrieve partner details")
//        }
//
//        cell.logoImageView.image = partnerData["logo"] as? UIImage
//
//        cell.delegate = self
//
//     return cell
//    }
//
//  func didClickPartnerCell(partner: String) {
//
//    switch partner {
//      case "Simplex":
//        let simplexWebviewVC = BRWebViewController(partner: "Simplex", mountPoint: mountPoint + "_simplex", walletManager: walletManager, store: store, noAuthApiClient: nil)
//         present(simplexWebviewVC, animated: true
//        , completion: nil)
//      case "Changelly":
//        print("Changelly No Code Placeholder")
//      case "Coinbase":
//        let coinbaseWebViewWC = BRWebViewController(partner: "Coinbase", mountPoint: mountPoint + "_coinbase", walletManager: walletManager, store: store, noAuthApiClient: nil)
//        present(coinbaseWebViewWC, animated: true) {
//          //
//       }
//      default:
//        fatalError("No Partner Chosen")
//    }
//  }
//
//  @objc func dismissWebContainer() {
//    dismiss(animated: true, completion: nil)
//  }
//}


//extension BuyCenterTableViewController: ModalDisplayable {
  
//  var faqArticleId: String? {
//    return nil
//  }
//
//  var modalTitle: String {
//    return S.BuyCenter.buyModalTitle
//  }
//}


