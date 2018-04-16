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
}

class TokenListViewController : UITableViewController {

    private let type: TokenListType
    private let cellIdentifier = "CellIdentifier"
    private let kvStore: BRReplicatedKVStore
    private let metaData: CurrencyListMetaData
    private var tokens = [StoredTokenData]() {
        didSet {
            tableView.reloadData()
        }
    }

    private var tokenAddressesToBeAdded = [String]()
    
    init(type: TokenListType, kvStore: BRReplicatedKVStore) {
        self.type = type
        self.kvStore = kvStore
        self.metaData = CurrencyListMetaData(kvStore: kvStore)!
        super.init(style: .plain)
    }

    override func viewDidLoad() {
        title = S.TokenList.title
        tableView.register(TokenCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .none
        StoredTokenData.fetchTokens(callback: {
            self.tokens = $0.filter { !self.metaData.previouslyAddedTokenAddresses.contains($0.address) }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        addAddedTokens()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tokens.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? TokenCell else { return UITableViewCell() }
        let token = tokens[indexPath.row]
        cell.set(name: token.name, code: token.code, address: token.address)
        cell.didAddToken = { [unowned self] address in
            if !self.tokenAddressesToBeAdded.contains(address) {
                self.tokenAddressesToBeAdded.append(address)
            }
        }
        cell.didRemoveToken = { [unowned self] address in
            self.tokenAddressesToBeAdded = self.tokenAddressesToBeAdded.filter { $0 != address }
        }
        return cell
    }
    
    private func addAddedTokens() {
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
        do {
            let _ = try kvStore.set(metaData)
        } catch let error {
            print("error setting wallet info: \(error)")
        }
        Store.perform(action: ManageWallets.addWallets(newWallets))
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
}

extension StoredTokenData {
    static func fetchTokens(callback: @escaping ([StoredTokenData])->Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let path = Bundle.main.path(forResource: "tokens", ofType: "json")
                let data = try Data(contentsOf: URL(fileURLWithPath: path!))
                let tokens = try JSONDecoder().decode([StoredTokenData].self, from: data)
                DispatchQueue.main.async {
                    callback(tokens)
                }
            } catch let e {
                print("json errro: \(e)")
            }
        }
    }
}
