//
//  AssetListTableView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class AssetListTableView: UITableViewController, Subscriber {

    var didSelectCurrency: ((Currency) -> Void)?
    var didTapAddWallet: (() -> Void)?
    
    private let assetHeight: CGFloat = 90.0
    private let addWalletButtonHeight: CGFloat = 80.0
    private let addWalletButton = UIButton.icon(image: #imageLiteral(resourceName: "add"), title: S.TokenList.addTitle)

    // MARK: - Init
    
    init() {
        super.init(style: .plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .darkBackground
        tableView.register(HomeScreenCell.self, forCellReuseIdentifier: HomeScreenCell.cellIdentifier)
        tableView.separatorStyle = .none
        tableView.rowHeight = assetHeight
        
        setupAddWalletButton()
        setupSubscriptions()
        reload()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.visibleCells.forEach {
            if let cell = $0 as? HomeScreenCell {
                cell.refreshAnimations()
            }
        }
    }
    
    private func setupAddWalletButton() {
        addWalletButton.tintColor = .disabledWhiteText
        addWalletButton.setTitleColor(.disabledWhiteText, for: .normal)
        addWalletButton.setTitleColor(.transparentWhite, for: .highlighted)
        addWalletButton.addTarget(self, action: #selector(addWallet), for: .touchUpInside)
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: addWalletButtonHeight))
        addWalletButton.frame = CGRect(x: 0, y: 0, width: footerView.frame.width, height: addWalletButtonHeight)
        addWalletButton.accessibilityLabel = E.isScreenshots ? "Add Wallet" : S.TokenList.addTitle
        footerView.addSubview(addWalletButton)
        footerView.backgroundColor = .darkBackground
        tableView.tableFooterView = footerView
    }
    
    private func setupSubscriptions() {
        Store.lazySubscribe(self, selector: {
            var result = false
            let oldState = $0
            let newState = $1
            $0.displayCurrencies.forEach { currency in
                if oldState[currency]?.balance != newState[currency]?.balance
                    || oldState[currency]?.currentRate?.rate != newState[currency]?.currentRate?.rate
                    || oldState[currency]?.maxDigits != newState[currency]?.maxDigits {
                    result = true
                }
            }
            return result
        }, callback: { _ in
            self.tableView.reloadData()
        })
        
        Store.lazySubscribe(self, selector: {
            $0.displayCurrencies.map { $0.code } != $1.displayCurrencies.map { $0.code }
        }, callback: { _ in
            self.tableView.reloadData()
        })
    }
    
    @objc func addWallet() {
        didTapAddWallet?()
    }
    
    func reload() {
        tableView.reloadData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Data Source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Store.state.displayCurrencies.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let currency = Store.state.displayCurrencies[indexPath.row]
        let viewModel = AssetListViewModel(currency: currency)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: HomeScreenCell.cellIdentifier, for: indexPath)
        if let cell = cell as? HomeScreenCell {
            cell.set(viewModel: viewModel)
        }
        return cell
    }
    
    // MARK: - Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectCurrency?(Store.state.displayCurrencies[indexPath.row])
    }
}
