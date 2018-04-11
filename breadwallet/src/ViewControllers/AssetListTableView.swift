//
//  AssetListTableView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class AssetListTableView: UITableViewController, Subscriber {

    var didSelectCurrency: ((CurrencyDef) -> Void)?
    var didTapSecurity: (() -> Void)?
    var didTapSupport: (() -> Void)?
    var didTapSettings: (() -> Void)?
    var didTapAddWallet: (() -> Void)?
    private let assetHeight: CGFloat = 85.0
    private let menuHeight: CGFloat = 53.0
    private let addWalletContent = (S.MenuButton.addWallet, #imageLiteral(resourceName: "PlaylistPlus"))

    // MARK: - Init
    
    init() {
        super.init(style: .grouped)
    }

    override func viewDidLoad() {
        tableView.backgroundColor = .whiteBackground
        tableView.register(HomeScreenCell.self, forCellReuseIdentifier: HomeScreenCell.cellIdentifier)
        tableView.register(MenuCell.self, forCellReuseIdentifier: MenuCell.cellIdentifier)
        tableView.separatorStyle = .none
        
        tableView.reloadData()
        
        Store.subscribe(self, selector: {
            var result = false
            let oldState = $0
            let newState = $1
            $0.currencies.forEach { currency in
                if oldState[currency].balance != newState[currency].balance
                    || oldState[currency].currentRate?.rate != newState[currency].currentRate?.rate
                    || oldState[currency].maxDigits != newState[currency].maxDigits {
                    result = true
                }
            }
            return result
        }, callback: { _ in
            self.tableView.reloadData()
        })
        
        Store.subscribe(self, selector: {
            $0.currencies.count != $1.currencies.count
        }, callback: { _ in
                self.tableView.reloadData()
            })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.visibleCells.forEach {
            if let cell = $0 as? HomeScreenCell {
                cell.refreshAnimations()
            }
        }
    }
    
    func reload() {
        tableView.reloadData()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Data Source
    
    enum Section: Int {
        case assets
        case menu
    }

    enum Menu: Int {
        case settings
        case security
        case support
        
        var content: (String, UIImage) {
            switch self {
            case .settings:
                return (S.MenuButton.settings, #imageLiteral(resourceName: "Settings"))
            case .security:
                return (S.MenuButton.security, #imageLiteral(resourceName: "Shield"))
            case .support:
                return (S.MenuButton.support, #imageLiteral(resourceName: "Faq"))
            }
        }
        
        static let allItems: [Menu] = [.settings, .security, .support]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        
        switch section {
        case .assets:
            return Store.state.wallets.count + 1
        case .menu:
            return Menu.allItems.count
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(rawValue: indexPath.section) else { return 0 }
        switch section {
        case .assets:
            return isAddWalletRow(row: indexPath.row) ? menuHeight : assetHeight
        case .menu:
            return menuHeight
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }

        if section == .assets && isAddWalletRow(row: indexPath.row) {
            let cell = tableView.dequeueReusableCell(withIdentifier: MenuCell.cellIdentifier, for: indexPath) as! MenuCell
            cell.set(title: addWalletContent.0, icon: addWalletContent.1)
            return cell
        }

        switch section {
        case .assets:
            let currency = Store.state.currencies[indexPath.row]
            let viewModel = AssetListViewModel(currency: currency)

            let cell = tableView.dequeueReusableCell(withIdentifier: HomeScreenCell.cellIdentifier, for: indexPath) as! HomeScreenCell
            cell.set(viewModel: viewModel)
            return cell
        case .menu:
            let cell = tableView.dequeueReusableCell(withIdentifier: MenuCell.cellIdentifier, for: indexPath) as! MenuCell
            guard let item = Menu(rawValue: indexPath.row) else { return cell }
            let content = item.content
            cell.set(title: content.0, icon: content.1)
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }

        switch section {
        case .assets:
            return S.HomeScreen.portfolio
        case .menu:
            return S.HomeScreen.admin
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView,
            let label = header.textLabel else { return }
        label.text = label.text?.capitalized
        label.textColor = .mediumGray
        label.font = .customBody(size: 12.0)
        header.tintColor = tableView.backgroundColor
    }
    
    // MARK: - Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section {
        case .assets:
            isAddWalletRow(row: indexPath.row) ? didTapAddWallet?() : didSelectCurrency?(Store.state.currencies[indexPath.row])
        case .menu:
            guard let item = Menu(rawValue: indexPath.row) else { return }
            switch item {
            case .settings:
                didTapSettings?()
            case .security:
                didTapSecurity?()
            case .support:
                didTapSupport?()
            }
        }
    }

    private func isAddWalletRow(row: Int) -> Bool {
        return row == Store.state.currencies.count
    }
}
