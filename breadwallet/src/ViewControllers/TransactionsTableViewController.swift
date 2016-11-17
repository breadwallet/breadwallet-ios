//
//  TransactionsTableViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class TransactionsTableViewController: UITableViewController {

    private let transactionCellIdentifier = "transactionCellIdentifier"
    private let transactions: [Transaction] = {
        let array = (0...20).map { _ in
            return Transaction.random
        }
        return array.sorted {
            $0.timestamp < $1.timestamp
        }
    }()
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TransactionTableViewCell.self, forCellReuseIdentifier: transactionCellIdentifier)
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 100.0
        tableView.rowHeight = UITableViewAutomaticDimension
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
        }
        return cell
    }
}
