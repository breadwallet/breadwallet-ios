//
//  TransactionsTableViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let promptDelay: TimeInterval = 0.6

class TransactionsTableViewController : UITableViewController, Subscriber, Trackable {

    //MARK: - Public
    init(store: Store, didSelectTransaction: @escaping ([Transaction], Int) -> Void) {
        self.store = store
        self.didSelectTransaction = didSelectTransaction
        self.isBtcSwapped = store.state.isBtcSwapped
        super.init(nibName: nil, bundle: nil)
    }

    let didSelectTransaction: ([Transaction], Int) -> Void
    let syncingView = SyncingView()
    
    var isSyncingViewVisible = false {
        didSet {
            guard oldValue != isSyncingViewVisible else { return } //We only care about changes
            if isSyncingViewVisible {
                tableView.beginUpdates()
                if currentPrompt != nil {
                    currentPrompt = nil
                    tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                } else {
                    tableView.insertSections(IndexSet(integer: 0), with: .automatic)
                }
                tableView.endUpdates()
            } else {
                tableView.beginUpdates()
                tableView.deleteSections(IndexSet(integer: 0), with: .automatic)
                tableView.endUpdates()

                DispatchQueue.main.asyncAfter(deadline: .now() + promptDelay , execute: {
                    self.attemptShowPrompt()
                })
            }
        }
    }

    var filters: [TransactionFilter] = [] {
        didSet {
            transactions = filters.reduce(allTransactions, { $0.filter($1) })
            tableView.reloadData()
        }
    }

    var walletManager: WalletManager?

