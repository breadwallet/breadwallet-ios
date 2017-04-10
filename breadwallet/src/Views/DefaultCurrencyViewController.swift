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
        self.faq = .buildFaqButton(store: store)
        super.init(style: .plain)
    }

    private let apiClient: BRAPIClient
    private let store: Store
    private let cellIdentifier = "CellIdentifier"
    private let faq: UIButton
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
        tableView.register(SeparatorCell.self, forCellReuseIdentifier: cellIdentifier)
        store.subscribe(self, selector: { $0.defaultCurrency != $1.defaultCurrency }, callback: {
            self.defaultCurrency = $0.defaultCurrency
        })
        apiClient.exchangeRates { rates, error in
            self.rates = rates.filter { $0.code != "BTC" }
        }
    }

    private func setHeader() {
        let header = UIView(color: .whiteTint)

        let titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)
        let rateLabelTitle = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)

        header.addSubview(titleLabel)
        header.addSubview(rateLabelTitle)
        header.addSubview(rateLabel)
        header.addSubview(faq)

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
        faq.constrain([
            faq.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            faq.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: 0.0),
            faq.constraint(.height, constant: 44.0),
            faq.constraint(.width, constant: 44.0)])

        titleLabel.text = S.DefaultCurrency.title
        rateLabelTitle.text = S.DefaultCurrency.rateLabel

        //This is a hack so that autolayout gets the right size for the header
        rateLabel.text = "blah blah"
        rateLabel.textColor = .white

        tableView.tableHeaderView = header
        tableView.backgroundColor = .whiteTint
        tableView.separatorStyle = .none

        header.constrain([
            header.widthAnchor.constraint(equalTo: view.widthAnchor) ])

    }

    private func setExchangeRateLabel() {
        if let currentRate = rates.filter({ $0.code == defaultCurrency }).first {
            let amount = Amount(amount: C.satoshis, rate: currentRate.rate)
            rateLabel.textColor = .darkText
            rateLabel.text = "\(amount.string(forLocal: currentRate.locale)) = 1 BTC"
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
        cell.textLabel?.text = "\(rate.code) (\(rate.locale.currencySymbol!))"

        if rate.code == defaultCurrency {
            let check = UIImageView(image: #imageLiteral(resourceName: "CircleCheck").withRenderingMode(.alwaysTemplate))
            check.tintColor = C.defaultTintColor
            cell.accessoryView = check
        } else {
            cell.accessoryView = nil
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
