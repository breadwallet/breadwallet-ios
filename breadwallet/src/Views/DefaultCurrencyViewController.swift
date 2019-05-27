//
//  DefaultCurrencyViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

class DefaultCurrencyViewController: UITableViewController, Subscriber, Trackable {

    init() {
        //TODO:CRYPTO rates / wallet state
        self.rates = [Rate]()
        //self.rates = Currencies.btc.state?.rates.filter { $0.code != Currencies.btc.code } ?? [Rate]()
        super.init(style: .plain)
    }

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

    private let bitcoinLabel = UILabel(font: .customBold(size: 14.0), color: .white)
    private let rateLabel = UILabel(font: .customBody(size: 16.0), color: .white)
    private var header: UIView?

    deinit {
        Store.unsubscribe(self)
    }

    override func viewDidLoad() {
        tableView.register(SeparatorCell.self, forCellReuseIdentifier: cellIdentifier)
        Store.subscribe(self, selector: { $0.defaultCurrencyCode != $1.defaultCurrencyCode }, callback: {
            self.defaultCurrencyCode = $0.defaultCurrencyCode
        })

        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 140.0
        tableView.separatorStyle = .none
        tableView.backgroundColor = .darkBackground

        let titleLabel = UILabel(font: .customBold(size: 17.0), color: .white)
        titleLabel.text = S.Settings.currency
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel

        //TODO:CRYPTO hardcoded btc
        /*
        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.displayCurrency, currency: Currencies.btc)
        faqButton.tintColor = .navigationTint
        navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
        */
    }

    private func setExchangeRateLabel() {
        //TODO:CRYPTO hard-coded currency/unit
        /*
        if let currentRate = rates.filter({ $0.code == defaultCurrencyCode }).first {
            let amount = Amount(value: UInt256(C.satoshis), currency: Currencies.btc, rate: currentRate)
            rateLabel.textColor = .white
            rateLabel.text = "\(amount.tokenDescription) = \(amount.fiatDescription(forLocale: currentRate.locale))"
        }
         */
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
        cell.textLabel?.font = UIFont.customBody(size: 14.0)
        cell.textLabel?.textColor = .white
        if rate.code == defaultCurrencyCode {
            let check = UIImageView(image: #imageLiteral(resourceName: "CircleCheck").withRenderingMode(.alwaysTemplate))
            check.tintColor = .navigationTint
            cell.accessoryView = check
        } else {
            cell.accessoryView = nil
        }
        cell.contentView.backgroundColor = .darkBackground
        cell.backgroundColor = .darkBackground
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let header = self.header { return header }

        let header = UIView(color: .darkBackground)
        let rateLabelTitle = UILabel(font: .customBold(size: 14.0), color: .white)

        header.addSubview(rateLabelTitle)
        header.addSubview(rateLabel)
        header.addSubview(bitcoinLabel)

        rateLabelTitle.constrain([
            rateLabelTitle.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: C.padding[2]),
            rateLabelTitle.topAnchor.constraint(equalTo: header.topAnchor, constant: C.padding[1])])
        rateLabel.constrain([
            rateLabel.leadingAnchor.constraint(equalTo: rateLabelTitle.leadingAnchor),
            rateLabel.topAnchor.constraint(equalTo: rateLabelTitle.bottomAnchor) ])

        bitcoinLabel.constrain([
            bitcoinLabel.leadingAnchor.constraint(equalTo: rateLabelTitle.leadingAnchor),
            bitcoinLabel.topAnchor.constraint(equalTo: rateLabel.bottomAnchor, constant: C.padding[2]),
            bitcoinLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -C.padding[2])])

        bitcoinLabel.text = S.DefaultCurrency.bitcoinLabel
        rateLabelTitle.text = S.DefaultCurrency.rateLabel

        self.header = header
        return header
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rate = rates[indexPath.row]
        Store.perform(action: DefaultCurrency.SetDefault(rate.code))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
