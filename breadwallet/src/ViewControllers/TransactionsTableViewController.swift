//
//  TransactionsTableViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import SafariServices

private let promptDelay: TimeInterval = 0.6

class TransactionsTableViewController : UITableViewController, Subscriber, Trackable {

    let currency: CurrencyDef
    
    //MARK: - Public
    init(currency: CurrencyDef, didSelectTransaction: @escaping ([Transaction], Int) -> Void) {
        self.currency = currency
        self.didSelectTransaction = didSelectTransaction
        self.isBtcSwapped = Store.state.isBtcSwapped
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

        Store.subscribe(self,
                        selector: { $0.isBtcSwapped != $1.isBtcSwapped },
                        callback: { self.isBtcSwapped = $0.isBtcSwapped })
        Store.subscribe(self,
                        selector: { $0[self.currency].currentRate != $1[self.currency].currentRate},
                        callback: {
                            self.rate = $0[self.currency].currentRate
                            self.reload()
        })
        Store.subscribe(self, selector: { $0[self.currency].maxDigits != $1[self.currency].maxDigits }, callback: {_ in
            self.reload()
        })

        Store.subscribe(self, selector: { $0[self.currency].syncState != $1[self.currency].syncState
        }, callback: {
            if $0[self.currency].syncState == .syncing {
                self.syncingView.reset()
            } else if $0[self.currency].syncState == .connecting {
                self.syncingView.setIsConnecting()
            }
        })

        Store.subscribe(self, selector: { $0[self.currency].recommendRescan != $1[self.currency].recommendRescan }, callback: { _ in
            self.attemptShowPrompt()
        })
        Store.subscribe(self, selector: { $0[self.currency].syncState != $1[self.currency].syncState }, callback: { _ in
            self.reload()
        })
        Store.subscribe(self, name: .didUpgradePin, callback: { _ in
            if self.currentPrompt?.type == .upgradePin {
                self.currentPrompt = nil
            }
        })
        Store.subscribe(self, name: .didEnableShareData, callback: { _ in
            if self.currentPrompt?.type == .shareData {
                self.currentPrompt = nil
            }
        })
        Store.subscribe(self, name: .didWritePaperKey, callback: { _ in
            if self.currentPrompt?.type == .paperKey {
                self.currentPrompt = nil
            }
        })

        Store.subscribe(self, name: .txMemoUpdated(""), callback: {
            guard let trigger = $0 else { return }
            if case .txMemoUpdated(let txHash) = trigger {
                self.reload(txHash: txHash)
            }
        })

        setContentInset()

        Store.subscribe(self, selector: { $0[self.currency].transactions != $1[self.currency].transactions },
                        callback: { state in
                            self.allTransactions = state[self.currency].transactions
                            self.reload()
        })
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

    private func setContentInset() {
        if #available(iOS 11, *) {
            tableView.contentInset = UIEdgeInsets(top: accountHeaderHeight - 44.0, left: 0, bottom: accountFooterHeight + C.padding[2], right: 0)
        } else {
            tableView.contentInset = UIEdgeInsets(top: accountHeaderHeight + C.padding[2], left: 0, bottom: accountFooterHeight + C.padding[2], right: 0)
        }
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: accountHeaderHeight - 44.0, left: 0, bottom: accountFooterHeight, right: 0)
    }

    private func reload(txHash: String) {
        self.transactions.enumerated().forEach { i, tx in
            if tx.hash == txHash {
                DispatchQueue.main.async {
                    self.tableView.reload(row: i, section: self.hasExtraSection ? 1 : 0)
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
            return headerCell(tableView: tableView, indexPath: indexPath)
        } else {
            return transactionCell(tableView: tableView, indexPath: indexPath)
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
                Store.trigger(name: trigger)
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
        if let type = types.first(where: { $0.shouldPrompt(walletManager: walletManager, state: Store.state) }) {
            self.saveEvent("prompt.\(type.name).displayed")
            currentPrompt = Prompt(type: type)
            currentPrompt?.close.tap = { [weak self] in
                self?.saveEvent("prompt.\(type.name).dismissed")
                self?.currentPrompt = nil
            }
            if type == .biometrics {
                UserDefaults.hasPromptedBiometrics = true
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

//MARK: - Cell Builders
extension TransactionsTableViewController {

    private func headerCell(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
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
    }

    private func transactionCell(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
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
        if let transactionCell = cell as? TransactionTableViewCell,
            let rate = rate,
            let walletManager = walletManager {
            let viewModel = TxListViewModel(tx: transactions[indexPath.row], walletManager: walletManager)
            transactionCell.setStyle(style)
            transactionCell.setTransaction(viewModel, isBtcSwapped: isBtcSwapped, rate: rate, maxDigits: currency.state.maxDigits, isSyncing: currency.state.syncState != .success)
        }
        return cell
    }
}
