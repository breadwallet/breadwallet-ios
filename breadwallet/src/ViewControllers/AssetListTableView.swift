//
//  AssetListTableView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class AssetListTableView : UITableViewController, Subscriber {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    var didSelectCurrency : ((String) -> Void)?

    private let cellIdentifier = "CellIdentifier"
    let currencies: [(String, String)] = {
        return [("Bitcoin", "btc"), ("Ethereum", "eth")] + tokens.map {
            return ($0.name, $0.code)
        }
    }()

    override func viewDidLoad() {
        tableView.backgroundColor = UIColor(red:0.960784, green:0.968627, blue:0.980392, alpha:1.0)
        tableView.register(HomeScreenCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 140
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 200.0) ])

        tableView.reloadData()

//        stores[0].lazySubscribe(self, selector: { $0.walletState.balance != $1.walletState.balance }, callback: { _ in
//            self.tableView.beginUpdates()
//            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
//            self.tableView.endUpdates()
//        })
//
//        var i = 0
//        stores.forEach {
//            let j = i
//            $0.lazySubscribe(self, selector: { $0.walletState.bigBalance?.getString(10) != $1.walletState.bigBalance?.getString(10) }, callback: { _ in
//                self.tableView.beginUpdates()
//                self.tableView.reloadRows(at: [IndexPath(row: j, section: 0)], with: .automatic)
//                self.tableView.endUpdates()
//            })
//
//            if $0.state.walletState.crowdsale != nil {
//                $0.lazySubscribe(self, selector: { $0.walletState.crowdsale != $1.walletState.crowdsale }, callback: { _  in
//                    self.tableView.beginUpdates()
//                    self.tableView.reloadRows(at: [IndexPath(row: j, section: 0)], with: .automatic)
//                    self.tableView.endUpdates()
//                })
//            }
//
//            $0.lazySubscribe(self, selector: { $0.currentRate != $1.currentRate }, callback: { _ in
//                self.tableView.beginUpdates()
//                self.tableView.reloadRows(at: [IndexPath(row: j, section: 0)], with: .automatic)
//                self.tableView.endUpdates()
//            })
//            i = i + 1
//        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currencies.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! HomeScreenCell
//        if let rate = store.state.currentRate {
//            let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: 2, store: store)
//            let price = placeholderAmount.localFormat.string(from: NSNumber(value: rate.rate)) ?? ""
//            cell.setData(currencyName: currencies[indexPath.row].0, price: price, balance: balanceString(forStore: store), store: store)
//        }
//
//        if store.state.walletState.token != nil{
//            if let balance = store.state.walletState.bigBalance, let value = Decimal(string: balance.getString(10)), value > 0 {
//                cell.isHidden = false
//            } else {
//                cell.isHidden = true
//            }
//        } else {
//            cell.isHidden = false
//        }
        return cell
    }

    private func balanceString() -> String {
        if !Store.isEthLike {
            guard let balance = Store.state.walletState.balance else { return "" }
            return DisplayAmount(amount: Satoshis(rawValue: balance), selectedRate: nil, minimumFractionDigits: Store.state.maxDigits).combinedDescription
        } else {
            guard let bigBalance = Store.state.walletState.bigBalance else { return "" }
            if Store.state.currency == .ethereum {
                return DisplayAmount.ethString(value: bigBalance) + " " + "(\(DisplayAmount.localEthString(value: bigBalance)))"
            } else {
                return DisplayAmount.tokenString(value: bigBalance)
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
