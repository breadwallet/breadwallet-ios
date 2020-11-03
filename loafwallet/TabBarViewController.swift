//
//  TabBarViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.

import UIKit
import Foundation 

enum TabViewControllerIndex: Int {
    case transactions = 0
    case send = 1
    case buy = 2
    case receive = 3
}
 
protocol MainTabBarControllerDelegate {
    func alertViewShouldDismiss()
}

class TabBarViewController: UIViewController, Subscriber, Trackable, UITabBarDelegate {
      
    let kInitialChildViewControllerIndex = 0 // TransactionsViewController
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var tabBar: UITabBar!
    @IBOutlet weak var currentLTCPriceLabel: UILabel!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var timeStampLabel: UILabel!
    @IBOutlet weak var timeStampStackView: UIStackView!
    @IBOutlet weak var timeStampStackViewHeight: NSLayoutConstraint!
    
    
    
    var primaryBalanceLabel: UpdatingLabel?
    var secondaryBalanceLabel: UpdatingLabel?
    private let largeFontSize: CGFloat = 24.0
    private let smallFontSize: CGFloat = 12.0
    private var hasInitialized = false
    private let dateFormatter = DateFormatter()
    private let equalsLabel = UILabel(font: .barlowMedium(size: 12), color: .whiteTint)
    private var regularConstraints: [NSLayoutConstraint] = []
    private var swappedConstraints: [NSLayoutConstraint] = []
    private let currencyTapView = UIView()
    private let storyboardNames:[String] = ["Transactions","Send","Receive","Buy"]
    var storyboardIDs:[String] = ["TransactionsViewController","SendLTCViewController","ReceiveLTCViewController","BuyTableViewController"]
    var viewControllers:[UIViewController] = []
    var activeController:UIViewController? = nil
    
    var delegate: MainTabBarControllerDelegate?
    
    var updateTimer: Timer?
    var store: Store?
    var walletManager: WalletManager?
    var exchangeRate: Rate? {
        didSet { setBalances() }
    }
    
    private var balance: UInt64 = 0 {
        didSet { setBalances() }
    }
    
    var isLtcSwapped: Bool? {
        didSet { setBalances() }
    }
    
    @IBAction func showSettingsAction(_ sender: Any) {
        guard let store = self.store else {
            NSLog("ERROR: Store not set")
            return
        }
        store.perform(action: RootModalActions.Present(modal: .menu))
    }
    
      
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        configurePriceLabels()
        addSubscriptions()
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
  
        for (index, storyboardID) in self.storyboardIDs.enumerated() {
            let controller = UIStoryboard.init(name: storyboardNames[index], bundle: nil).instantiateViewController(withIdentifier: storyboardID)
            viewControllers.append(controller)
        }
        
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { timer in
            self.setBalances()
        }
        
