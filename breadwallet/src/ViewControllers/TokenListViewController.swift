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

    private var tokens = [TokenData]() {
        didSet {
            tableView.reloadData()
        }
    }

    init(type: TokenListType) {
        self.type = type
        super.init(style: .plain)
    }

    override func viewDidLoad() {
        tableView.register(TokenCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.separatorStyle = .none
        fetchTokens(callback: {
            self.tokens = $0
        })
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
        cell.set(name: token.name, symbol: token.symbol)
        return cell
    }

    private func fetchTokens(callback: @escaping ([TokenData])->Void) {
        do {
            let path = Bundle.main.path(forResource: "SampleTokens", ofType: "json")
            let data = try Data(contentsOf: URL(fileURLWithPath: path!))
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            DispatchQueue.main.async {
                callback(tokenResponse.tokens)
            }
        } catch let e {
            print("json errro: \(e)")
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct TokenData : Codable {
    let address: String
    let name: String
    let symbol: String
}

private struct TokenResponse : Codable {
    let tokens: [TokenData]
}
