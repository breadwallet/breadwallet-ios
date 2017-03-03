//
//  TransactionsTableViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class TransactionsTableViewController : UITableViewController, Subscriber {

    //MARK: - Public
    init(store: Store, didSelectTransaction: @escaping ([Transaction], Int) -> Void) {
        self.store = store
        self.didSelectTransaction = didSelectTransaction
        super.init(nibName: nil, bundle: nil)
    }

    let didSelectTransaction: ([Transaction], Int) -> Void
    let syncingView = SyncingView()
    
    var isSyncingViewVisible = true {
        didSet {
            if isSyncingViewVisible {
                if tableView.numberOfSections == 1 {
                    tableView.beginUpdates()
                    tableView.insertSections(IndexSet(integer: 0), with: .automatic)
                    tableView.endUpdates()
                }
            } else {
                if tableView.numberOfSections == 2 {
                    tableView.beginUpdates()
                    tableView.deleteSections(IndexSet(integer: 0), with: .automatic)
                    tableView.endUpdates()
                }
            }
        }
    }

    //MARK: - Private
    private let store: Store
    private let headerCellIdentifier = "HeaderCellIdentifier"
    private let transactionCellIdentifier = "TransactionCellIdentifier"
    private var transactions: [Transaction] = []
    private var currency: Currency = .bitcoin {
        didSet {
            tableView.reloadData()
        }
    }
    private var rate: Rate? {
        didSet {
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TransactionTableViewCell.self, forCellReuseIdentifier: transactionCellIdentifier)
        tableView.register(TransactionTableViewCell.self, forCellReuseIdentifier: headerCellIdentifier)
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 100.0
        tableView.rowHeight = UITableViewAutomaticDimension

        store.subscribe(self, selector: { $0.walletState.transactions != $1.walletState.transactions },
                        callback: { state in
                            self.transactions = state.walletState.transactions
                            self.tableView.reloadData()
        })

        store.subscribe(self,
                        selector: { $0.currency != $1.currency },
                        callback: { self.currency = $0.currency })
        store.subscribe(self,
                        selector: { $0.currentRate != $1.currentRate},
                        callback: { self.rate = $0.currentRate })

        tableView.reloadData()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return isSyncingViewVisible ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSyncingViewVisible && section == 0 {
            return 1
        } else {
            return transactions.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isSyncingViewVisible && indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: headerCellIdentifier, for: indexPath)
            if let transactionCell = cell as? TransactionTableViewCell {
                transactionCell.setStyle(.single)
                transactionCell.container.subviews.forEach {
                    $0.removeFromSuperview()
                }
                transactionCell.container.addSubview(syncingView)
                syncingView.constrain(toSuperviewEdges: nil)
                syncingView.constrain([
                    syncingView.heightAnchor.constraint(equalToConstant: 88.0) ])
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
                transactionCell.setTransaction(transactions[indexPath.row], currency: currency, rate: rate)
            }
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSyncingViewVisible && section == 1 {
            return C.padding[2]
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isSyncingViewVisible && section == 1 {
            let view = UIView()
            view.backgroundColor = .clear
            return view
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectTransaction(transactions, indexPath.row)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