        guard let array = self.tabBar.items else {
            NSLog("ERROR: no items found")
            return
        }
        self.tabBar.selectedItem = array[kInitialChildViewControllerIndex]
    }
    
    deinit {
        self.updateTimer = nil
    }
    
    private func setupViews() {
        
       if #available(iOS 11.0, *),
            let  backgroundColor = UIColor(named: "mainColor") {
            headerView.backgroundColor = backgroundColor
            tabBar.barTintColor = backgroundColor
            containerView.backgroundColor = backgroundColor
            self.view.backgroundColor = backgroundColor
       } else {
            headerView.backgroundColor = .liteWalletBlue
            tabBar.barTintColor = .liteWalletBlue
            containerView.backgroundColor = .liteWalletBlue
            self.view.backgroundColor = .liteWalletBlue
       }
    }
    
    private func configurePriceLabels() {

        //TODO: Debug the reizing of label...very important
        guard let primaryLabel = self.primaryBalanceLabel ,
            let secondaryLabel = self.secondaryBalanceLabel else {
          NSLog("ERROR: Price labels not initialized")
                return
        }
         
        let priceLabelArray = [primaryBalanceLabel,secondaryBalanceLabel,equalsLabel]
        
        priceLabelArray.enumerated().forEach { (index, view) in
            view?.backgroundColor = .clear
            view?.textColor = .white
        }
 
        primaryLabel.font = UIFont.barlowSemiBold(size: largeFontSize)
        secondaryLabel.font = UIFont.barlowSemiBold(size: largeFontSize)
        
        equalsLabel.text = "="
        headerView.addSubview(primaryLabel)
        headerView.addSubview(secondaryLabel)
        headerView.addSubview(equalsLabel)
        headerView.addSubview(currencyTapView)
 
        secondaryLabel.constrain([
            secondaryLabel.constraint(.firstBaseline, toView: primaryLabel, constant: 0.0) ])

        equalsLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        regularConstraints = [
            primaryLabel.firstBaselineAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),
            primaryLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: C.padding[1]*1.25),
            equalsLabel.firstBaselineAnchor.constraint(equalTo: primaryLabel.firstBaselineAnchor, constant: 0),
            equalsLabel.leadingAnchor.constraint(equalTo: primaryLabel.trailingAnchor, constant: C.padding[1]/2.0),
            secondaryLabel.leadingAnchor.constraint(equalTo: equalsLabel.trailingAnchor, constant: C.padding[1]/2.0),
         ]
         
        swappedConstraints = [
            secondaryLabel.firstBaselineAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),
            secondaryLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: C.padding[1]*1.25),
            equalsLabel.firstBaselineAnchor.constraint(equalTo: secondaryLabel.firstBaselineAnchor, constant: 0),
            equalsLabel.leadingAnchor.constraint(equalTo: secondaryLabel.trailingAnchor, constant: C.padding[1]/2.0),
            primaryLabel.leadingAnchor.constraint(equalTo: equalsLabel.trailingAnchor, constant: C.padding[1]/2.0),
         ]
        
        if let isLTCSwapped = self.isLtcSwapped {
            NSLayoutConstraint.activate(isLTCSwapped ? self.swappedConstraints : self.regularConstraints)
        }
        
        currencyTapView.constrain([
                   currencyTapView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 0),
                   currencyTapView.trailingAnchor.constraint(equalTo: self.timeStampStackView.leadingAnchor, constant: 0),
                   currencyTapView.topAnchor.constraint(equalTo: primaryLabel.topAnchor, constant: 0),
                   currencyTapView.bottomAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: C.padding[1]) ])

         let gr = UITapGestureRecognizer(target: self, action: #selector(currencySwitchTapped))
         currencyTapView.addGestureRecognizer(gr)
    }
    
    private func addSubscriptions() {
        
        guard let store = self.store else {
            NSLog("ERROR - Store not passed")
            return
        }
        
        guard let primaryLabel = self.primaryBalanceLabel ,
            let secondaryLabel = self.secondaryBalanceLabel else {
          NSLog("ERROR: Price labels not initialized")
                return
        }
        
        store.subscribe(self, selector: { $0.walletState.syncProgress != $1.walletState.syncProgress },
                        callback: { _ in
                            self.tabBar.selectedItem = self.tabBar.items?.first
        })
 
        store.lazySubscribe(self,
                            selector: { $0.isLtcSwapped != $1.isLtcSwapped },
                            callback: { self.isLtcSwapped = $0.isLtcSwapped })
        store.lazySubscribe(self,
                            selector: { $0.currentRate != $1.currentRate},
                            callback: {
                                if let rate = $0.currentRate {
                                    let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: $0.maxDigits)
                                    secondaryLabel.formatter = placeholderAmount.localFormat
                                    primaryLabel.formatter = placeholderAmount.ltcFormat
                                    
                                }
                                self.exchangeRate = $0.currentRate
        })
        
        store.lazySubscribe(self,
                            selector: { $0.maxDigits != $1.maxDigits},
                            callback: {
                                if let rate = $0.currentRate {
                                    let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: $0.maxDigits)
                                    secondaryLabel.formatter = placeholderAmount.localFormat
                                    primaryLabel.formatter = placeholderAmount.ltcFormat
                                    self.setBalances()
                                }
        })
        
        store.subscribe(self,
                        selector: {$0.walletState.balance != $1.walletState.balance },
                        callback: { state in
                            if let balance = state.walletState.balance {
                                self.balance = balance
                                self.setBalances()
                            } })
    }
    
    private func setBalances() {
        guard let rate = exchangeRate, let store = self.store, let isLTCSwapped = self.isLtcSwapped else {
            NSLog("ERROR: Rate, Store not initialized")
            return
        }
        guard let primaryLabel = self.primaryBalanceLabel,
            let secondaryLabel = self.secondaryBalanceLabel else {
                NSLog("ERROR: Price labels not initialized")
                return
        }
         
        let amount = Amount(amount: balance, rate: rate, maxDigits: store.state.maxDigits)

        if !hasInitialized {
            let amount = Amount(amount: balance, rate: exchangeRate!, maxDigits: store.state.maxDigits)
            NSLayoutConstraint.deactivate(isLTCSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(isLTCSwapped ? self.swappedConstraints : self.regularConstraints)
            primaryLabel.setValue(amount.amountForLtcFormat)
            secondaryLabel.setValue(amount.localAmount)
            if isLTCSwapped {
                primaryLabel.transform = transform(forView: primaryLabel)
            } else {
                secondaryLabel.transform = transform(forView: secondaryLabel)
            }
            hasInitialized = true
        } else {
            if primaryLabel.isHidden {
                primaryLabel.isHidden = false
            }

            if secondaryLabel.isHidden {
                secondaryLabel.isHidden = false
            }
        }
        
        primaryLabel.setValue(amount.amountForLtcFormat)
        secondaryLabel.setValue(amount.localAmount)
        
        if !isLTCSwapped {
            primaryLabel.transform = .identity
            secondaryLabel.transform = transform(forView: secondaryLabel)
        } else {
            secondaryLabel.transform = .identity
            primaryLabel.transform = transform(forView: primaryLabel)
        }
        
        self.timeStampLabel.text = S.TransactionDetails.priceTimeStampLabel + " " + dateFormatter.string(from: Date())
        let fiatRate = Double(round(100*rate.rate)/100)
        let formattedFiatString = String(format: "%.02f", fiatRate)
        self.currentLTCPriceLabel.text = Currency.getSymbolForCurrencyCode(code: rate.code)! + formattedFiatString
       
    }
   
    private func transform(forView: UIView) ->  CGAffineTransform {
        forView.transform = .identity //Must reset the view's transform before we calculate the next transform
        let scaleFactor: CGFloat = smallFontSize/largeFontSize
        let deltaX = forView.frame.width * (1-scaleFactor)
        let deltaY = forView.frame.height * (1-scaleFactor)
        let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
        return scale.translatedBy(x: -deltaX, y: deltaY/2.0)
    }
    
    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
        
        guard let array = self.tabBar.items else {
            NSLog("ERROR: no items found")
            return
        }
        
        array.forEach { item in
            
            switch item.tag {
            case 0: item.title = S.History.barItemTitle
            case 1: item.title = S.Send.barItemTitle
            case 2: item.title = S.Receive.barItemTitle
            case 3: item.title = S.BuyCenter.barItemTitle
            default:
                item.title = "XXXXXX"
                NSLog("ERROR: UITabbar item count is wrong")
            }
        }
     }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.displayContentController(contentController: viewControllers[kInitialChildViewControllerIndex])
    }
 
    func displayContentController(contentController:UIViewController) {
        
        switch NSStringFromClass(contentController.classForCoder) {
        case "loafwallet.TransactionsViewController":

            guard let transactionVC = contentController as? TransactionsViewController else  {
                return
            }
            
            transactionVC.store = self.store
            transactionVC.walletManager = self.walletManager
            transactionVC.isLtcSwapped = self.store?.state.isLtcSwapped
        
        case "loafwallet.BuyTableViewController":
                guard let buyVC = contentController as? BuyTableViewController else  {
                    return
            }
            buyVC.store = self.store
            buyVC.walletManager = self.walletManager
            
        case "loafwallet.SendLTCViewController":
            guard let sendVC = contentController as? SendLTCViewController else  {
                return
            }
            
            sendVC.store = self.store
            
        case "loafwallet.ReceiveLTCViewController":
            guard let receiveVC = contentController as? ReceiveLTCViewController else  {
                return
            }
            receiveVC.store = self.store
            
        default:
            fatalError("Tab viewController not set")
        }
        self.exchangeRate = TransactionManager.sharedInstance.rate
        
        self.addChildViewController(contentController)
        contentController.view.frame = self.containerView.frame
        self.view.addSubview(contentController.view)
        contentController.didMove(toParentViewController: self)
        self.activeController = contentController
    }
    
    func hideContentController(contentController:UIViewController) {
        contentController.willMove(toParentViewController: nil)
        contentController.view .removeFromSuperview()
        contentController.removeFromParentViewController()
    }
      
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        
        if let tempActiveController = activeController {
            self.hideContentController(contentController: tempActiveController)
        }
        self.displayContentController(contentController: viewControllers[item.tag])
    }
}

extension TabBarViewController {
    
    @objc private func currencySwitchTapped() {
        self.view.layoutIfNeeded()
        guard let store = self.store else { return }
        guard let isLTCSwapped = self.isLtcSwapped else { return }
        guard let primaryLabel = self.primaryBalanceLabel,
            let secondaryLabel = self.secondaryBalanceLabel else {
                NSLog("ERROR: Price labels not initialized")
                return
        }

        UIView.spring(0.7, animations: {
            primaryLabel.transform = primaryLabel.transform.isIdentity ? self.transform(forView: primaryLabel) : .identity
            secondaryLabel.transform = secondaryLabel.transform.isIdentity ? self.transform(forView: secondaryLabel) : .identity
            NSLayoutConstraint.deactivate(!isLTCSwapped ? self.regularConstraints : self.swappedConstraints)
            NSLayoutConstraint.activate(!isLTCSwapped ? self.swappedConstraints : self.regularConstraints)
            self.view.layoutIfNeeded()
            
        }) { _ in }
        store.perform(action: CurrencyChange.toggle())
    }
}




 