    //MARK: - Private
    private let store: Store
    private let headerCellIdentifier = "HeaderCellIdentifier"
    private let transactionCellIdentifier = "TransactionCellIdentifier"
    private var transactions: [Transaction] = []
    private var allTransactions: [Transaction] = [] {
        didSet {
            transactions = allTransactions
        }
    }
    private var isBtcSwapped: Bool {
        didSet {
            reload()
        }
    }
    private var rate: Rate? {
        didSet {
            reload()
        }
    }
    private let emptyMessage = UILabel.wrapping(font: .customBody(size: 16.0), color: .grayTextTint)
    private var currentPrompt: Prompt? {
        didSet {
            if currentPrompt != nil && oldValue == nil {
                tableView.beginUpdates()
                tableView.insertSections(IndexSet(integer: 0), with: .automatic)
                tableView.endUpdates()
            } else if currentPrompt == nil && oldValue != nil && !isSyncingViewVisible {
                tableView.beginUpdates()
                tableView.deleteSections(IndexSet(integer: 0), with: .automatic)
                tableView.endUpdates()
            }
        }
    }
    private var hasExtraSection: Bool {
        return isSyncingViewVisible || (currentPrompt != nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TransactionTableViewCell.self, forCellReuseIdentifier: transactionCellIdentifier)
        tableView.register(TransactionTableViewCell.self, forCellReuseIdentifier: headerCellIdentifier)
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 100.0
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.backgroundColor = .whiteTint
        
        store.subscribe(self, selector: { $0.walletState.transactions != $1.walletState.transactions },
                        callback: { state in
                            self.allTransactions = state.walletState.transactions
                            self.reload()
        })

        store.subscribe(self,
                        selector: { $0.isBtcSwapped != $1.isBtcSwapped },
                        callback: { self.isBtcSwapped = $0.isBtcSwapped })
        store.subscribe(self,
                        selector: { $0.currentRate != $1.currentRate},
                        callback: { self.rate = $0.currentRate })
        store.subscribe(self, selector: { $0.maxDigits != $1.maxDigits }, callback: {_ in 
            self.reload()
        })

        store.subscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState
        }, callback: {
            if $0.walletState.syncState == .syncing {
                self.syncingView.reset()
            } else if $0.walletState.syncState == .connecting {
                self.syncingView.setIsConnecting()
            }
        })

        store.subscribe(self, selector: { $0.recommendRescan != $1.recommendRescan }, callback: { _ in
            self.attemptShowPrompt()
        })
        store.subscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState }, callback: { _ in
            self.reload()
        })
        store.subscribe(self, name: .didUpgradePin, callback: { _ in
            if self.currentPrompt?.type == .upgradePin {
                self.currentPrompt = nil
            }
        })
        store.subscribe(self, name: .didEnableShareData, callback: { _ in
            if self.currentPrompt?.type == .shareData {
                self.currentPrompt = nil
            }
        })
        store.subscribe(self, name: .didWritePaperKey, callback: { _ in
            if self.currentPrompt?.type == .paperKey {
                self.currentPrompt = nil
            }
        })

        store.subscribe(self, name: .txMemoUpdated(""), callback: {
            guard let trigger = $0 else { return }
            if case .txMemoUpdated(let txHash) = trigger {
                self.reload(txHash: txHash)
            }
        })

        emptyMessage.textAlignment = .center
        emptyMessage.text = S.TransactionDetails.emptyMessage
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + promptDelay, execute: { [weak self] in
            guard let myself = self else { return }
            if !myself.isSyncingViewVisible {
                myself.attemptShowPrompt()
            }
        })
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

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return hasExtraSection ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if hasExtraSection && section == 0 {
            return 1
        } else {
            return transactions.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if hasExtraSection && indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: headerCellIdentifier, for: indexPath)
            if let transactionCell = cell as? TransactionTableViewCell {
                transactionCell.setStyle(.single)
                transactionCell.container.subviews.forEach {
                    $0.removeFromSuperview()
                }
                if let prompt = currentPrompt {
                    transactionCell.container.addSubview(prompt)
                    prompt.constrain(toSuperviewEdges: nil)
                    prompt.constrain([
                        prompt.heightAnchor.constraint(equalToConstant: 88.0) ])
                    transactionCell.selectionStyle = .default
                } else {
                    transactionCell.container.addSubview(syncingView)
                    syncingView.constrain(toSuperviewEdges: nil)
                    syncingView.constrain([
                        syncingView.heightAnchor.constraint(equalToConstant: 88.0) ])
                    transactionCell.selectionStyle = .none
                }
            }
            return cell
        } else {
            let numRows = tableView.numberOfRows(inSection: indexPath.section)
            var style: TransactionCellStyle = .middle
            if numRows == 1 {
                style = .single
            }
            if numRows > 1 {
                if indexPath.row == 0 {
                    style = .first
                }
                if indexPath.row == numRows - 1 {
                    style = .last
                }
            }

            let cell = tableView.dequeueReusableCell(withIdentifier: transactionCellIdentifier, for: indexPath)
            if let transactionCell = cell as? TransactionTableViewCell, let rate = rate {
                transactionCell.setStyle(style)
                transactionCell.setTransaction(transactions[indexPath.row], isBtcSwapped: isBtcSwapped, rate: rate, maxDigits: store.state.maxDigits, isSyncing: store.state.walletState.syncState != .success)
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if hasExtraSection && section == 1 {
            return C.padding[2]
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if hasExtraSection && section == 1 {
            return UIView(color: .clear)
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSyncingViewVisible && indexPath.section == 0 { return }
        if let currentPrompt = currentPrompt, indexPath.section == 0 {
            if let trigger = currentPrompt.type.trigger {
                store.trigger(name: trigger)
            }
            saveEvent("prompt.\(currentPrompt.type.name).trigger")
            self.currentPrompt = nil
            return
        }
        didSelectTransaction(transactions, indexPath.row)
    }

    private func reload() {
        tableView.reloadData()
        if transactions.count == 0 {
            if emptyMessage.superview == nil {
                tableView.addSubview(emptyMessage)
                emptyMessage.constrain([
                    emptyMessage.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
                    emptyMessage.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -accountHeaderHeight),
                    emptyMessage.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[2]) ])
            }
        } else {
            emptyMessage.removeFromSuperview()
        }
    }

    private func attemptShowPrompt() {
        guard let walletManager = walletManager else { return }
        guard !isSyncingViewVisible else { return }
        let types = PromptType.defaultOrder
        if let type = types.first(where: { $0.shouldPrompt(walletManager: walletManager, state: store.state) }) {
            self.saveEvent("prompt.\(type.name).displayed")
            currentPrompt = Prompt(type: type)
            currentPrompt?.close.tap = { [weak self] in
                self?.saveEvent("prompt.\(type.name).dismissed")
                self?.currentPrompt = nil
            }
            if type == .touchId {
                UserDefaults.hasPromptedTouchId = true
            }
            if type == .shareData {
                UserDefaults.hasPromptedShareData = true
            }
        } else {
            currentPrompt = nil
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
