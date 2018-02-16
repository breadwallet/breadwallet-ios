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
let accountFooterHeight: CGFloat = 67.0

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
        self.footerView = AccountFooterView(currency: currency)
        super.init(nibName: nil, bundle: nil)
        self.transactionsTableView = TransactionsTableViewController(currency: currency, didSelectTransaction: didSelectTransaction)
        
        footerView.sendCallback = { Store.perform(action: RootModalActions.Present(modal: .send(currency: currency))) }
        footerView.receiveCallback = { Store.perform(action: RootModalActions.Present(modal: .receive(currency: currency))) }
        footerView.buyCallback = { Store.perform(action: RootModalActions.Present(modal: .buy)) }
    }

    //MARK: - Private
    private let currency: CurrencyDef
    
    private let headerView: AccountHeaderView
    private let footerView: AccountFooterView
    private let transitionDelegate = ModalTransitionDelegate(type: .transactionDetail)
    private var transactionsTableView: TransactionsTableViewController!
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
        headerContainer.addSubview(searchHeaderview)
        view.addSubview(footerView)
    }

    private func addConstraints() {
        headerContainer.constrainTopCorners(height: accountHeaderHeight)
        headerView.constrain(toSuperviewEdges: nil)

        if #available(iOS 11.0, *) {
            footerView.constrain([
                footerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                footerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                footerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                footerView.heightAnchor.constraint(equalToConstant: accountFooterHeight)
                ])
        } else {
            footerView.constrain([
                footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                footerView.heightAnchor.constraint(equalToConstant: accountFooterHeight)
                ])
            
        }
        searchHeaderview.constrain(toSuperviewEdges: nil)
    }

    private func addSubscriptions() {
        Store.subscribe(self, selector: { $0.isLoginRequired != $1.isLoginRequired }, callback: { self.isLoginRequired = $0.isLoginRequired })
        Store.subscribe(self, name: .showStatusBar, callback: { _ in
            self.shouldShowStatusBar = true
        })
        Store.subscribe(self, name: .hideStatusBar, callback: { _ in
            self.shouldShowStatusBar = false
        })
    }

    private func setInitialData() {
        let navBarHeight: CGFloat = 44.0
        
        headerView.searchButton.tap = { [unowned self] in
            self.navigationController?.setNavigationBarHidden(true, animated: false)
            var contentInset = self.transactionsTableView.tableView.contentInset
            var contentOffset = self.transactionsTableView.tableView.contentOffset
            contentInset.top += navBarHeight
            contentOffset.y -= navBarHeight
            self.transactionsTableView.tableView.contentInset = contentInset
            self.transactionsTableView.tableView.contentOffset = contentOffset
            UIView.transition(from: self.headerView,
                              to: self.searchHeaderview,
                              duration: C.animationDuration,
                              options: [.transitionFlipFromBottom, .showHideTransitionViews, .curveEaseOut],
                              completion: { _ in
                                self.searchHeaderview.triggerUpdate()
                                self.setNeedsStatusBarAppearanceUpdate()
            })
        }
        
        searchHeaderview.didCancel = { [unowned self] in
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            var contentInset = self.transactionsTableView.tableView.contentInset
            contentInset.top -= navBarHeight
            self.transactionsTableView.tableView.contentInset = contentInset
            UIView.transition(from: self.searchHeaderview,
                              to: self.headerView,
                              duration: C.animationDuration,
                              options: [.transitionFlipFromTop, .showHideTransitionViews, .curveEaseOut],
                              completion: { _ in
                                self.setNeedsStatusBarAppearanceUpdate()
            })
        }
        
        
        searchHeaderview.didChangeFilters = { [weak self] filters in
            self?.transactionsTableView.filters = filters
        }
    }

    private func addTransactionsView() {
        view.backgroundColor = .whiteTint
        addChildViewController(transactionsTableView, layout: {
            if #available(iOS 11.0, *) {
                transactionsTableView.view.constrain([
                    transactionsTableView.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                transactionsTableView.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                transactionsTableView.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                transactionsTableView.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                ])
            } else {
                transactionsTableView.view.constrain(toSuperviewEdges: nil)
            }
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
