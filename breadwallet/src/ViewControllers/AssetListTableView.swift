//
//  AssetListTableView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-04.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class AssetListTableView: UITableViewController, Subscriber {

    var didSelectCurrency: ((Currency) -> Void)?
    var didTapAddWallet: (() -> Void)?
    
    let loadingSpinner = UIActivityIndicatorView(style: .white)

    private let assetHeight: CGFloat = 80.0 // rowHeight of 72 plus 8 padding
    private let addWalletButtonHeight: CGFloat = 56.0
    private let addWalletButton = UIButton()

    // MARK: - Init
    
    init() {
        super.init(style: .plain)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupAddWalletButton()
        if Store.state.wallets.isEmpty {
            showLoadingState(true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = .darkBackground
        tableView.register(HomeScreenCell.self, forCellReuseIdentifier: HomeScreenCellIds.regularCell.rawValue)
        tableView.register(HomeScreenHiglightableCell.self, forCellReuseIdentifier: HomeScreenCellIds.highlightableCell.rawValue)
        tableView.separatorStyle = .none
        tableView.rowHeight = assetHeight
        tableView.contentInset = UIEdgeInsets(top: C.padding[1], left: 0, bottom: C.padding[2], right: 0)

        setupSubscriptions()
        reload()
    }
    
    private func setupAddWalletButton() {
        let topInset: CGFloat = 0
        let leftRightInset: CGFloat = C.padding[1]
        let width = tableView.frame.width - tableView.contentInset.left - tableView.contentInset.right
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: addWalletButtonHeight))
        
        addWalletButton.titleLabel?.font = Theme.body1
        
        addWalletButton.tintColor = Theme.tertiaryBackground
        addWalletButton.setTitleColor(Theme.tertiaryText, for: .normal)
        addWalletButton.setTitleColor(.transparentWhite, for: .highlighted)
        addWalletButton.titleLabel?.font = Theme.body1
        
        addWalletButton.imageView?.contentMode = .scaleAspectFit
        addWalletButton.setBackgroundImage(UIImage(named: "add"), for: .normal)
        
        addWalletButton.contentHorizontalAlignment = .center
        addWalletButton.contentVerticalAlignment = .center

        let buttonTitle = S.MenuButton.manageWallets
        addWalletButton.setTitle(buttonTitle, for: .normal)
        addWalletButton.accessibilityLabel = E.isScreenshots ? "Manage Wallets" : buttonTitle

        addWalletButton.addTarget(self, action: #selector(addWallet), for: .touchUpInside)

        addWalletButton.frame = CGRect(x: leftRightInset, y: topInset,
                                       width: footerView.frame.width - (2 * leftRightInset),
                                       height: addWalletButtonHeight)
        
        footerView.addSubview(addWalletButton)
        footerView.backgroundColor = .darkBackground
        tableView.tableFooterView = footerView
    }
    
    private func setupSubscriptions() {
        Store.lazySubscribe(self, selector: {
            var result = false
            let oldState = $0
            let newState = $1
            $0.wallets.values.map { $0.currency }.forEach { currency in
                if oldState[currency]?.balance != newState[currency]?.balance
                    || oldState[currency]?.currentRate?.rate != newState[currency]?.currentRate?.rate {
                    result = true
                }
            }
            return result
        }, callback: { _ in
            self.reload()
        })
        
        Store.lazySubscribe(self, selector: {
            $0.currencies.map { $0.code } != $1.currencies.map { $0.code }
        }, callback: { _ in
            self.reload()
        })
    }
    
    @objc func addWallet() {
        didTapAddWallet?()
    }
    
    func reload() {
        tableView.reloadData()
        showLoadingState(false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Store.state.currencies.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let currency = Store.state.currencies[indexPath.row]
        let viewModel = HomeScreenAssetViewModel(currency: currency)
        
        let cellIdentifier = (shouldHighlightCell(for: currency) ? HomeScreenCellIds.highlightableCell : HomeScreenCellIds.regularCell).rawValue
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        
        if let highlightable: HighlightableCell = cell as? HighlightableCell {
            handleCellHighlightingOnDisplay(cell: highlightable, currency: currency)
        }
        
        if let cell = cell as? HomeScreenCell {
            cell.set(viewModel: viewModel)
        }
        return cell
    }
    
    // MARK: - Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let currency = Store.state.currencies[indexPath.row]
        // If a currency has a wallet, home screen cells are always tap-able
        // Also, if HBAR account creation is required, it is also tap-able
        guard (currency.wallet != nil) ||
            //Only an HBAR wallet requiring creation can go to the account screen without a wallet
            (currency.isHBAR && Store.state.requiresCreation(currency)) else { return }
        
        didSelectCurrency?(currency)
        handleCellHighlightingOnSelect(indexPath: indexPath, currency: currency)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return assetHeight
    }
}

// loading state management
extension AssetListTableView {
    
    func showLoadingState(_ show: Bool) {
        showLoadingIndicator(show)
        showAddWalletsButton(!show)
    }
    
    func showLoadingIndicator(_ show: Bool) {
        guard show else {
            loadingSpinner.removeFromSuperview()
            return
        }
        
        view.addSubview(loadingSpinner)
        
        loadingSpinner.constrain([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        
        loadingSpinner.startAnimating()
    }
    
    func showAddWalletsButton(_ show: Bool) {
        addWalletButton.isHidden = !show
    }
}

// cell highlighting
extension AssetListTableView {
    
    func shouldHighlightCell(for currency: Currency) -> Bool {
        // Currently the only currency/wallet we highlight is BRD.
        guard currency.isBRDToken else { return false }
        return UserDefaults.shouldShowBRDCellHighlight
    }
    
    func clearShouldHighlightForCurrency(currency: Currency) {
        guard currency.isBRDToken else { return }
        UserDefaults.shouldShowBRDCellHighlight = false
    }
    
    func handleCellHighlightingOnDisplay(cell: HighlightableCell, currency: Currency) {
        guard shouldHighlightCell(for: currency) else { return }
        cell.highlight()
    }
    
    func handleCellHighlightingOnSelect(indexPath: IndexPath, currency: Currency) {
        guard shouldHighlightCell(for: currency) else { return }
        guard let highlightable: HighlightableCell = tableView.cellForRow(at: indexPath) as? HighlightableCell else { return }
        
        highlightable.unhighlight()
        clearShouldHighlightForCurrency(currency: currency)
    }
}
