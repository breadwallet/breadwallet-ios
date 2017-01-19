//
//  TransactionsTableViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class TransactionsTableViewController : UITableViewController, Subscriber {

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    private let store: Store
    private let transactionCellIdentifier = "transactionCellIdentifier"
    private var transactions: [Transaction] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TransactionTableViewCell.self, forCellReuseIdentifier: transactionCellIdentifier)
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 100.0
        tableView.rowHeight = UITableViewAutomaticDimension

        store.subscribe(self, selector: {$0.walletState.transactions != $1.walletState.transactions },
                        callback: { state in
                            self.transactions = state.walletState.transactions
                            self.tableView.reloadData()
        })

        tableView.reloadData()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        if let transactionCell = cell as? TransactionTableViewCell {
            transactionCell.setStyle(style)
            transactionCell.setTransaction(transactions[indexPath.row])
            if transactionCell.store == nil {
                transactionCell.store = store
            }
        }
        return cell
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
