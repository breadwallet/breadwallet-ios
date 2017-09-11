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
private let transactionsLoadingViewHeightConstant: CGFloat = 48.0

class AccountViewController : UIViewController, Subscriber {

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
                    self.attemptShowWelcomeView()
                })
            }
            transactionsTableView.walletManager = walletManager
            headerView.isWatchOnly = walletManager.isWatchOnly
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
    private let transactionsLoadingView = LoadingProgressView()
    private let transactionsTableView: TransactionsTableViewController
    private let footerHeight: CGFloat = 56.0
    private var transactionsLoadingViewTop: NSLayoutConstraint?
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private var isLoginRequired = false
    private let loginView: LoginViewController
    private let tempLoginView: LoginViewController
    private let loginTransitionDelegate = LoginTransitionDelegate()
    private let welcomeTransitingDelegate = PinTransitioningDelegate()

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
        addTemporaryStartupViews()
        setInitialData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldShowStatusBar = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    private func addSubviews() {
        view.addSubview(headerContainer)
        headerContainer.addSubview(headerView)
        view.addSubview(footerView)
        headerContainer.addSubview(searchHeaderview)
    }

    private func addConstraints() {
        headerContainer.constrainTopCorners(sidePadding: 0, topPadding: 0)
        headerContainer.constrain([
            headerContainer.constraint(.height, constant: accountHeaderHeight) ])
        headerView.constrain(toSuperviewEdges: nil)

        footerView.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        footerView.constrain([
            footerView.constraint(.height, constant: footerHeight) ])
        searchHeaderview.constrain(toSuperviewEdges: nil)
    }

    private func addSubscriptions() {
        store.subscribe(self, selector: { $0.walletState.syncProgress != $1.walletState.syncProgress },
                        callback: { state in
                            self.transactionsTableView.syncingView.progress = CGFloat(state.walletState.syncProgress)
                            self.transactionsTableView.syncingView.timestamp = state.walletState.lastBlockTimestamp
        })

        store.lazySubscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState },
                            callback: { state in
                                guard let peerManager = self.walletManager?.peerManager else { return }
                                if state.walletState.syncState == .success {
                                    self.transactionsTableView.isSyncingViewVisible = false
                                } else if peerManager.shouldShowSyncingView {
                                    self.transactionsTableView.isSyncingViewVisible = true
                                } else {
                                    self.transactionsTableView.isSyncingViewVisible = false
                                }
        })

        store.subscribe(self, selector: { $0.isLoadingTransactions != $1.isLoadingTransactions }, callback: {
            if $0.isLoadingTransactions {
                self.loadingDidStart()
            } else {
                self.hideLoadingView()
            }
        })
        store.subscribe(self, selector: { $0.isLoginRequired != $1.isLoginRequired }, callback: { self.isLoginRequired = $0.isLoginRequired })
        store.subscribe(self, name: .showStatusBar, callback: { _ in
            self.shouldShowStatusBar = true
        })
        store.subscribe(self, name: .hideStatusBar, callback: { _ in
            self.shouldShowStatusBar = false
        })
    }

    private func setInitialData() {
        headerView.search.tap = { [weak self] in
            guard let myself = self else { return }
            UIView.transition(from: myself.headerView,
                              to: myself.searchHeaderview,
                              duration: C.animationDuration,
                              options: [.transitionFlipFromBottom, .showHideTransitionViews, .curveEaseOut],
                              completion: { _ in
                                myself.searchHeaderview.triggerUpdate()
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

    private func addTemporaryStartupViews() {
        guardProtected {
            if !WalletManager.staticNoWallet {
                self.addChildViewController(self.tempLoginView, layout: {
                    self.tempLoginView.view.constrain(toSuperviewEdges: nil)
                })
            } else {
                let startView = StartViewController(store: self.store, didTapCreate: {}, didTapRecover: {})
                self.addChildViewController(startView, layout: {
                    startView.view.constrain(toSuperviewEdges: nil)
                    startView.view.isUserInteractionEnabled = false
                })
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    startView.remove()
                })
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
            if !self.isLoginRequired && !self.store.state.isPromptingTouchId {
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

    private func attemptShowWelcomeView() {
        if !UserDefaults.hasShownWelcome {
            let welcome = WelcomeViewController()
            welcome.transitioningDelegate = welcomeTransitingDelegate
            welcome.modalPresentationStyle = .overFullScreen
            welcome.modalPresentationCapturesStatusBarAppearance = true
            welcomeTransitingDelegate.shouldShowMaskView = false
            loginView.present(welcome, animated: true, completion: nil)
            UserDefaults.hasShownWelcome = true
        }
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
