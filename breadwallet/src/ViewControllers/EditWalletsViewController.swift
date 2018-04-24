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

class EditWalletsViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {

    private let type: TokenListType
    private let cellIdentifier = "CellIdentifier"
    private let kvStore: BRReplicatedKVStore
    private let metaData: CurrencyListMetaData
    private var tokens = [StoredTokenData]() {
        didSet {
            tableView.reloadData()
        }
    }

    private var tokenAddressesToBeAdded = [String]() {
        didSet {
            tokens = tokens.map {
                var token = $0
                if tokenAddressesToBeAdded.contains($0.address) {
                    token.isHidden = false
                } else if tokenAddressesToBeRemoved.contains($0.address) {
                    token.isHidden = true
                }
                return token
            }
        }
    }
    private var tokenAddressesToBeRemoved = [String]() {
        didSet {
            tokens = tokens.map {
                var token = $0
                if tokenAddressesToBeRemoved.contains($0.address) {
                    token.isHidden = true
                } else if tokenAddressesToBeAdded.contains($0.address) {
                    token.isHidden = false
                }
                return token
            }
        }
    }
    private let tableView = UITableView()
    
    init(type: TokenListType, kvStore: BRReplicatedKVStore) {
        self.type = type
        self.kvStore = kvStore
        self.metaData = CurrencyListMetaData(kvStore: kvStore)!
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(tableView)
        if #available(iOS 11.0, *) {
            tableView.constrain([
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        } else {
            tableView.constrain([
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.topAnchor.constraint(equalTo: view.topAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        }
        tableView.delegate = self
        tableView.dataSource = self
        title = type.title
        tableView.register(TokenCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .none
        StoredTokenData.fetchTokens(callback: { [weak self] in
            guard let `self` = self else { return }
            switch self.type {
            case .add:
                self.tokens = $0.filter { !self.metaData.previouslyAddedTokenAddresses.contains($0.address) }.map {
                    var token = $0
                    token.isHidden = true
                    return token
                }
            case .manage:
                let addedTokens = $0.filter { self.metaData.enabledTokenAddresses.contains($0.address) }
                var hiddenTokens = $0.filter { self.metaData.hiddenTokenAddresses.contains($0.address) }
                hiddenTokens = hiddenTokens.map {
                    var token = $0
                    token.isHidden = true
                    return token
                }
                self.tokens = addedTokens + hiddenTokens
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reconcileChanges()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tokens.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? TokenCell else { return UITableViewCell() }
        cell.set(token: tokens[indexPath.row], listType: type)
        cell.didAddToken = { [unowned self] address in
            if !self.tokenAddressesToBeAdded.contains(address) {
                self.tokenAddressesToBeAdded.append(address)
            }
            self.tokenAddressesToBeRemoved = self.tokenAddressesToBeRemoved.filter { $0 != address }
        }
        cell.didRemoveToken = { [unowned self] address in
            self.tokenAddressesToBeAdded = self.tokenAddressesToBeAdded.filter { $0 != address }
            if !self.tokenAddressesToBeRemoved.contains(address) {
                self.tokenAddressesToBeRemoved.append(address)
            }
        }
        return cell
    }
    
    private func reconcileChanges() {
        switch type {
        case .add:
            addAddedTokens()
        case .manage:
            removeRemovedTokens()
            addAddedTokens()
        }
    }
    
    private func addAddedTokens() {
        guard tokenAddressesToBeAdded.count > 0 else { return }
        var currentWalletCount = Store.state.wallets.values.count
        let newWallets: [String: WalletState] = tokens.filter {
            return self.tokenAddressesToBeAdded.contains($0.address)
        }.map {
            ERC20Token(tokenData: $0)
            }.reduce([String: WalletState]()) { (dictionary, currency) -> [String: WalletState] in
                var dictionary = dictionary
                dictionary[currency.code] = WalletState.initial(currency, displayOrder: currentWalletCount)
                currentWalletCount = currentWalletCount + 1
                return dictionary
        }
        metaData.addTokenAddresses(addresses: tokenAddressesToBeAdded)
        save()
        Store.perform(action: ManageWallets.addWallets(newWallets))
    }
    
    private func removeRemovedTokens() {
        guard tokenAddressesToBeRemoved.count > 0 else { return }
        metaData.removeTokenAddresses(addresses: tokenAddressesToBeRemoved)
        save()
        Store.perform(action: ManageWallets.removeTokenAddresses(tokenAddressesToBeRemoved))
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

struct StoredTokenData : Codable {
    let address: String
    let name: String
    let code: String
    let colors: [String]
    let decimal: String
    //extras not in json
    var isHidden = false
    
    private enum CodingKeys: String, CodingKey {
        case address
        case name
        case code
        case colors
        case decimal
    }
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
        return StoredTokenData(address: E.isTestnet ?  "0x722dd3f80bac40c951b51bdd28dd19d435762180" : "0x3efd578b271d034a69499e4a2d933c631d44b9ad", name: "Test Token", code: "TST", colors: ["2FB8E6", "2FB8E6"], decimal: "18", isHidden: false)
    }
    //this is a random token I was airdropped...using for testing
    static var viu: StoredTokenData {
        return StoredTokenData(address: "0x519475b31653e46d20cd09f9fdcf3b12bdacb4f5", name: "VIU Token", code: "VIU", colors: ["2FB8E6", "2FB8E6"], decimal: "18", isHidden: false)
    }
}
