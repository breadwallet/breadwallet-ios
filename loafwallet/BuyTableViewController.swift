//
//  BuyTableViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 12/18/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import UIKit

class BuyTableViewController: UITableViewController {
    
    private var currencyCode: String = "USD"
 
    @IBAction func didTapSimplex(_ sender: Any) {
        
        if let vcWKVC = UIStoryboard.init(name: "Buy", bundle: nil).instantiateViewController(withIdentifier: "BuyWKWebViewController") as? BuyWKWebViewController {
            vcWKVC.partnerPrefixString = PartnerPrefix.simplex.rawValue
            vcWKVC.currencyCode = currencyCode
            addChildViewController(vcWKVC)
            self.view.addSubview(vcWKVC.view)
            vcWKVC.didMove(toParentViewController: self)
            
            vcWKVC.didDismissChildView = { [weak self] in
                guard self != nil else { return }
                vcWKVC.willMove(toParentViewController: nil)
                vcWKVC.view.removeFromSuperview()
                vcWKVC.removeFromParentViewController()
            }
        }  else {
            NSLog("ERROR: Storyboard not initialized")
        }
    }
    
    var store: Store?
    var walletManager: WalletManager?
    let mountPoint = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let thinHeaderView = UIView()
        thinHeaderView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 1.0)
        thinHeaderView.backgroundColor = .white
        tableView.tableHeaderView = thinHeaderView
        
        
        // TODO: Remove when Simplex or any partner is ready for operations
        let comingSoonLabel = UILabel()
        comingSoonLabel.textAlignment = .center
        comingSoonLabel.textColor = .white
        comingSoonLabel.font = UIFont.barlowBold(size: 20)
        comingSoonLabel.text = S.BuyCenter.comingSoon
        
        tableView.backgroundView = comingSoonLabel
        
        tableView.tableFooterView = UIView()
        
        LWAnalytics.logEventWithParameters(itemName: ._20191105_DTBT)
        setupData()
    }
    
    private func setupData() {
        
    }
    
    @objc private func didChangeCurrency() {
        
    }
}

