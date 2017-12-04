//
//  AssetListTableView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class AssetListTableView : UITableViewController, Subscriber {

    init(stores: [Store]) {
        self.stores = stores
        super.init(nibName: nil, bundle: nil)
    }

    var didSelectCurrency : ((String) -> Void)?

    private let stores: [Store]
    private let cellIdentifier = "CellIdentifier"
    private let crowdSaleCellIdentifier = "CrowdsaleCellIdentifier"
    let currencies: [(String, String)] = {
        return [("Bitcoin", "btc"), ("Ethereum", "eth")] + tokens.map {
            return ($0.name, $0.code)
        }
    }()

    override func viewDidLoad() {
        tableView.backgroundColor = UIColor(red:0.960784, green:0.968627, blue:0.980392, alpha:1.0)
        tableView.register(HomeScreenCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.register(CrowsaleCell.self, forCellReuseIdentifier: crowdSaleCellIdentifier)
        tableView.separatorStyle = .none
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 200.0) ])

        tableView.reloadData()

        stores[0].lazySubscribe(self, selector: { $0.walletState.balance != $1.walletState.balance }, callback: { _ in
            self.tableView.beginUpdates()
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
            self.tableView.endUpdates()
        })

        var i = 0
        stores.forEach {
            let j = i
            $0.lazySubscribe(self, selector: { $0.walletState.bigBalance?.getString(10) != $1.walletState.bigBalance?.getString(10) }, callback: { _ in
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [IndexPath(row: j, section: 0)], with: .automatic)
                self.tableView.endUpdates()
            })

            if $0.state.walletState.crowdsale != nil {
                $0.lazySubscribe(self, selector: { $0.walletState.crowdsale != $1.walletState.crowdsale }, callback: { _  in
                    self.tableView.beginUpdates()
                    self.tableView.reloadRows(at: [IndexPath(row: j, section: 0)], with: .automatic)
                    self.tableView.endUpdates()
                })
            }
            i = i + 1
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currencies.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let store = stores[indexPath.row]
        if store.state.walletState.token?.code == "BRD" {
            let cell = tableView.dequeueReusableCell(withIdentifier: crowdSaleCellIdentifier, for: indexPath) as! CrowsaleCell
            if let rate = store.state.currentRate {
                let price = "$\(rate.rate)"
                cell.setData(currencyName: currencies[indexPath.row].0, price: price, balance: balanceString(forStore: store), store: store)
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! HomeScreenCell
            if let rate = store.state.currentRate {
                let price = "$\(rate.rate)"
                cell.setData(currencyName: currencies[indexPath.row].0, price: price, balance: balanceString(forStore: store), store: store)
            }
            return cell
        }
    }

    private func balanceString(forStore store: Store) -> String {
        if !store.isEthLike {
            guard let balance = store.state.walletState.balance else { return "" }
            return DisplayAmount(amount: Satoshis(rawValue: balance), state: store.state, selectedRate: nil, minimumFractionDigits: store.state.maxDigits, store: store).combinedDescription
        } else {
            guard let bigBalance = store.state.walletState.bigBalance else { return "" }
            if store.state.currency == .ethereum {
                return DisplayAmount.ethString(value: bigBalance, store: store) + " " + DisplayAmount.localEthString(value: bigBalance, store: store)
            } else {
                guard let token = store.state.walletState.token else { return "" }
                var decimal = Decimal(string: bigBalance.getString(10)) ?? Decimal(0)
                var amount: Decimal = 0.0
                NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-1*token.decimals), .up)
                let value = NSDecimalNumber(decimal: amount)
                return String(describing: value) + " \(token.code)"
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectCurrency?(currencies[indexPath.row].1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
