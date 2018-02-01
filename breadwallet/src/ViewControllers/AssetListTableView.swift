//
//  AssetListTableView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class AssetListTableView : UITableViewController, Subscriber {

    var didSelectCurrency : ((CurrencyDef) -> Void)?
    private let cellIdentifier = "CellIdentifier"

    override func viewDidLoad() {
        tableView.backgroundColor = UIColor(red:0.960784, green:0.968627, blue:0.980392, alpha:1.0)
        tableView.register(HomeScreenCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 140
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 200.0) ])

        tableView.reloadData()

        Store.subscribe(self, selector: {
            var result = false
            let oldState = $0
            let newState = $1
            $0.currencies.forEach { currency in
                if oldState[currency].balance != newState[currency].balance {
                    result = true
                }

                if oldState[currency].currentRate?.rate != newState[currency].currentRate?.rate {
                    result = true
                }
            }
            return result
        }, callback: { _ in
            self.tableView.reloadData()
        })
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Store.state.wallets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let currency = Store.state.currencies[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! HomeScreenCell
        let rate = currency.state.currentRate ?? Rate.empty
        let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: 2, currency: currency)
        let price = placeholderAmount.localFormat.string(from: NSNumber(value: rate.rate)) ?? ""
        cell.setData(price: price, balance: balanceString(currency: currency), currency: currency)
        return cell
    }

    private func balanceString(currency: CurrencyDef) -> String {
        guard let balance = currency.state.balance else { return "" }
        return DisplayAmount(amount: Satoshis(rawValue: balance), selectedRate: nil, minimumFractionDigits: currency.state.maxDigits, currency: currency).combinedDescription
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectCurrency?(Store.state.currencies[indexPath.row])
    }
}
