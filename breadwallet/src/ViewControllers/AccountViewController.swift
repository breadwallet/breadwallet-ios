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

let accountHeaderHeight: CGFloat = 136.0
private let notificationViewHeight: CGFloat = 48.0

class AccountViewController : UIViewController, Trackable, Subscriber {

    //MARK: - Public
    var sendCallback: (() -> Void)? {
        didSet { footerView.sendCallback = sendCallback }
    }
    var receiveCallback: (() -> Void)? {
        didSet { footerView.receiveCallback = receiveCallback }
    }
    var menuCallback: (() -> Void)? {
        didSet { footerView.menuCallback = menuCallback }
    }

    var walletManager: WalletManager? {
        didSet {
            guard let walletManager = walletManager else { return }
            if !walletManager.noWallet {
                loginView.walletManager = walletManager
                loginView.transitioningDelegate = loginTransitionDelegate
                loginView.modalPresentationStyle = .overFullScreen
                loginView.modalPresentationCapturesStatusBarAppearance = true
                loginView.shouldSelfDismiss = true
                present(loginView, animated: false, completion: {
                    self.tempLoginView.remove()
                })
            }
        }
    }

    init(store: Store, didSelectTransaction: @escaping ([Transaction], Int) -> Void) {
        self.store = store
        self.transactionsTableView = TransactionsTableViewController(store: store, didSelectTransaction: didSelectTransaction)
        self.headerView = AccountHeaderView(store: store)
        self.loginView = LoginViewController(store: store, isPresentedForLock: false)
        self.tempLoginView = LoginViewController(store: store, isPresentedForLock: false)
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let store: Store
    private let headerView: AccountHeaderView
    private let footerView = AccountFooterView()
    private let notificationView = LoadingProgressView()
    private let transactionsTableView: TransactionsTableViewController
    private let footerHeight: CGFloat = 56.0
    private var notificationViewTop: NSLayoutConstraint?
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private var isLoginRequired = false
    private let loginView: LoginViewController
    private let tempLoginView: LoginViewController
    private let loginTransitionDelegate = LoginTransitionDelegate()
    private let searchHeaderview: SearchHeaderView = {
        let view = SearchHeaderView()
        view.isHidden = true
        return view
    }()
    private let headerContainer = UIView()

    override func viewDidLoad() {
        // detect jailbreak so we can throw up an idiot warning, in viewDidLoad so it can't easily be swizzled out
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

        //Start Accont View
        addTransactionsView()
        view.addSubview(headerContainer)
        headerContainer.addSubview(headerView)
        view.addSubview(footerView)

        headerContainer.constrainTopCorners(sidePadding: 0, topPadding: 0)
        headerContainer.constrain([
            headerContainer.constraint(.height, constant: accountHeaderHeight) ])
        headerView.constrain(toSuperviewEdges: nil)

        footerView.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        footerView.constrain([
            footerView.constraint(.height, constant: footerHeight) ])

        store.subscribe(self, selector: { $0.walletState.syncProgress != $1.walletState.syncProgress },
                        callback: { state in
                            self.transactionsTableView.syncingView.progress = CGFloat(state.walletState.syncProgress)
                            self.transactionsTableView.syncingView.timestamp = state.walletState.lastBlockTimestamp
        })

        store.subscribe(self, selector: { $0.walletState.isSyncing != $1.walletState.isSyncing },
                        callback: { state in
                            if state.walletState.isSyncing {
                                self.transactionsTableView.isSyncingViewVisible = true
                            } else {
                                self.transactionsTableView.isSyncingViewVisible = false
                            }
        })

        store.subscribe(self, selector: {$0.walletState.balance != $1.walletState.balance },
                        callback: { state in
                            self.headerView.balance = state.walletState.balance
        })

        store.subscribe(self, selector: { $0.isLoginRequired != $1.isLoginRequired }, callback: { self.isLoginRequired = $0.isLoginRequired })

        addAppLifecycleNotificationEvents()
        addTemporaryStartupViews()


        headerContainer.addSubview(searchHeaderview)
        searchHeaderview.constrain(toSuperviewEdges: nil)

        headerView.search.tap = { [weak self] in
            guard let myself = self else { return }
            UIView.transition(from: myself.headerView,
                              to: myself.searchHeaderview,
                              duration: C.animationDuration,
                              options: [.transitionFlipFromBottom, .showHideTransitionViews, .curveEaseOut],
                              completion: { _ in
                                myself.setNeedsStatusBarAppearanceUpdate()
            })
        }

        searchHeaderview.didCancel = { [weak self] in
            guard let myself = self else { return }
            UIView.transition(from: myself.searchHeaderview,
                              to: myself.headerView,
                              duration: C.animationDuration,
                              options: [.transitionFlipFromTop, .showHideTransitionViews, .curveEaseOut],
                              completion: { _ in
                                myself.setNeedsStatusBarAppearanceUpdate()
            })
        }


        searchHeaderview.didChangeFilters = { [weak self] filters in
            self?.transactionsTableView.filters = filters
        }

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        saveEvent("accout:did_appear")
    }

    private func showLoadingView() {
        view.addSubview(notificationView)
        view.bringSubview(toFront: headerView)
        notificationViewTop = notificationView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -notificationViewHeight)
        notificationView.constrain([
            notificationViewTop,
            notificationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            notificationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            notificationView.heightAnchor.constraint(equalToConstant: notificationViewHeight) ])

        view.layoutIfNeeded()

        UIView.animate(withDuration: C.animationDuration, animations: { 
            self.transactionsTableView.tableView.verticallyOffsetContent(notificationViewHeight)
            self.notificationViewTop?.constant = 0.0
            self.view.layoutIfNeeded()
        }) { completed in
            //This view needs to be brought to the front so that it's above the headerview shadow. It looks weird if it's below.
            self.view.bringSubview(toFront: self.notificationView)
        }
    }

    private func addTemporaryStartupViews() {
        if WalletManager.hasWallet {
            addChildViewController(tempLoginView, layout: {
                tempLoginView.view.constrain(toSuperviewEdges: nil)
            })
        } else {
            let startView = StartViewController(store: store, didTapRecover: {})
            addChildViewController(startView, layout: {
                startView.view.constrain(toSuperviewEdges: nil)
                startView.view.isUserInteractionEnabled = false
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                startView.remove()
            })
        }
    }

    private func hideLoadingView() {
        if notificationView.superview != nil {
            UIView.animate(withDuration: C.animationDuration, animations: {
                self.transactionsTableView.tableView.verticallyOffsetContent(-notificationViewHeight)
                self.notificationViewTop?.constant = -notificationViewHeight
                self.view.layoutIfNeeded()
            }) { completed in
                self.notificationView.removeFromSuperview()
            }
        }
    }

    private func addTransactionsView() {
        addChildViewController(transactionsTableView, layout: {
            transactionsTableView.view.constrain(toSuperviewEdges: nil)
            transactionsTableView.tableView.contentInset = UIEdgeInsets(top: accountHeaderHeight + C.padding[2], left: 0, bottom: footerHeight + C.padding[2], right: 0)
            transactionsTableView.tableView.scrollIndicatorInsets = UIEdgeInsets(top: accountHeaderHeight, left: 0, bottom: footerHeight, right: 0)
        })
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
            if !self.isLoginRequired {
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
