//
//  TransactionsTableViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class TransactionsTableViewController: UITableViewController, Subscriber, Trackable {

    // MARK: - Public
    init(wallet: Wallet, didSelectTransaction: @escaping ([Transaction], Int) -> Void) {
        self.wallet = wallet
        self.didSelectTransaction = didSelectTransaction
        self.showFiatAmounts = Store.state.showFiatAmounts
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        wallet.unsubscribe(self)
        Store.unsubscribe(self)
    }

    let didSelectTransaction: ([Transaction], Int) -> Void

    var filters: [TransactionFilter] = [] {
        didSet {
            transactions = filters.reduce(allTransactions, { $0.filter($1) })
            tableView.reloadData()
        }
    }
    
    var didScrollToYOffset: ((CGFloat) -> Void)?
    var didStopScrolling: (() -> Void)?

    // MARK: - Private
    private let wallet: Wallet
    private var currency: Currency { return wallet.currency }
    
    private let transactionCellIdentifier = "TransactionCellIdentifier"
    private var transactions: [Transaction] = []
    private var allTransactions: [Transaction] = [] {
        didSet { transactions = allTransactions }
    }
    private var showFiatAmounts: Bool {
        didSet { reload() }
    }
    private var rate: Rate? {
        didSet { reload() }
    }
    private let emptyMessage = UILabel.wrapping(font: .customBody(size: 16.0), color: .grayTextTint)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TxListCell.self, forCellReuseIdentifier: transactionCellIdentifier)

        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 60.0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInsetAdjustmentBehavior = .never

        let header = SyncingHeaderView(currency: currency)
        header.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 40.0)
        tableView.tableHeaderView = header

        emptyMessage.textAlignment = .center
        emptyMessage.text = S.TransactionDetails.emptyMessage
        
        setupSubscriptions()
        updateTransactions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Store.trigger(name: .didViewTransactions(transactions))
    }
    
    private func setupSubscriptions() {
        Store.subscribe(self,
                        selector: { $0.showFiatAmounts != $1.showFiatAmounts },
                        callback: { [weak self] state in
                            self?.showFiatAmounts = state.showFiatAmounts
        })
        Store.subscribe(self,
                        selector: { [weak self] oldState, newState in
                            guard let `self` = self else { return false }
                            return oldState[self.currency]?.currentRate != newState[self.currency]?.currentRate},
                        callback: { [weak self] state in
                            guard let `self` = self else { return }
                            self.rate = state[self.currency]?.currentRate
        })
        
        Store.subscribe(self, name: .txMemoUpdated("")) { [weak self] trigger in
            guard let trigger = trigger else { return }
            if case .txMemoUpdated(let txHash) = trigger {
                _ = self?.reload(txHash: txHash)
            }
        }
        
        wallet.subscribe(self) { [weak self] event in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                print("[TXLIST] \(Date()) \(self.wallet.currency.code) wallet event: \(event)")
                switch event {
                case .balanceUpdated, .transferAdded, .transferDeleted:
                    self.updateTransactions()

                case .transferChanged(let transfer),
                     .transferSubmitted(let transfer, _):
                    if let txHash = transfer.hash?.description, self.reload(txHash: txHash) {
                        break
                    }
                    self.updateTransactions()

                default:
                    break
                }
            }
        }
    }

    // MARK: - 

    private func reload() {
        assert(Thread.isMainThread)
        tableView.reloadData()
        if transactions.isEmpty {
            if emptyMessage.superview == nil {
                tableView.addSubview(emptyMessage)
                emptyMessage.constrain([
                    emptyMessage.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
                    emptyMessage.topAnchor.constraint(equalTo: tableView.topAnchor, constant: E.isIPhone5 ? 50.0 : AccountHeaderView.headerViewMinHeight),
                    emptyMessage.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[2]) ])
            }
        } else {
            emptyMessage.removeFromSuperview()
        }
    }

    private func reload(txHash: String) -> Bool {
        assert(Thread.isMainThread)
        guard let index = transactions.firstIndex(where: { txHash == $0.hash }) else { return false }
        tableView.reload(row: index, section: 0)
        return true
    }

    private func updateTransactions() {
        assert(Thread.isMainThread)
        allTransactions = wallet.transfers
        reload()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return transactionCell(tableView: tableView, indexPath: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectTransaction(transactions, indexPath.row)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Cell Builders

extension TransactionsTableViewController {

    private func transactionCell(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: transactionCellIdentifier,
                                                       for: indexPath) as? TxListCell
            else { assertionFailure(); return UITableViewCell() }
        let rate = self.rate ?? Rate.empty
        let viewModel = TxListViewModel(tx: transactions[indexPath.row])
        cell.setTransaction(viewModel,
                            showFiatAmounts: showFiatAmounts,
                            rate: rate,
                            isSyncing: currency.state?.syncState != .success)
        return cell
    }
}

extension TransactionsTableViewController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScrollToYOffset?(scrollView.contentOffset.y)
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            didStopScrolling?()
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        didStopScrolling?()
    }
}
