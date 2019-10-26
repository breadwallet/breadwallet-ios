//
//  DefaultCurrencyViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-06.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class DefaultCurrencyViewController: UITableViewController, Subscriber, Trackable {

    init() {
        self.selectedCurrencyCode = Store.state.defaultCurrencyCode
        super.init(style: .plain)
    }

    private let cellIdentifier = "CellIdentifier"
    private let fiatCurrencies = FiatCurrency.availableCurrencies
    
    private var selectedCurrencyCode: String {
        didSet {
            // Grab index paths of new and old rows when the currency changes
            let filtered = fiatCurrencies.enumerated().filter({ $0.1.code == selectedCurrencyCode || $0.1.code == oldValue })
            let paths: [IndexPath] = filtered.map({ IndexPath(row: $0.0, section: 0 )})
            
            tableView.beginUpdates()
            tableView.reloadRows(at: paths, with: .automatic)
            tableView.endUpdates()
            
            Store.perform(action: DefaultCurrency.SetDefault(selectedCurrencyCode))
        }
    }

    deinit {
        Store.unsubscribe(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(SeparatorCell.self, forCellReuseIdentifier: cellIdentifier)
        self.selectedCurrencyCode = Store.state.defaultCurrencyCode

        tableView.separatorStyle = .none
        tableView.backgroundColor = Theme.primaryBackground

        let titleLabel = UILabel(font: .customBold(size: 17.0), color: .white)
        titleLabel.text = S.Settings.currency
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel

        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.displayCurrency, currency: nil)
        faqButton.tintColor = .navigationTint
        navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Scroll to the selected display currency.
        if let index = self.fiatCurrencies.firstIndex(where: {
            return $0.code.lowercased() == self.selectedCurrencyCode.lowercased()
        }) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fiatCurrencies.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)

        let currency = fiatCurrencies[indexPath.row]
        let code = currency.code

        cell.textLabel?.text = "\(currency.code) (\(Rate.symbolMap[code] ?? currency.code))"
        cell.textLabel?.font = UIFont.customBody(size: 14.0)
        cell.textLabel?.textColor = .white

        if currency.code == selectedCurrencyCode {
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currency = fiatCurrencies[indexPath.row]
        selectedCurrencyCode = currency.code
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
