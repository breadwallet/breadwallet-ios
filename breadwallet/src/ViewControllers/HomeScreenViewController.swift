//
//  HomeScreenViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class HomeScreenViewController : UITableViewController, Subscriber {

    init(stores: [Store]) {
        self.stores = stores
        super.init(nibName: nil, bundle: nil)
    }

    var didSelectCurrency : ((String) -> Void)?

    private let stores: [Store]
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
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 200.0) ])
        stores.forEach {
            $0.subscribe(self, selector: { $0.walletState.balance != $1.walletState.balance }, callback: { _ in
                self.updateTotalAssets()
                self.tableView.reloadData()
            })
            $0.subscribe(self, selector: { $0.walletState.bigBalance != $1.walletState.bigBalance }, callback: { _ in
                self.updateTotalAssets()
                self.tableView.reloadData()
            })
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
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! HomeScreenCell
        if let rate = store.state.currentRate {
            let price = "$\(rate.rate)"
            cell.setData(currencyName: currencies[indexPath.row].0, price: price, balance: balanceString(forStore: store), store: store)
        }
        return cell
    }

    private func updateTotalAssets() {
        guard let bitcoinBalance = stores[0].state.walletState.balance else { return }
        let bitcoinAmount = Amount(amount: bitcoinBalance, rate: stores[0].state.currentRate!, maxDigits: stores[0].state.maxDigits, store: stores[0]).localAmount

        guard let ethBalance = stores[1].state.walletState.bigBalance else { return }
        guard let ethRate = stores[1].state.currentRate else { return }
        var decimal = Decimal(string: ethBalance.getString(10)) ?? Decimal(0)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        let eth = NSDecimalNumber(decimal: amount)
        let ethValue = eth.doubleValue*ethRate.rate

        let total = bitcoinAmount + ethValue

        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencySymbol = stores[0].state.currentRate!.currencySymbol
        let formattedString = format.string(from: NSNumber(value: total)) ?? ""
        let label = UILabel()
        label.text = "Total Assets: \(formattedString)"
        navigationItem.titleView = label

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
                return bigBalance.getString(10) + " \(token.code)"
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

extension HomeScreenViewController : UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is HomeScreenViewController {
            navigationController.isNavigationBarHidden = false
        } else {
            navigationController.isNavigationBarHidden = true
        }
    }
}
