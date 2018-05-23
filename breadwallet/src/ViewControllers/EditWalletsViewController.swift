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

class EditWalletsViewController : UIViewController {

    private let type: TokenListType
    private let cellIdentifier = "CellIdentifier"
    private let kvStore: BRReplicatedKVStore
    private var metaData: CurrencyListMetaData
    private let localCurrencies: [CurrencyDef] = [Currencies.btc, Currencies.bch, Currencies.eth, Currencies.brd]
    private let tableView = UITableView()
    private let searchBar = UISearchBar()

    //(Currency, isHidden)
    private var model = [(CurrencyDef, Bool)]() {
        didSet { tableView.reloadData() }
    }

    private var allModels = [(CurrencyDef, Bool)]()

    init(type: TokenListType, kvStore: BRReplicatedKVStore) {
        self.type = type
        self.kvStore = kvStore
        self.metaData = CurrencyListMetaData(kvStore: kvStore)!
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(tableView)
        tableView.keyboardDismissMode = .interactive
        tableView.constrain([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        if #available(iOS 11.0, *) {
            tableView.constrain([
                tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)])
        } else {
            tableView.constrain([
                tableView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor)])
            automaticallyAdjustsScrollViewInsets = false
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TokenCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsetsMake(0, C.padding[2], 0, C.padding[2])

        if type == .manage {
            tableView.setEditing(true, animated: true)
            addMenuButton()
        }
        addSearchBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        StoredTokenData.fetchTokens(callback: { [weak self] in
            guard let `self` = self else { return }
            self.metaData = CurrencyListMetaData(kvStore: self.kvStore)!
            switch self.type {
            case .add:
                self.setAddModel(storedCurrencies: $0.map{ ERC20Token(tokenData: $0) })
            case .manage:
                self.setManageModel(storedCurrencies: $0.map{ ERC20Token(tokenData: $0) })
            }
        })
        title = type.title
    }


    private func addSearchBar() {
        guard type == .add else { return }
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 48.0))
        tableView.tableHeaderView = headerView
        headerView.addSubview(searchBar)
        searchBar.delegate = self
        searchBar.constrain([
            searchBar.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: C.padding[1]),
            searchBar.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -C.padding[1]),
            searchBar.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)])
        searchBar.backgroundImage = UIImage()
        searchBar.placeholder = S.Search.search
    }

    private func addMenuButton() {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 56.0))
        tableView.tableFooterView = footerView
        let menuButton = MenuButton(title: S.MenuButton.addWallet, icon: #imageLiteral(resourceName: "PlaylistPlus"))
        footerView.addSubview(menuButton)
        menuButton.constrain(toSuperviewEdges: UIEdgeInsetsMake(0, 0, 0, 0))
        menuButton.tap = {
            self.pushAddWallets()
        }
    }

    private func pushAddWallets() {
        let addWallets = EditWalletsViewController(type: .add, kvStore: kvStore)
        navigationController?.pushViewController(addWallets, animated: true)
    }

    private func setManageModel(storedCurrencies: [CurrencyDef]) {
        let allCurrencies: [CurrencyDef] = storedCurrencies + localCurrencies
        let enabledCurrencies = findCurrencies(fromList: metaData.enabledCurrencies, fromCurrencies: allCurrencies)
        let hiddenCurrencies = findCurrencies(fromList: metaData.hiddenCurrencies, fromCurrencies: allCurrencies)
        model = enabledCurrencies.map { ($0, false) } + hiddenCurrencies.map { ($0, true) }
    }

    private func setAddModel(storedCurrencies: [CurrencyDef]) {
        model = storedCurrencies.filter { !self.metaData.previouslyAddedTokenAddresses.contains(($0 as! ERC20Token).address)}.map{($0, true)}
        allModels = model
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reconcileChanges()
        title = ""
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
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
        model = model.map { row in
            if currencyMatchesCode(currency: row.0, identifier: identifier) {
                return (row.0, isHidden)
            } else {
                return row
            }
        }
        allModels = allModels.map { row in
            if currencyMatchesCode(currency: row.0, identifier: identifier) {
                return (row.0, isHidden)
            } else {
                return row
            }
        }
    }

    private func addAddedTokens() {
        let tokensToBeAdded: [ERC20Token] = model.filter { $0.1 == false }.map{ $0.0 as! ERC20Token }
        var displayOrder = Store.state.displayCurrencies.count
        let newWallets: [String: WalletState] = tokensToBeAdded.reduce([String: WalletState]()) { (dictionary, currency) -> [String: WalletState] in
            var dictionary = dictionary
            dictionary[currency.code] = WalletState.initial(currency, displayOrder: displayOrder)
            displayOrder = displayOrder + 1
            return dictionary
        }
        metaData.addTokenAddresses(addresses: tokensToBeAdded.map{ $0.address })
        save()
        Store.perform(action: ManageWallets.addWallets(newWallets))
    }
    
    private func mergeChanges() {

        let oldWallets = Store.state.wallets
        var newWallets = [String: WalletState]()
        var displayOrder = 0
        model.forEach { currency in

            //Hidden local wallets get a displayOrder of -1
            let localCurrencyCodes = localCurrencies.map { $0.code.lowercased() }
            if localCurrencyCodes.contains(currency.0.code.lowercased()) {
                var walletState = oldWallets[currency.0.code]!
                if currency.1 {
                    walletState = walletState.mutate(displayOrder: -1)
                } else {
                    walletState = walletState.mutate(displayOrder: displayOrder)
                    displayOrder = displayOrder + 1
                }
                newWallets[currency.0.code] = walletState

            //Hidden tokens, except for brd, get removed from the wallet state
            } else {
                if let walletState = oldWallets[currency.0.code] {
                    if currency.1 {
                        newWallets[currency.0.code] = nil
                    } else {
                        newWallets[currency.0.code] = walletState.mutate(displayOrder: displayOrder)
                        displayOrder = displayOrder + 1
                    }
                } else {
                    if currency.1 == false {
                        let newWalletState = WalletState.initial(currency.0, displayOrder: displayOrder)
                        displayOrder = displayOrder + 1
                        newWallets[currency.0.code] = newWalletState
                    }
                }
            }
        }

        //Save new metadata
        metaData.enabledCurrencies = model.compactMap {
            guard $0.1 == false else { return nil}
            if let token = $0.0 as? ERC20Token {
                return C.erc20Prefix + token.address
            } else {
                return $0.0.code
            }
        }
        metaData.hiddenCurrencies = model.compactMap {
            guard $0.1 == true else { return nil}
            if let token = $0.0 as? ERC20Token {
                return C.erc20Prefix + token.address
            } else {
                return $0.0.code
            }
        }
        save()

        //Apply new state
        Store.perform(action: ManageWallets.setWallets(newWallets))
    }
    
    private func save() {
        do {
            let _ = try kvStore.set(metaData)
        } catch let error {
            print("error setting wallet info: \(error)")
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension EditWalletsViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? TokenCell else { return UITableViewCell() }
        cell.set(currency: model[indexPath.row].0, listType: type, isHidden: model[indexPath.row].1)
        cell.didAddIdentifier = { [unowned self] identifier in
            self.editCurrency(identifier: identifier, isHidden: false)
        }
        cell.didRemoveIdentifier = { [unowned self] identifier in
            self.editCurrency(identifier: identifier, isHidden: true)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedObject = model[sourceIndexPath.row]
        model.remove(at: sourceIndexPath.row)
        model.insert(movedObject, at: destinationIndexPath.row)
    }
}

extension EditWalletsViewController : UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == "" {
            model = allModels
        } else {
            model = allModels.filter {
                return $0.0.name.lowercased().contains(searchText.lowercased()) || $0.0.code.lowercased().contains(searchText.lowercased())
            }
        }
    }
}

