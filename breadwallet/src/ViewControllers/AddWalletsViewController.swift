// 
//  AddWalletsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-07-30.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class AddWalletsViewController: UITableViewController {
    
    private let assetCollection: AssetCollection
    private let coreSystem: CoreSystem
    private var displayData = [CurrencyMetaData]()
    private var allAssets = [CurrencyMetaData]()
    private var addedCurrencyIndices = [Int]()
    private var addedCurrencyIdentifiers = [CurrencyId]()
    private let searchBar = UISearchBar()
    
    init(assetCollection: AssetCollection, coreSystem: CoreSystem) {
        self.assetCollection = assetCollection
        self.coreSystem = coreSystem
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        allAssets = assetCollection.availableAssets
            .sorted {
                if let balance = coreSystem.walletBalance(currencyId: $0.uid),
                    !balance.isZero,
                    coreSystem.walletBalance(currencyId: $1.uid) == nil {
                    return true
                }
                return false
        }
        displayData = allAssets
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reconcileChanges()
    }
    
    private func reconcileChanges() {
        // add eth when adding tokens
        let currenciesToAdd = addedCurrencyIndices.map { allAssets[$0] }
        if let eth = allAssets.first(where: { $0.uid == Currencies.eth.uid }),
            !currenciesToAdd.filter({ $0.tokenAddress != nil }).isEmpty, // tokens are being added
            !assetCollection.enabledAssets.contains(eth), // eth not already added
            !currenciesToAdd.contains(eth) { // eth not being explicitly added
            self.assetCollection.add(asset: eth)
        }
        addedCurrencyIndices.forEach {
            self.assetCollection.add(asset: allAssets[$0])
        }
        assetCollection.saveChanges()
    }
    
    override func viewDidLoad() {
        tableView.backgroundColor = .darkBackground
        tableView.keyboardDismissMode = .interactive
        tableView.separatorStyle = .none
        tableView.rowHeight = 66.0
        tableView.register(ManageCurrencyCell.self, forCellReuseIdentifier: ManageCurrencyCell.cellIdentifier)
        setupSearchBar()
        title = S.TokenList.addTitle
    }
    
    private func addCurrency(_ identifier: CurrencyId) {
        guard let index = allAssets.firstIndex(where: {$0.uid == identifier }) else { return assertionFailure() }
        addedCurrencyIndices.append(index)
        addedCurrencyIdentifiers.append(identifier)
    }
    
    private func removeCurrency(_ identifier: CurrencyId) {
        guard let index = allAssets.firstIndex(where: {$0.uid == identifier }) else { return assertionFailure() }
        addedCurrencyIndices.removeAll(where: { $0 == index })
        addedCurrencyIdentifiers.removeAll(where: { $0 == identifier })
    }
    
    private func setupSearchBar() {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 48.0))
        tableView.tableHeaderView = headerView
        headerView.addSubview(searchBar)
        searchBar.delegate = self
        searchBar.constrain([
            searchBar.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            searchBar.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)])
        searchBar.searchBarStyle = .minimal
        searchBar.barStyle = .black
        searchBar.isTranslucent = false
        searchBar.barTintColor = .darkBackground
        searchBar.placeholder = S.Search.search
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension AddWalletsViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayData.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ManageCurrencyCell.cellIdentifier, for: indexPath) as? ManageCurrencyCell else {
            return UITableViewCell()
        }
        
        let currency = displayData[indexPath.row]
        let balance = coreSystem.walletBalance(currencyId: currency.uid)
        let isHidden = !addedCurrencyIdentifiers.contains(currency.uid)
        cell.set(currency: currency,
                 balance: balance,
                 listType: .add,
                 isHidden: isHidden,
                 isRemovable: true)
        cell.didAddIdentifier = { [unowned self] identifier in
            self.addCurrency(identifier)
        }
        cell.didRemoveIdentifier = { [unowned self] identifier in
            self.removeCurrency(identifier)
        }
        return cell
    }
}

extension AddWalletsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            displayData = allAssets
        } else {
            displayData = allAssets.filter {
                return $0.name.lowercased().contains(searchText.lowercased()) || $0.code.lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }
}
