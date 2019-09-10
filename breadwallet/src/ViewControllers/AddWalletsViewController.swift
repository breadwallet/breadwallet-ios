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
    private var displayData = [CurrencyMetaData]()
    private var allAssets = [CurrencyMetaData]()
    private var addedCurrencyIndices = [Int]()
    private var addedCurrencyIdentifiers = [String]()
    private let searchBar = UISearchBar()
    
    init(assetCollection: AssetCollection) {
        self.assetCollection = assetCollection
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        displayData = assetCollection.availableAssets
        allAssets = assetCollection.availableAssets
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reconcileChanges()
    }
    
    private func reconcileChanges() {
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
    
    private func addCurrency(_ identifier: String) {
        guard let index = allAssets.firstIndex(where: {$0.uid == identifier }) else { return assertionFailure() }
        addedCurrencyIndices.append(index)
        addedCurrencyIdentifiers.append(identifier)
    }
    
    private func removeCurrency(_ identifier: String) {
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
        let isHidden = !addedCurrencyIdentifiers.contains(currency.uid)
        cell.set(currency: currency, index: indexPath.row, listType: .add, isHidden: isHidden)
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