extension EditWalletsViewController {
    private func findCurrencies(fromList: [String], fromCurrencies: [CurrencyDef]) -> [CurrencyDef] {
        return fromList.compactMap { codeOrAddress in
            let codeOrAddress = codeOrAddress.replacingOccurrences(of: C.erc20Prefix, with: "")
            var currency: CurrencyDef? = nil
            fromCurrencies.forEach {
                if currencyMatchesCode(currency: $0, identifier: codeOrAddress) {
                    currency = $0
                }
            }
            assert(currency != nil || E.isTestnet)
            return currency
        }
    }

    private func currencyMatchesCode(currency: CurrencyDef, identifier: String) -> Bool {
        if currency.code.lowercased() == identifier.lowercased() {
            return true
        }
        if let token = currency as? ERC20Token {
            if token.address.lowercased() == identifier.lowercased() {
                return true
            }
        }
        return false
    }
}

struct StoredTokenData : Codable {
    let address: String
    let name: String
    let code: String
    let colors: [String]
    let decimal: String
}

extension StoredTokenData {
    static func fetchTokens(callback: @escaping ([StoredTokenData])->Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let path = Bundle.main.path(forResource: "tokens", ofType: "json")
                let data = try Data(contentsOf: URL(fileURLWithPath: path!))
                var tokens = try JSONDecoder().decode([StoredTokenData].self, from: data)
                if E.isDebug {
                    tokens.append(StoredTokenData.tst)
                    tokens.append(StoredTokenData.viu)
                }
                DispatchQueue.main.async {
                    callback(tokens)
                }
            } catch let e {
                print("json errro: \(e)")
            }
        }
    }
}

extension StoredTokenData {
    static var tst: StoredTokenData {
        return StoredTokenData(address: E.isTestnet ?  "0x722dd3f80bac40c951b51bdd28dd19d435762180" : "0x3efd578b271d034a69499e4a2d933c631d44b9ad", name: "Test Token", code: "TST", colors: ["2FB8E6", "2FB8E6"], decimal: "18")
    }
    //this is a random token I was airdropped...using for testing
    static var viu: StoredTokenData {
        return StoredTokenData(address: "0x519475b31653e46d20cd09f9fdcf3b12bdacb4f5", name: "VIU Token", code: "VIU", colors: ["2FB8E6", "2FB8E6"], decimal: "18")
    }
}
