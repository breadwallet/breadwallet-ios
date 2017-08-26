//
//  DefaultCurrencyViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class DefaultCurrencyViewController : UITableViewController, Subscriber {

    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store
        self.rates = store.state.rates.filter { $0.code != C.btcCurrencyCode }
        super.init(style: .plain)
    }

    private let walletManager: WalletManager
    private let store: Store
    private let cellIdentifier = "CellIdentifier"
    private var rates: [Rate] = [] {
        didSet {
            tableView.reloadData()
            setExchangeRateLabel()
        }
    }
    private var defaultCurrencyCode: String? = nil {
        didSet {
            //Grab index paths of new and old rows when the currency changes
            let paths: [IndexPath] = rates.enumerated().filter { $0.1.code == defaultCurrencyCode || $0.1.code == oldValue } .map { IndexPath(row: $0.0, section: 0) }
            tableView.beginUpdates()
            tableView.reloadRows(at: paths, with: .automatic)
            tableView.endUpdates()

            setExchangeRateLabel()
        }
    }

    private let bitcoinLabel = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let bitcoinSwitch = UISegmentedControl(items: ["Bits (\(S.Symbols.bits))", "BTC (\(S.Symbols.btc))"])
    private let rateLabel = UILabel(font: .customBody(size: 16.0), color: .darkText)
    private var header: UIView?

    deinit {
        store.unsubscribe(self)
    }

    override func viewDidLoad() {
        tableView.register(SeparatorCell.self, forCellReuseIdentifier: cellIdentifier)
        store.subscribe(self, selector: { $0.defaultCurrencyCode != $1.defaultCurrencyCode }, callback: {
            self.defaultCurrencyCode = $0.defaultCurrencyCode
        })
        store.subscribe(self, selector: { $0.maxDigits != $1.maxDigits }, callback: { _ in
            self.setExchangeRateLabel()
        })

        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.estimatedSectionHeaderHeight = 140.0
        tableView.backgroundColor = .whiteTint
        tableView.separatorStyle = .none

        let titleLabel = UILabel(font: .customBold(size: 17.0), color: .darkText)
        titleLabel.text = S.Settings.currency
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel

        let faqButton = UIButton.buildFaqButton(store: store, articleId: ArticleIds.displayCurrency)
        faqButton.tintColor = .darkText
        navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
    }

    private func setExchangeRateLabel() {
        if let currentRate = rates.filter({ $0.code == defaultCurrencyCode }).first {
            let amount = Amount(amount: C.satoshis, rate: currentRate, maxDigits: store.state.maxDigits)
            let bitsAmount = Amount(amount: C.satoshis, rate: currentRate, maxDigits: store.state.maxDigits)
            rateLabel.textColor = .darkText
            rateLabel.text = "\(bitsAmount.bits) = \(amount.string(forLocal: currentRate.locale))"
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rates.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let rate = rates[indexPath.row]
        cell.textLabel?.text = "\(rate.code) (\(rate.currencySymbol))"

        if rate.code == defaultCurrencyCode {
            let check = UIImageView(image: #imageLiteral(resourceName: "CircleCheck").withRenderingMode(.alwaysTemplate))
            check.tintColor = C.defaultTintColor
            cell.accessoryView = check
        } else {
            cell.accessoryView = nil
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = self.header { return header }

        let header = UIView(color: .whiteTint)
        let rateLabelTitle = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)

        header.addSubview(rateLabelTitle)
        header.addSubview(rateLabel)
        header.addSubview(bitcoinLabel)
        header.addSubview(bitcoinSwitch)

        rateLabelTitle.constrain([
            rateLabelTitle.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: C.padding[2]),
            rateLabelTitle.topAnchor.constraint(equalTo: header.topAnchor, constant: C.padding[1])])
        rateLabel.constrain([
            rateLabel.leadingAnchor.constraint(equalTo: rateLabelTitle.leadingAnchor),
            rateLabel.topAnchor.constraint(equalTo: rateLabelTitle.bottomAnchor) ])

        bitcoinLabel.constrain([
            bitcoinLabel.leadingAnchor.constraint(equalTo: rateLabelTitle.leadingAnchor),
            bitcoinLabel.topAnchor.constraint(equalTo: rateLabel.bottomAnchor, constant: C.padding[2]) ])
        bitcoinSwitch.constrain([
            bitcoinSwitch.leadingAnchor.constraint(equalTo: bitcoinLabel.leadingAnchor),
            bitcoinSwitch.topAnchor.constraint(equalTo: bitcoinLabel.bottomAnchor, constant: C.padding[1]),
            bitcoinSwitch.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -C.padding[2]),
            bitcoinSwitch.widthAnchor.constraint(equalTo: header.widthAnchor, constant: -C.padding[4]) ])

        if store.state.maxDigits == 8 {
            bitcoinSwitch.selectedSegmentIndex = 1
        } else {
            bitcoinSwitch.selectedSegmentIndex = 0
        }

        bitcoinSwitch.valueChanged = strongify(self) { myself in
            let newIndex = myself.bitcoinSwitch.selectedSegmentIndex
            if newIndex == 1 {
                myself.store.perform(action: MaxDigits.set(8))
            } else {
                myself.store.perform(action: MaxDigits.set(2))
            }
        }

        bitcoinLabel.text = S.DefaultCurrency.bitcoinLabel
        rateLabelTitle.text = S.DefaultCurrency.rateLabel

        self.header = header
        return header
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rate = rates[indexPath.row]
        store.perform(action: DefaultCurrency.setDefault(rate.code))
    }


    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
