//
//  CurrencyList.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-09-22.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

extension NSNotification.Name {
    static let SwitchCurrencyNotification = NSNotification.Name("SwitchCurrencyNotification")
}

class CurrencyList : UITableViewController {

    private let cellIdentifier = "CellIdentifier"

    override func viewDidLoad() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 200.0) ])
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.text = indexPath.row == 0 ? "Bitcoin" : "Ethereum"
        cell.textLabel?.font = UIFont.customBody(size: 15.0)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        parent?.dismiss(animated: true, completion: {
            if indexPath.row == 0 {
                NotificationCenter.default.post(name: .SwitchCurrencyNotification, object: nil, userInfo: ["currency": "btc"])
            } else {
                NotificationCenter.default.post(name: .SwitchCurrencyNotification, object: nil, userInfo: ["currency": "eth"])
            }
        })
    }
}

extension CurrencyList : ModalDisplayable {
    var modalTitle: String {
        return "Switch Currency"
    }

    var faqArticleId: String? {
        return nil
    }
}
