//
//  TokenListViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-08.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

enum TokenListType {
    case manage
    case add
    
    var title: String {
        switch self {
        case .manage:
            return S.TokenList.manageTitle
        case .add:
            return S.TokenList.addTitle
        }
    }
    
    var addTitle: String {
        switch self {
        case .manage:
            return S.TokenList.show
        case .add:
            return S.TokenList.add
        }
    }
    
    var removeTitle: String {
        switch self {
        case .manage:
            return S.TokenList.hide
        case .add:
            return S.TokenList.remove
        }
    }
}

class EditWalletsViewController: UIViewController, Subscriber {
    
    struct Wallet {
        var currency: Currency
        var isHidden: Bool
    }

    private let type: TokenListType
    private let kvStore: BRReplicatedKVStore
    private var metaData: CurrencyListMetaData
    //TODO:CRYPTO default currencies
    private let localCurrencies: [Currency] = []//[Currencies.btc, Currencies.bch, Currencies.eth, Currencies.brd]
    private let tableView = UITableView()
    private let searchBar = UISearchBar()

    private let addWalletButtonHeight: CGFloat = 72.0
    
    private var wallets = [Wallet]() {
        didSet { tableView.reloadData() }
    }

    private var allWallets = [Wallet]()

    init(type: TokenListType, kvStore: BRReplicatedKVStore) {
        self.type = type
        self.kvStore = kvStore
        self.metaData = CurrencyListMetaData(kvStore: kvStore)!
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .darkBackground
        view.addSubview(tableView)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: C.padding[2], right: 0)
        tableView.backgroundColor = .darkBackground
        tableView.keyboardDismissMode = .interactive
        tableView.separatorStyle = .none
        tableView.rowHeight = 66.0
        tableView.constrain([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        tableView.constrain([
                tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)])
        
        view.layoutIfNeeded()
        
        if type == .manage {
            tableView.setEditing(true, animated: true)
            setupAddButton()    // adds te Add Wallet button to the table view footer
        }

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TokenCell.self, forCellReuseIdentifier: TokenCell.cellIdentifier)

        setupSearchBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        Store.subscribe(self,
                        selector: { $0.availableTokens != $1.availableTokens },
                        callback: {
                            let tokens = $0.availableTokens
                            assert(tokens.count > 1, "missing token list")
                            self.metaData = CurrencyListMetaData(kvStore: self.kvStore)!
                            switch self.type {
                            case .add:
                                self.setAddModel(storedCurrencies: tokens.filter({ $0.isSupported }))
                            case .manage:
                                self.setManageModel(storedCurrencies: tokens)
                            }
        })
        title = type.title
    }

    // MARK: - 
    
    private func setupSearchBar() {
        guard type == .add else { return }
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

    private func setupAddButton() {
        
        let topInset: CGFloat = C.padding[1]
        let leftRightInset: CGFloat = C.padding[2]
        let width = tableView.frame.width - tableView.contentInset.left - tableView.contentInset.right
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: addWalletButtonHeight))
        
        let addButton = UIButton()
        
        addButton.tintColor = .disabledWhiteText
        addButton.setTitleColor(Theme.tertiaryText, for: .normal)
        addButton.setTitleColor(.transparentWhite, for: .highlighted)
        addButton.titleLabel?.font = Theme.body1
        
        addButton.imageView?.contentMode = .scaleAspectFit
        addButton.setBackgroundImage(UIImage(named: "add"), for: .normal)
        
        addButton.contentHorizontalAlignment = .center
        addButton.contentVerticalAlignment = .center
        
        let buttonTitle = "+ " + S.TokenList.addTitle
        addButton.setTitle(buttonTitle, for: .normal)
        addButton.accessibilityLabel = E.isScreenshots ? "Add Wallet" : buttonTitle
        
        addButton.tap = { [weak self] in
            guard let `self` = self else { return }
            self.pushAddWallets()
        }
        
        addButton.frame = CGRect(x: leftRightInset, y: topInset,
                                       width: footerView.frame.width - (2 * leftRightInset),
                                       height: addWalletButtonHeight)
        
        footerView.addSubview(addButton)
        footerView.backgroundColor = Theme.primaryBackground
        tableView.tableFooterView = footerView

        /*
        
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 70.0))
        tableView.tableFooterView = footerView
        let addButton = UIButton.icon(image: #imageLiteral(resourceName: "add"), title: S.TokenList.addTitle)
        addButton.tintColor = .disabledWhiteText
        addButton.setTitleColor(.disabledWhiteText, for: .normal)
        footerView.addSubview(addButton)
        addButton.constrain(toSuperviewEdges: UIEdgeInsets.init(top: 10, left: 0, bottom: 10, right: 0))
        addButton.tap = {
            self.pushAddWallets()
        }
        */
    }

    private func pushAddWallets() {
        let addWallets = EditWalletsViewController(type: .add, kvStore: kvStore)
        navigationController?.pushViewController(addWallets, animated: true)
    }

    private func setManageModel(storedCurrencies: [Currency]) {
        let allCurrencies: [Currency] = storedCurrencies + localCurrencies
        let enabledCurrencies = findCurrencies(inKeyList: metaData.enabledCurrencies, fromCurrencies: allCurrencies)
        let hiddenCurrencies = findCurrencies(inKeyList: metaData.hiddenCurrencies, fromCurrencies: allCurrencies)
        wallets = enabledCurrencies.map { Wallet(currency: $0, isHidden: false) } + hiddenCurrencies.map { Wallet(currency: $0, isHidden: true) }
    }

    private func setAddModel(storedCurrencies: [Currency]) {
        // For adding wallets, filter out the ones that have already been added.
        wallets = storedCurrencies
            .filter { !self.metaData.isAddressAlreadyAdded(address: $0.tokenAddress ?? "") }
            .map { Wallet(currency: $0, isHidden: true) }
        allWallets = wallets
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reconcileChanges()
        title = ""
        Store.unsubscribe(self)
    }

    private func reconcileChanges() {
        switch type {
        case .add:
            addAddedTokens()
        case .manage:
            mergeChanges()
        }
    }

    private func editCurrency(identifier: String, isHidden: Bool) {
        wallets = wallets.map { wallet in
            if currencyMatchesCode(currency: wallet.currency, identifier: identifier) {
                return Wallet(currency: wallet.currency, isHidden: isHidden)
            } else {
                return wallet
            }
        }
        allWallets = allWallets.map { wallet in
            if currencyMatchesCode(currency: wallet.currency, identifier: identifier) {
                return Wallet(currency: wallet.currency, isHidden: isHidden)
            } else {
                return wallet
            }
        }
    }

    private func addAddedTokens() {
        let tokensToBeAdded: [Currency] = allWallets
            .filter { $0.isHidden == false && $0.currency.isERC20Token }
            .map { $0.currency }
        var displayOrder = Store.state.displayCurrencies.count
        let newWallets: [String: WalletState] = tokensToBeAdded.reduce([String: WalletState]()) { (dictionary, currency) -> [String: WalletState] in
            var dictionary = dictionary
            dictionary[currency.code] = WalletState.initial(currency, displayOrder: displayOrder)
            displayOrder += 1
            return dictionary
        }
        //TODO:CRYPTO token address
        metaData.addTokenAddresses(addresses: tokensToBeAdded.map { $0.tokenAddress! })
        save()
        Store.perform(action: ManageWallets.AddWallets(newWallets))
    }
    
    private func mergeChanges() {

        let oldWallets = Store.state.wallets
        var newWallets = [String: WalletState]()
        var displayOrder = 0
        wallets.forEach { entry in
            let currency = entry.currency
            let isHidden = entry.isHidden
            
            //Hidden local wallets get a displayOrder of -1
            let localCurrencyCodes = localCurrencies.map { $0.code.lowercased() }
            if localCurrencyCodes.contains(currency.code.lowercased()) {
                var walletState = oldWallets[currency.code]!
                if isHidden {
                    walletState = walletState.mutate(displayOrder: -1)
                } else {
                    walletState = walletState.mutate(displayOrder: displayOrder)
                    displayOrder += 1
                }
                newWallets[currency.code] = walletState

            //Hidden tokens, except for brd, get removed from the wallet state
            } else {
                if let walletState = oldWallets[currency.code] {
                    if isHidden {
                        newWallets[currency.code] = nil
                    } else {
                        newWallets[currency.code] = walletState.mutate(displayOrder: displayOrder)
                        displayOrder += 1
                    }
                } else {
                    if isHidden == false {
                        let newWalletState = WalletState.initial(currency, displayOrder: displayOrder)
                        displayOrder += 1
                        newWallets[currency.code] = newWalletState
                    }
                }
            }
        }

        //Save new metadata
        metaData.enabledCurrencies = wallets.compactMap {
            guard $0.isHidden == false else { return nil}
            if let tokenAddress = $0.currency.tokenAddress {
                return C.erc20Prefix + tokenAddress
            } else {
                return $0.currency.code
            }
        }
        metaData.hiddenCurrencies = wallets.compactMap {
            guard $0.isHidden == true else { return nil}
            if let tokenAddress = $0.currency.tokenAddress {
                return C.erc20Prefix + tokenAddress
            } else {
                return $0.currency.code
            }
        }
        save()

        //Apply new state
        Store.perform(action: ManageWallets.SetWallets(newWallets))
    }
    
    private func save() {
        do {
            _ = try kvStore.set(metaData)
        } catch let error {
            print("error setting wallet info: \(error)")
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension EditWalletsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wallets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TokenCell.cellIdentifier, for: indexPath) as? TokenCell else { return UITableViewCell() }
        cell.set(currency: wallets[indexPath.row].currency, listType: type, isHidden: wallets[indexPath.row].isHidden)
        cell.didAddIdentifier = { [unowned self] identifier in
            self.editCurrency(identifier: identifier, isHidden: false)
        }
        cell.didRemoveIdentifier = { [unowned self] identifier in
            self.editCurrency(identifier: identifier, isHidden: true)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedObject = wallets[sourceIndexPath.row]
        wallets.remove(at: sourceIndexPath.row)
        wallets.insert(movedObject, at: destinationIndexPath.row)
    }
}

extension EditWalletsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            wallets = allWallets
        } else {
            wallets = allWallets.filter {
                return $0.currency.name.lowercased().contains(searchText.lowercased()) || $0.currency.code.lowercased().contains(searchText.lowercased())
            }
        }
    }
}

extension EditWalletsViewController {
    private func findCurrencies(inKeyList keys: [String], fromCurrencies: [Currency]) -> [Currency] {
        return keys.compactMap { codeOrAddress in
            let codeOrAddress = codeOrAddress.replacingOccurrences(of: C.erc20Prefix, with: "")
            var currency: Currency?
            fromCurrencies.forEach {
                if currencyMatchesCode(currency: $0, identifier: codeOrAddress) {
                    currency = $0
                }
            }
            assert(currency != nil || E.isTestnet)
            return currency
        }
    }

    private func currencyMatchesCode(currency: Currency, identifier: String) -> Bool {
        if currency.code.lowercased() == identifier.lowercased() {
            return true
        }
        if let tokenAddress = currency.tokenAddress, tokenAddress.lowercased() == identifier.lowercased() {
            return true
        }
        return false
    }
}
