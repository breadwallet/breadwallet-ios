//
//  AccountViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore
import MachO

let accountHeaderHeight: CGFloat = 152.0
let accountFooterHeight: CGFloat = 56.0
private let transactionsLoadingViewHeightConstant: CGFloat = 48.0

class AccountViewController : UIViewController, Subscriber {

    var walletManager: WalletManager? {
        didSet {
            guard let walletManager = walletManager else { return }
            transactionsTableView.walletManager = walletManager
            headerView.isWatchOnly = walletManager.isWatchOnly
        }
    }

    init(currency: CurrencyDef) {
        self.currency = currency
        self.headerView = AccountHeaderView(currency: currency)
        super.init(nibName: nil, bundle: nil)
        self.transactionsTableView = TransactionsTableViewController(currency: currency, didSelectTransaction: didSelectTransaction)
        
        //TODO:BCH these actions should be currency-specific
        footerView.sendCallback = { Store.perform(action: RootModalActions.Present(modal: .send)) }
        footerView.receiveCallback = { Store.perform(action: RootModalActions.Present(modal: .receive)) }
        footerView.buyCallback = { Store.perform(action: RootModalActions.Present(modal: .buy)) }
    }

    //MARK: - Private
    private let currency: CurrencyDef
    
    private let headerView: AccountHeaderView
    private let footerView = AccountFooterView()
    private let transitionDelegate = ModalTransitionDelegate(type: .transactionDetail)
    private let transactionsLoadingView = LoadingProgressView()
    private var transactionsTableView: TransactionsTableViewController!
    private var transactionsLoadingViewTop: NSLayoutConstraint?
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private var isLoginRequired = false
    private let searchHeaderview: SearchHeaderView = {
        let view = SearchHeaderView()
        view.isHidden = true
        return view
    }()
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
    private var didEndLoading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // detect jailbreak so we can throw up an idiot warning, in viewDidLoad so it can't easily be swizzled out
        if !E.isSimulator {
            var s = stat()
            var isJailbroken = (stat("/bin/sh", &s) == 0) ? true : false
            for i in 0..<_dyld_image_count() {
                guard !isJailbroken else { break }
                // some anti-jailbreak detection tools re-sandbox apps, so do a secondary check for any MobileSubstrate dyld images
                if strstr(_dyld_get_image_name(i), "MobileSubstrate") != nil {
                    isJailbroken = true
                }
            }
            NotificationCenter.default.addObserver(forName: .UIApplicationWillEnterForeground, object: nil, queue: nil) { note in
                self.showJailbreakWarnings(isJailbroken: isJailbroken)
            }
            showJailbreakWarnings(isJailbroken: isJailbroken)
        }

