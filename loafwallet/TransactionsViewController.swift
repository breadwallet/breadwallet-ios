//
//  TransactionsViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import UIKit
import LocalAuthentication

private let promptDelay: TimeInterval = 0.6
private let qrImageSize = 120.0
class TransactionsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, Subscriber, Trackable {

    @IBOutlet weak var tableView: UITableView!
      
    var store: Store?
    var walletManager: WalletManager?
    var selectedIndexes = [IndexPath: NSNumber]()
    var shouldBeSyncing: Bool = false
    var syncingHeaderView : SyncProgressHeaderView?
    var shouldShowPrompt = true
    
    private var transactions: [Transaction] = []
    private var allTransactions: [Transaction] = [] {
        didSet {
            transactions = allTransactions
        }
    }
    private var rate: Rate? {
        didSet { reload() }
    }
    
    private var hasExtraSection: Bool {
        return  currentPromptType != nil
    }
    
    private var currentPromptType: PromptType? {
        didSet {
            if currentPromptType != nil && oldValue == nil {
                tableView.beginUpdates()
                tableView.insertSections(IndexSet(integer: 0), with: .automatic)
                tableView.endUpdates()
            }
        }
    }
    var isLtcSwapped: Bool? {
        didSet { reload() }
    }
     
    override func viewDidLoad() {
      setup()
      addSubscriptions()
    }
    
    private func setup() {
        
        guard let _ = walletManager else {
             NSLog("ERROR - Wallet manager not initialized")
             assertionFailure("PEER MAANAGER Not initialized")
             return
        }
        
        self.transactions = TransactionManager.sharedInstance.transactions
        self.rate = TransactionManager.sharedInstance.rate
        tableView.backgroundColor = .liteWalletBlue
        initSyncingHeaderView(completion: {})
        attemptShowPrompt()
    }
    
    private func initSyncingHeaderView(completion: @escaping () -> Void) {
        self.syncingHeaderView = Bundle.main.loadNibNamed("SyncProgressHeaderView",
        owner: self,
        options: nil)?.first as? SyncProgressHeaderView
        completion()
    }
     
