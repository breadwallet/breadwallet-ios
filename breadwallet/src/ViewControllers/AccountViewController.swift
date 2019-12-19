//
//  AccountViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class AccountViewController: UIViewController, Subscriber, Trackable {
    
    // MARK: - Public
    var currency: Currency { return wallet.currency }
    
    init(wallet: Wallet) {
        self.wallet = wallet
        self.headerView = AccountHeaderView(currency: wallet.currency)
        self.footerView = AccountFooterView(currency: wallet.currency)
        self.searchHeaderview = SearchHeaderView()
        super.init(nibName: nil, bundle: nil)
        self.transactionsTableView = TransactionsTableViewController(wallet: wallet, didSelectTransaction: { [unowned self] (transactions, index) in
            self.didSelectTransaction(transactions: transactions, selectedIndex: index)
        })

        footerView.sendCallback = { [unowned self] in
            Store.perform(action: RootModalActions.Present(modal: .send(currency: self.currency))) }
        footerView.receiveCallback = { [unowned self] in
            Store.perform(action: RootModalActions.Present(modal: .receive(currency: self.currency))) }
        footerView.buyCallback = { [unowned self] in
            Store.perform(action: RootModalActions.Present(modal: .buy(currency: self.currency))) }
        footerView.sellCallback = { [unowned self] in
            Store.perform(action: RootModalActions.Present(modal: .sell(currency: self.currency))) }
    }
    
    deinit {
        rewardsShrinkTimer?.invalidate()
        rewardsShrinkTimer = nil
        Store.unsubscribe(self)
    }
    
    // MARK: - Private
    private let wallet: Wallet
    private let headerView: AccountHeaderView
    private let footerView: AccountFooterView
    private var footerHeightConstraint: NSLayoutConstraint?
    private let transitionDelegate = ModalTransitionDelegate(type: .transactionDetail)
    private var transactionsTableView: TransactionsTableViewController!
    private let searchHeaderview: SearchHeaderView
    private let headerContainer = UIView()
    private var loadingTimer: Timer?
    private var shouldShowStatusBar: Bool = true {
        didSet {
            if oldValue != shouldShowStatusBar {
                UIView.animate(withDuration: C.animationDuration) {
                    self.setNeedsStatusBarAppearanceUpdate()
                }
            }
        }
    }
    private var tableViewTopConstraint: NSLayoutConstraint?
    private var headerContainerSearchHeight: NSLayoutConstraint?
    private var rewardsViewHeightConstraint: NSLayoutConstraint?
    private var rewardsView: RewardsView?
    private let rewardsAnimationDuration: TimeInterval = 0.5
    private let rewardsShrinkTimerDuration: TimeInterval = 6.0
    private var rewardsShrinkTimer: Timer?
    private var rewardsTappedEvent: String {
        return makeEventName([EventContext.rewards.name, Event.banner.name])
    }

    var isSearching: Bool = false
    
    private func tableViewTopConstraintConstant(for rewardsViewState: RewardsView.State) -> CGFloat {
        return rewardsViewState == .expanded ? RewardsView.expandedSize : (RewardsView.normalSize)
    }
    
    private var shouldShowRewardsView: Bool {
        return currency.isBRDToken
    }
    
    private var shouldAnimateRewardsView: Bool {
        return shouldShowRewardsView && UserDefaults.shouldShowBRDRewardsAnimation
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        addSubviews()
        addConstraints()
        addTransactionsView()
        addSubscriptions()
        setInitialData()
        
        if shouldShowRewardsView {
            addRewardsView()
        }
        transactionsTableView.didScrollToYOffset = { [unowned self] offset in
            self.headerView.setOffset(offset)
        }
        transactionsTableView.didStopScrolling = { [unowned self] in
            self.headerView.didStopScrolling()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldShowStatusBar = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if shouldAnimateRewardsView {
            expandRewardsView()
        }
        
        saveEvent(makeEventName([EventContext.wallet.name, currency.code, Event.appeared.name]))
    }
    
    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        footerHeightConstraint?.constant = AccountFooterView.height + view.safeAreaInsets.bottom
    }
    
    // MARK: -
    
    private func setupNavigationBar() {
        let searchButton = UIButton(type: .system)
        searchButton.setImage(#imageLiteral(resourceName: "SearchIcon"), for: .normal)
        searchButton.widthAnchor.constraint(equalToConstant: 22.0).isActive = true
        searchButton.heightAnchor.constraint(equalToConstant: 22.0).isActive = true
        searchButton.tintColor = .white
        searchButton.tap = { [unowned self] in
            self.showSearchHeaderView()
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: searchButton)
    }

    private func addSubviews() {
        view.addSubview(headerContainer)
        headerContainer.addSubview(headerView)
        headerContainer.addSubview(searchHeaderview)
        view.addSubview(footerView)
    }

    private func addConstraints() {
        let topConstraint = headerContainer.topAnchor.constraint(equalTo: view.topAnchor)
        topConstraint.priority = .required
        headerContainer.constrain([
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topConstraint,
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        headerView.constrain(toSuperviewEdges: nil)
        searchHeaderview.constrain(toSuperviewEdges: nil)
        headerContainerSearchHeight = headerContainer.heightAnchor.constraint(equalToConstant: AccountHeaderView.headerViewMinHeight)
        
        footerHeightConstraint = footerView.heightAnchor.constraint(equalToConstant: AccountFooterView.height)
        footerView.constrain([
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: -C.padding[1]),
            footerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: C.padding[1]),
            footerHeightConstraint ])
    }

    private func addSubscriptions() {
        Store.subscribe(self, name: .showStatusBar, callback: { [weak self] _ in
            self?.shouldShowStatusBar = true
        })
        Store.subscribe(self, name: .hideStatusBar, callback: { [weak self] _ in
            self?.shouldShowStatusBar = false
        })
    }

    private func setInitialData() {
        searchHeaderview.isHidden = true
        searchHeaderview.didCancel = { [weak self] in
            self?.hideSearchHeaderView()
            self?.isSearching = false
        }
        searchHeaderview.didChangeFilters = { [weak self] filters in
            self?.transactionsTableView.filters = filters
        }
        headerView.setHostContentOffset = { [weak self] offset in
            self?.transactionsTableView.tableView.contentOffset.y = offset
        }
    }
    
    private func addTransactionsView() {
        // Store this constraint so it can be easily updated later when showing/hiding the rewards view.
        tableViewTopConstraint = transactionsTableView.view.topAnchor.constraint(equalTo: headerView.bottomAnchor)
        
        transactionsTableView.view.backgroundColor = .clear
        view.backgroundColor = .white
        addChildViewController(transactionsTableView, layout: {
            transactionsTableView.view.constrain([
                tableViewTopConstraint,
                transactionsTableView.view.bottomAnchor.constraint(equalTo: footerView.topAnchor),
                transactionsTableView.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                transactionsTableView.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)])
        })
        view.sendSubviewToBack(transactionsTableView.view)
    }
        
    // MARK: keyboard management
    
    private func hideSearchKeyboard() {
        isSearching = searchHeaderview.isFirstResponder
        if isSearching {
            _ = searchHeaderview.resignFirstResponder()
        }
    }
    
    private func showSearchKeyboard() {
        _ = searchHeaderview.becomeFirstResponder()
    }
    
    // MARK: show transaction details
    
    private func didSelectTransaction(transactions: [Transaction], selectedIndex: Int) {
        let transactionDetails = TxDetailViewController(transaction: transactions[selectedIndex], delegate: self)
        
        transactionDetails.modalPresentationStyle = .overCurrentContext
        transactionDetails.transitioningDelegate = transitionDelegate
        transactionDetails.modalPresentationCapturesStatusBarAppearance = true
        
        hideSearchKeyboard()
        
        present(transactionDetails, animated: true, completion: nil)
    }
    
    private func showSearchHeaderView() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        headerView.stopHeightConstraint()
        headerContainerSearchHeight?.isActive = true
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.view.layoutIfNeeded()
        })
        
        UIView.transition(from: headerView,
                          to: searchHeaderview,
                          duration: C.animationDuration,
                          options: [.transitionFlipFromBottom, .showHideTransitionViews, .curveEaseOut],
                          completion: { _ in
                            self.searchHeaderview.triggerUpdate()
                            self.setNeedsStatusBarAppearanceUpdate()
        })
    }
    
    private func hideSearchHeaderView() {
        navigationController?.setNavigationBarHidden(false, animated: false)
        headerView.resumeHeightConstraint()
        headerContainerSearchHeight?.isActive = false
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.view.layoutIfNeeded()
        })
        
        UIView.transition(from: searchHeaderview,
                          to: headerView,
                          duration: C.animationDuration,
                          options: [.transitionFlipFromTop, .showHideTransitionViews, .curveEaseOut],
                          completion: { _ in
                            self.setNeedsStatusBarAppearanceUpdate()
        })
    }
    
    // The rewards view is a separate UIView that is displayed in the BRD wallet,
    // under the table view header, above the transaction cells.
    private func addRewardsView() {
        
        let rewards = RewardsView()
        view.addSubview(rewards)
        rewardsView = rewards

        //Rewards view has an intrinsic grey padding view, so it doesn't need top padding.
        let rewardsViewTopConstraint = rewards.topAnchor.constraint(equalTo: headerView.bottomAnchor)
        // Start the rewards view at a height of zero if animating, otherwise at the normal height.
        let initialHeight = shouldAnimateRewardsView ? 0 : RewardsView.normalSize
        rewardsViewHeightConstraint = rewards.heightAnchor.constraint(equalToConstant: initialHeight)
        
        rewards.constrain([
            rewardsViewTopConstraint,
            rewardsViewHeightConstraint,
            rewards.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rewards.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        
        tableViewTopConstraint?.constant = shouldAnimateRewardsView ? 0 : tableViewTopConstraintConstant(for: .normal)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                          action: #selector(rewardsViewTapped))
        rewardsView?.addGestureRecognizer(tapGestureRecognizer)
    }

    private func expandRewardsView() {
        
        if E.isIPhone5 {
            headerView.collapseHeader()
        }
        
        let constants = (tableViewTopConstraintConstant(for: .expanded), RewardsView.expandedSize)
        
        UIView.animate(withDuration: rewardsAnimationDuration, animations: { [unowned self] in
            self.tableViewTopConstraint?.constant = constants.0
            self.rewardsViewHeightConstraint?.constant = constants.1
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            guard let `self` = self else { return }
            
            self.rewardsView?.animateIcon()

            UserDefaults.shouldShowBRDRewardsAnimation = false
            
            self.rewardsShrinkTimer = Timer.scheduledTimer(withTimeInterval: self.rewardsShrinkTimerDuration, repeats: false) { _ in
                self.shrinkRewardsView()
            }
        })
    }
    
    private func shrinkRewardsView() {
        let constants = (tableViewTopConstraintConstant(for: .normal), RewardsView.normalSize)

        UIView.animate(withDuration: rewardsAnimationDuration, animations: {
            self.rewardsView?.shrinkView()
            self.tableViewTopConstraint?.constant = constants.0
            self.rewardsViewHeightConstraint?.constant = constants.1
            self.view.layoutIfNeeded()
        })
    }
    
    @objc private func rewardsViewTapped() {
        saveEvent(rewardsTappedEvent)
        Store.trigger(name: .openPlatformUrl("/rewards"))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return searchHeaderview.isHidden ? .lightContent : .default
    }

    override var prefersStatusBarHidden: Bool {
        return !shouldShowStatusBar
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: TxDetailDelegate
extension AccountViewController: TxDetaiViewControllerDelegate {
    func txDetailDidDismiss(detailViewController: TxDetailViewController) {
        if isSearching {
            // restore the search keyboard that we hid when the transaction details were displayed
            searchHeaderview.becomeFirstResponder()
        }
    }
}