        addTransactionsView()
        addSubviews()
        addConstraints()
        addSubscriptions()
        addAppLifecycleNotificationEvents()
        setInitialData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldShowStatusBar = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        headerView.setBalances()
    }

    private func addSubviews() {
        view.addSubview(headerContainer)
        headerContainer.addSubview(headerView)
        view.addSubview(footerView)
        headerContainer.addSubview(searchHeaderview)
    }

    private func addConstraints() {
        headerContainer.constrainTopCorners(sidePadding: 0, topPadding: 0)
        headerContainer.constrain([ headerContainer.constraint(.height, constant: E.isIPhoneX ? accountHeaderHeight + 14.0 : accountHeaderHeight) ])
        headerView.constrain(toSuperviewEdges: nil)

        footerView.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        footerView.constrain([
            footerView.constraint(.height, constant: E.isIPhoneX ? accountFooterHeight + 20.0 : accountFooterHeight) ])
        searchHeaderview.constrain(toSuperviewEdges: nil)
        searchHeaderview.constrain([
            searchHeaderview.constraint(.height, toView: headerContainer)
            ])
    }

    private func addSubscriptions() {
        Store.subscribe(self, selector: { $0[self.currency].syncProgress != $1[self.currency].syncProgress },
                        callback: { state in
                            self.transactionsTableView.syncingView.progress = CGFloat(state[self.currency].syncProgress)
                            self.transactionsTableView.syncingView.timestamp = state[self.currency].lastBlockTimestamp
        })

        Store.subscribe(self, selector: { $0[self.currency].syncState != $1[self.currency].syncState },
                        callback: { state in
                            guard let peerManager = self.walletManager?.peerManager else { return }
                            if state[self.currency].syncState == .success {
                                self.transactionsTableView.isSyncingViewVisible = false
                            } else if peerManager.shouldShowSyncingView {
                                self.transactionsTableView.isSyncingViewVisible = true
                            } else {
                                self.transactionsTableView.isSyncingViewVisible = false
                            }
        })

        //TODO:BCH this was never being set
//        Store.subscribe(self, selector: { $0.isLoadingTransactions != $1.isLoadingTransactions }, callback: {
//            if $0.isLoadingTransactions {
//                self.loadingDidStart()
//            } else {
//                self.hideLoadingView()
//            }
//        })
        Store.subscribe(self, selector: { $0.isLoginRequired != $1.isLoginRequired }, callback: { self.isLoginRequired = $0.isLoginRequired })
        Store.subscribe(self, name: .showStatusBar, callback: { _ in
            self.shouldShowStatusBar = true
        })
        Store.subscribe(self, name: .hideStatusBar, callback: { _ in
            self.shouldShowStatusBar = false
        })
    }

    private func setInitialData() {
        headerView.searchButton.tap = { [weak self] in
            guard let myself = self else { return }
            myself.navigationController?.setNavigationBarHidden(true, animated: false)
            UIView.transition(from: myself.headerView,
                              to: myself.searchHeaderview,
                              duration: C.animationDuration,
                              options: [.transitionFlipFromBottom, .showHideTransitionViews, .curveEaseOut],
                              completion: { _ in
                                myself.searchHeaderview.triggerUpdate()
                                myself.setNeedsStatusBarAppearanceUpdate()
                                let contentInset = myself.transactionsTableView.tableView.contentInset
                                myself.transactionsTableView.tableView.contentInset = UIEdgeInsetsMake(contentInset.top + 64.0, contentInset.left, contentInset.bottom, contentInset.right)
            })
        }

        searchHeaderview.didCancel = { [weak self] in
            guard let myself = self else { return }
            myself.navigationController?.setNavigationBarHidden(false, animated: false)
            UIView.transition(from: myself.searchHeaderview,
                              to: myself.headerView,
                              duration: C.animationDuration,
                              options: [.transitionFlipFromTop, .showHideTransitionViews, .curveEaseOut],
                              completion: { _ in
                                myself.setNeedsStatusBarAppearanceUpdate()
                                let contentInset = myself.transactionsTableView.tableView.contentInset
                                myself.transactionsTableView.tableView.contentInset = UIEdgeInsetsMake(contentInset.top - 64.0, contentInset.left, contentInset.bottom, contentInset.right)
            })
        }


        searchHeaderview.didChangeFilters = { [weak self] filters in
            self?.transactionsTableView.filters = filters
        }
    }

    private func loadingDidStart() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
            if !self.didEndLoading {
                self.showLoadingView()
            }
        })
    }

    private func showLoadingView() {
        view.insertSubview(transactionsLoadingView, belowSubview: headerContainer)
        transactionsLoadingViewTop = transactionsLoadingView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -transactionsLoadingViewHeightConstant)
        transactionsLoadingView.constrain([
            transactionsLoadingViewTop,
            transactionsLoadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            transactionsLoadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            transactionsLoadingView.heightAnchor.constraint(equalToConstant: transactionsLoadingViewHeightConstant) ])
        transactionsLoadingView.progress = 0.01
        view.layoutIfNeeded()
        UIView.animate(withDuration: C.animationDuration, animations: {
        self.transactionsTableView.tableView.verticallyOffsetContent(transactionsLoadingViewHeightConstant)
            self.transactionsLoadingViewTop?.constant = 0.0
            self.view.layoutIfNeeded()
        }) { completed in
            //This view needs to be brought to the front so that it's above the headerview shadow. It looks weird if it's below.
            self.view.insertSubview(self.transactionsLoadingView, aboveSubview: self.headerContainer)
        }
        loadingTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateLoadingProgress), userInfo: nil, repeats: true)
    }

    private func hideLoadingView() {
        didEndLoading = true
        guard self.transactionsLoadingViewTop?.constant == 0.0 else { return } //Should skip hide if it's not shown
        loadingTimer?.invalidate()
        loadingTimer = nil
        transactionsLoadingView.progress = 1.0
        view.insertSubview(transactionsLoadingView, belowSubview: headerContainer)
        if transactionsLoadingView.superview != nil {
            UIView.animate(withDuration: C.animationDuration, animations: {
                self.transactionsTableView.tableView.verticallyOffsetContent(-transactionsLoadingViewHeightConstant)
                self.transactionsLoadingViewTop?.constant = -transactionsLoadingViewHeightConstant
                self.view.layoutIfNeeded()
            }) { completed in
                self.transactionsLoadingView.removeFromSuperview()
            }
        }
    }

    @objc private func updateLoadingProgress() {
        transactionsLoadingView.progress = transactionsLoadingView.progress + (1.0 - transactionsLoadingView.progress)/8.0
    }

    private func addTransactionsView() {
        addChildViewController(transactionsTableView, layout: {
            transactionsTableView.view.constrain(toSuperviewEdges: nil)
        })
    }
    
    private func didSelectTransaction(transactions: [Transaction], selectedIndex: Int) -> Void {
        let transactionDetails = TxDetailViewController(transaction: transactions[selectedIndex])
        transactionDetails.modalPresentationStyle = .overCurrentContext
        transactionDetails.transitioningDelegate = transitionDelegate
        transactionDetails.modalPresentationCapturesStatusBarAppearance = true
        present(transactionDetails, animated: true, completion: nil)
    }

    private func addAppLifecycleNotificationEvents() {
        NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: nil) { note in
            UIView.animate(withDuration: 0.1, animations: {
                self.blurView.alpha = 0.0
            }, completion: { _ in
                self.blurView.removeFromSuperview()
            })
        }
        NotificationCenter.default.addObserver(forName: .UIApplicationWillResignActive, object: nil, queue: nil) { note in
            if !self.isLoginRequired && !Store.state.isPromptingBiometrics {
                self.blurView.alpha = 1.0
                self.view.addSubview(self.blurView)
                self.blurView.constrain(toSuperviewEdges: nil)
            }
        }
    }

    private func showJailbreakWarnings(isJailbroken: Bool) {
        guard isJailbroken else { return }
        let totalSent = walletManager?.wallet?.totalSent ?? 0
        let message = totalSent > 0 ? S.JailbreakWarnings.messageWithBalance : S.JailbreakWarnings.messageWithBalance
        let alert = UIAlertController(title: S.JailbreakWarnings.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.JailbreakWarnings.ignore, style: .default, handler: nil))
        if totalSent > 0 {
            alert.addAction(UIAlertAction(title: S.JailbreakWarnings.wipe, style: .default, handler: nil)) //TODO - implement wipe
        } else {
            alert.addAction(UIAlertAction(title: S.JailbreakWarnings.close, style: .default, handler: { _ in
                exit(0)
            }))
        }
        present(alert, animated: true, completion: nil)
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