    private func addSubscriptions() {
        
        guard let store = self.store else {
            NSLog("ERROR - Store not passed")
            return
        }
         
        store.subscribe(self, selector: { $0.walletState.transactions != $1.walletState.transactions },
                       callback: { state in
           self.allTransactions = state.walletState.transactions
           self.reload()
        })
        
        store.subscribe(self, selector: { $0.isLoadingTransactions != $1.isLoadingTransactions }, callback: {
            if $0.isLoadingTransactions {
               
            } else {
                 
            }
        })

        store.subscribe(self, selector: { $0.isLtcSwapped != $1.isLtcSwapped },
                       callback: { self.isLtcSwapped = $0.isLtcSwapped })
        store.subscribe(self, selector: { $0.currentRate != $1.currentRate},
                       callback: { self.rate = $0.currentRate })
        store.subscribe(self, selector: { $0.maxDigits != $1.maxDigits }, callback: {_ in
           self.reload()
        })
         
        store.subscribe(self, selector: { $0.walletState.syncProgress != $1.walletState.syncProgress },
                        callback: { state in
            store.subscribe(self, name:.showStatusBar) { (didShowStatusBar) in
               self.reload() //May fix where the action view persists after confirming pin
            }
                            
            if state.walletState.isRescanning {
                 self.initSyncingHeaderView(completion: {
                    self.syncingHeaderView?.isRescanning = state.walletState.isRescanning
                    self.syncingHeaderView?.progress = CGFloat(state.walletState.syncProgress)
                    self.syncingHeaderView?.headerMessage = state.walletState.syncState
                    self.syncingHeaderView?.noSendImageView.alpha = 1.0
                    self.syncingHeaderView?.timestamp = state.walletState.lastBlockTimestamp
                    self.shouldBeSyncing = true
                 })
            } else if state.walletState.syncProgress > 0.95 {
                self.shouldBeSyncing = false
                self.syncingHeaderView = nil
            } else {
                self.initSyncingHeaderView(completion: {
                    self.syncingHeaderView?.progress = CGFloat(state.walletState.syncProgress)
                    self.syncingHeaderView?.headerMessage = state.walletState.syncState
                    self.syncingHeaderView?.timestamp = state.walletState.lastBlockTimestamp
                    self.syncingHeaderView?.noSendImageView.alpha = 0.0
                    self.shouldBeSyncing = true
                })
            }
        self.reload()
        })
        
        store.subscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState },
                     callback: { state in
            guard let _ = self.walletManager?.peerManager else {
              assertionFailure("PEER MANAGER Not initialized")
            return
            }
         
            if state.walletState.syncState == .success {
            self.shouldBeSyncing = false
            self.syncingHeaderView = nil
            }
            self.reload()
       })
   
        store.subscribe(self, selector: { $0.recommendRescan != $1.recommendRescan }, callback: { _ in
            self.attemptShowPrompt()
        })
        store.subscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState }, callback: { _ in
            self.reload()
        })
        store.subscribe(self, name: .didUpgradePin, callback: { _ in
            if self.currentPromptType == .upgradePin {
                self.currentPromptType = nil
            }
        })
        store.subscribe(self, name: .didEnableShareData, callback: { _ in
            if self.currentPromptType == .shareData {
                self.currentPromptType = nil
            }
        })
        store.subscribe(self, name: .didWritePaperKey, callback: { _ in
            if self.currentPromptType == .paperKey {
                self.currentPromptType = nil
            }
        })
        
       store.subscribe(self, name: .didUpgradePin, callback: { _ in
          print("DidUpgragePIN")
       })
 
       store.subscribe(self, name: .didWritePaperKey, callback: { _ in
          print("DidWritePaperKey")
       })
       store.subscribe(self, name: .txMemoUpdated(""), callback: {
           guard let trigger = $0 else { return }
           if case .txMemoUpdated(let txHash) = trigger {
               self.reload(txHash: txHash)
           }
       })
       reload()
    }
    
    private func attemptShowPrompt() {
        guard let walletManager = walletManager else { return }
        guard let store = self.store else {
            NSLog("ERROR - Store not passed")
            return
        }
         
        let types = PromptType.defaultOrder
        if let type = types.first(where: { $0.shouldPrompt(walletManager: walletManager, state: store.state) }) {
            self.saveEvent("prompt.\(type.name).displayed")
            currentPromptType = type
            if type == .biometrics {
                UserDefaults.hasPromptedBiometrics = true
            }
            if type == .shareData {
                UserDefaults.hasPromptedShareData = true
            }
        } else {
            currentPromptType = nil
        }
    }
     
     
    private func reload() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    private func reload(txHash: String) {
        self.transactions.enumerated().forEach { i, tx in
            if tx.hash == txHash {
                DispatchQueue.main.async {
                    self.tableView.beginUpdates()
                    self.tableView.reloadRows(at: [IndexPath(row: i, section: self.hasExtraSection ? 1 : 0)], with: .automatic)
                    self.tableView.endUpdates()
                }
            }
        }
    }
     
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        if shouldBeSyncing {
            return self.syncingHeaderView
        }
        return nil
    }
     
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if shouldBeSyncing { return kProgressHeaderHeight }
        return 0.0
    }
    
    // MARK: - Table view data source
    func numberOfSections(in tableView: UITableView) -> Int {
        return hasExtraSection ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
          
        if hasExtraSection && section == 0 {
            return 1
        } else {
            if transactions.count > 0  {
                self.tableView.backgroundView = nil
                return transactions.count
            } else {
                self.tableView.backgroundView = emptyMessageView()
                self.tableView.separatorStyle = .none
                return 0
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if hasExtraSection && indexPath.section == 0 {
            return kPromptCellHeight
        } else {
            if cellIsSelected(indexPath: indexPath) {
                return kMaxTransactionCellHeight
            } else {
                return kNormalTransactionCellHeight
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
         
          if hasExtraSection && indexPath.section == 0 {
            return configurePromptCell(promptType: currentPromptType, indexPath: indexPath)
        } else {
            let transaction = transactions[indexPath.row]
            return configureTransactionCell(transaction:transaction, indexPath: indexPath)
        }
    }
    
    
    private func configurePromptCell(promptType: PromptType?, indexPath: IndexPath) -> PromptTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PromptTVC2", for: indexPath) as? PromptTableViewCell else {
            NSLog("ERROR No cell found")
            return PromptTableViewCell()
        }
        
        
        cell.type = promptType
        cell.titleLabel.text = promptType?.title
        cell.bodyLabel.text = promptType?.body
        cell.didClose = { [weak self] in
            self?.saveEvent("prompt.\(String(describing: promptType?.name)).dismissed")
            self?.currentPromptType = nil
            self?.reload()
        }
        
        cell.didTap = { [weak self] in
              
            if let store = self?.store,
                let trigger = self?.currentPromptType?.trigger {
                store.trigger(name: trigger)
            }
            self?.saveEvent("prompt.\(String(describing: self?.currentPromptType?.name)).trigger")
            self?.currentPromptType = nil
        }
        
        return cell
    }
      
    private func configureTransactionCell(transaction:Transaction?, indexPath: IndexPath) -> TransactionTableViewCellv2 {
         
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TransactionTVC2", for: indexPath) as? TransactionTableViewCellv2 else {
            NSLog("ERROR No cell found")
            return TransactionTableViewCellv2()
        }
        
        if let transaction = transaction {
            if transaction.direction == .received {
                cell.showQRModalAction = { [unowned self] in
                    
                    if let addressString = transaction.toAddress,
                        let qrImage =  UIImage.qrCode(data: addressString.data(using: .utf8) ?? Data(), color: CIColor(color: .black))?.resize(CGSize(width: qrImageSize, height: qrImageSize)),
                        let receiveLTCtoAddressModal = UIStoryboard.init(name: "Alerts", bundle: nil).instantiateViewController(withIdentifier: "LFModalReceiveQRViewController") as? LFModalReceiveQRViewController {
                        
                        receiveLTCtoAddressModal.providesPresentationContextTransitionStyle = true
                        receiveLTCtoAddressModal.definesPresentationContext = true
                        receiveLTCtoAddressModal.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
                        receiveLTCtoAddressModal.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
                        receiveLTCtoAddressModal.dismissQRModalAction = { [unowned self] in
                            self.dismiss(animated: true, completion: nil)
                        }
                        self.present(receiveLTCtoAddressModal, animated: true) {
                             receiveLTCtoAddressModal.receiveModalTitleLabel.text = S.TransactionDetails.receiveModaltitle
                             receiveLTCtoAddressModal.addressLabel.text = addressString
                             receiveLTCtoAddressModal.qrImageView.image = qrImage
                         }
                    }
                }
            }
               
            if let rate = rate,
                let store = self.store,
                let isLtcSwapped = self.isLtcSwapped {
                cell.setTransaction(transaction, isLtcSwapped: isLtcSwapped, rate: rate, maxDigits: store.state.maxDigits, isSyncing: store.state.walletState.syncState != .success)
            }
            
            cell.staticBlockLabel.text = S.TransactionDetails.blockHeightLabel
            cell.staticCommentLabel.text = S.TransactionDetails.commentsHeader
            cell.staticAmountDetailLabel.text = S.Transaction.amountDetailLabel
        }
        else {
            assertionFailure("Transaction must exist")
        }
        return cell
    }
      
    private func cellIsSelected(indexPath: IndexPath) -> Bool {
        
        let cellIsSelected = selectedIndexes[indexPath] as? Bool ?? false
        return  cellIsSelected
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.beginUpdates()
        let isSelected = !self.cellIsSelected(indexPath: indexPath)
        let selectedIndex = NSNumber(value: isSelected)
        selectedIndexes[indexPath] = selectedIndex

        if let selectedCell = tableView.cellForRow(at: indexPath) as? TransactionTableViewCellv2 {
             
            let identity: CGAffineTransform = .identity
            
            if isSelected {
                let newAlpha = 1.0
                UIView.animate(withDuration: 0.1, delay: 0.0, animations: {
                    selectedCell.expandCardView.alpha = CGFloat(newAlpha)
                    selectedCell.dropArrowImageView.transform = identity.rotated(by: π)
                })
            } else {
                let newAlpha = 0.0
                UIView.animate(withDuration: 0.1, delay: 0.0, animations: {
                    selectedCell.expandCardView.alpha = CGFloat(newAlpha)
                    selectedCell.dropArrowImageView.transform = identity.rotated(by: -4.0*π/2.0)
                })
            }
        }
        tableView.endUpdates()
    }
    
    private func emptyMessageView() -> UILabel {
        let rect = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: self.tableView.bounds.size.width, height: self.tableView.bounds.size.height))
        let messageLabel = UILabel(frame: rect)
        messageLabel.text = S.TransactionDetails.emptyMessage
        messageLabel.textColor = .litecoinGray
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.barloweMedium(size: 20)
        messageLabel.sizeToFit()
        self.tableView.backgroundView = messageLabel
        self.tableView.separatorStyle = .none
        return messageLabel
    }
}
 
