//
//  DefaultCurrencyViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class DefaultCurrencyViewController : UITableViewController, Subscriber {

    init(apiClient: BRAPIClient, store: Store) {
        self.apiClient = apiClient
        self.store = store
        super.init(style: .plain)
    }

    private let apiClient: BRAPIClient
    private let store: Store
    private let cellIdentifier = "CellIdentifier"
    private var rates: [Rate] = [] {
        didSet {
            tableView.reloadData()
            setExchangeRateLabel()
        }
    }
    private var defaultCurrency: String? = nil {
        didSet {
            //Grab index paths of new and old rows when the currency changes
            let paths: [IndexPath] = rates.enumerated().filter { $0.1.code == defaultCurrency || $0.1.code == oldValue } .map { IndexPath(row: $0.0, section: 0) }
            tableView.beginUpdates()
            tableView.reloadRows(at: paths, with: .automatic)
            tableView.endUpdates()

            setExchangeRateLabel()
        }
    }
    private let rateLabel = UILabel(font: .customBody(size: 16.0), color: .darkText)

    deinit {
        store.unsubscribe(self)
    }

    override func viewDidLoad() {
        setHeader()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        store.subscribe(self, selector: { $0.defaultCurrency != $1.defaultCurrency }, callback: {
            self.defaultCurrency = $0.defaultCurrency
        })
        apiClient.exchangeRates { rates, error in
            self.rates = rates
        }
    }

    private func setHeader() {
        let header = UIView()

        let titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)
        let rateLabelTitle = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)

        header.addSubview(titleLabel)
        header.addSubview(rateLabelTitle)
        header.addSubview(rateLabel)

        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: C.padding[2]) ])
        rateLabelTitle.constrain([
            rateLabelTitle.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            rateLabelTitle.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]) ])
        rateLabel.constrain([
            rateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            rateLabel.topAnchor.constraint(equalTo: rateLabelTitle.bottomAnchor),
            rateLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -C.padding[2]) ])

        titleLabel.text = S.DefaultCurrency.title
        rateLabelTitle.text = S.DefaultCurrency.rateLabel

        //This is a hack so that autolayout gets the right size for the header
        rateLabel.text = "blah blah"
        rateLabel.textColor = .white

        tableView.tableHeaderView = header

        header.constrain([
            header.widthAnchor.constraint(equalTo: view.widthAnchor) ])

    }

    private func setExchangeRateLabel() {
        if let currentRate = rates.filter({ $0.code == defaultCurrency }).first {
            let amount = Amount(amount: C.satoshis, rate: currentRate.rate)
            rateLabel.textColor = .darkText
            rateLabel.text = "\(amount.localCurrency) = 1 BTC"
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
        cell.textLabel?.text = "\(rate.name), \(rate.code)"

        if rate.code == defaultCurrency {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rate = rates[indexPath.row]
        store.perform(action: DefaultCurrency.setDefault(rate.code))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
