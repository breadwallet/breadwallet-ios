//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore
import UserNotifications

private let timeSinceLastExitKey = "TimeSinceLastExit"
private let shouldRequireLoginTimeoutKey = "ShouldRequireLoginTimeoutKey"

// swiftlint:disable type_body_length

class ApplicationController: Subscriber, Trackable {

    let window = UIWindow()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private var walletManagers = [String: WalletManager]()
    private var walletCoordinator: WalletCoordinator?
    private var keyStore: KeyStore!
    private var appRatingManager: AppRatingManager = AppRatingManager()
    
    var rootNavigationController: RootNavigationController? {
        guard let root = window.rootViewController as? RootNavigationController else { return nil }
        return root
    }
    
    var homeScreenViewController: HomeScreenViewController? {
        guard   let rootNavController = rootNavigationController,
                let homeScreen = rootNavController.viewControllers.first as? HomeScreenViewController
        else {
                return nil
        }
        return homeScreen
    }
        
    private var kvStoreCoordinator: KVStoreCoordinator?
    fileprivate var application: UIApplication?
    private var urlController: URLController?
    private let defaultsUpdater = UserDefaultsUpdater()
    private var fetchCompletionHandler: ((UIBackgroundFetchResult) -> Void)?
    private var launchURL: URL?
    private var hasPerformedWalletDependentInitialization = false
    private var didInitWallet = false
    private var rescanNeeded: [Currency]?
    private let notificationHandler = NotificationHandler()
    private var isReachable = true {
        didSet {
            if oldValue == false && isReachable {
                self.retryAfterIsReachable()
            }
        }
    }

    // MARK: -

    init() {
        do {
            self.keyStore = try KeyStore.create()
        } catch let error { // only possible exception here should be if the keychain is inaccessible
            print("error initializing key store: \(error)")
            fatalError("error initializing key store")
        }

        isReachable = Reachability.isReachable
        self.rescanNeeded = []
        // queue auomatic rescan attempt triggered by db load to execute after wallet coordinator is started
        Store.subscribe(self, name: .automaticRescan(Currencies.btc), callback: { [unowned self] in
            if case .automaticRescan(let currency)? = $0 {
                guard let rescanNeeded = self.rescanNeeded else { return }
                if !rescanNeeded.contains(where: { $0.matches(currency) }) {
                    self.rescanNeeded!.append(currency)
                }
            }
        })

        if self.keyStore.noWallet {
            // no seed present - onboarding
            self.didAttemptInitWallet()
        } else {
            // wallet initialization will access protected stored data
            guardProtected(queue: DispatchQueue.walletQueue) {
                if UserDefaults.hasBchConnected {
                    self.initWallets(completion: self.didAttemptInitWallet)
                } else {
                    self.initWalletsWithMigration(completion: self.didAttemptInitWallet)
                }
            }
        }
    }

    /// Migrates pre-fork BTC transactions to BCH wallet then init all wallets
    /// This only applies in the case where a BTC wallet with transaction history already exists on the device
    /// and the wallet was created prior to the BCH fork.
    /// This method will access protected stored data and should only be called inside a `guardProtected` block and on the walletQueue.
    private func initWalletsWithMigration(completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.walletQueue))
        let btc = Currencies.btc
        let bch = Currencies.bch
        let creationTime = keyStore.creationTime

        guard let mpk = keyStore.masterPubKey,
            let btcWalletManager = try? BTCWalletManager(currency: btc,
                                                         masterPubKey: mpk,
                                                         earliestKeyTime: creationTime,
                                                         dbPath: btc.dbPath) else { return }
        walletManagers[btc.code] = btcWalletManager
        btcWalletManager.initWallet { [unowned self] success in
            guard success else {
                completion()
                return
            }

            btcWalletManager.initPeerManager {
                btcWalletManager.db?.loadTransactions { txns in
                    btcWalletManager.db?.loadBlocks { blocks in
                        let preForkTransactions = txns.compactMap {$0}.filter { $0.pointee.blockHeight < C.bCashForkBlockHeight }
                        let preForkBlocks = blocks.compactMap {$0}.filter { $0.pointee.height < C.bCashForkBlockHeight }
                        var bchWalletManager: BTCWalletManager?
                        if !preForkBlocks.isEmpty || blocks.isEmpty {
                            bchWalletManager = try? BTCWalletManager(currency: bch,
                                                                     masterPubKey: mpk,
                                                                     earliestKeyTime: creationTime,
                                                                     dbPath: bch.dbPath)
                        } else {
                            bchWalletManager = try? BTCWalletManager(currency: bch,
                                                                     masterPubKey: mpk,
                                                                     earliestKeyTime: C.bCashForkTimeStamp,
                                                                     dbPath: bch.dbPath)
                        }
                        self.walletManagers[bch.code] = bchWalletManager
                        bchWalletManager?.initWallet(transactions: preForkTransactions)
                        bchWalletManager?.initPeerManager(blocks: preForkBlocks)
                        bchWalletManager?.db?.loadTransactions { storedTransactions in
                            if storedTransactions.isEmpty {
                                bchWalletManager?.wallet?.transactions.compactMap {$0}.forEach { txn in
                                    bchWalletManager?.db?.txAdded(txn)
                                }
                            }
                        }
                        // init other wallets
                        guardProtected(queue: DispatchQueue.walletQueue) {
                            self.initWallets(completion: completion)
                        }
                    }
                }
            }
        }
    }

    /// Inits all blockchain wallets
    /// This method will access protected stored data and must be called inside a `guardProtected` block and on the walletQueue.
    private func initWallets(completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.walletQueue))
        let dispatchGroup = DispatchGroup()
        Store.state.currencies.forEach { currency in
            if !(currency is ERC20Token) && walletManagers[currency.code] == nil {
                initWallet(currency: currency, dispatchGroup: dispatchGroup)
            }
        }
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }

    /// Inits the specified blockchain wallet
    private func initWallet(currency: Currency, dispatchGroup: DispatchGroup) {
        guard !(currency is ERC20Token) else { return assertionFailure() }
        dispatchGroup.enter()
        if let currency = currency as? Ethereum {
            guard let publicKey = keyStore.ethPubKey, let manager = EthWalletManager(publicKey: publicKey) else {
                dispatchGroup.leave()
                return
            }
            walletManagers[currency.code] = manager
            setupEthInitialState {
                dispatchGroup.leave()
            }
            return
        }
        guard let currency = currency as? Bitcoin,
            let mpk = keyStore.masterPubKey,
            let walletManager = try? BTCWalletManager(currency: currency,
                                                      masterPubKey: mpk,
                                                      earliestKeyTime: keyStore.creationTime,
                                                      dbPath: currency.dbPath) else { return assertionFailure() }
        walletManagers[currency.code] = walletManager
        walletManager.initWallet { success in
            guard success else {
                self.walletManagers[currency.code] = nil
                dispatchGroup.leave()
                return
            }
            walletManager.initPeerManager {
                dispatchGroup.leave()
            }
        }
    }
    
    /// Init all Ethereum token wallets
    private func initTokenWallets() {
        guard let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager else { return }
        let tokens = Store.state.currencies.compactMap { $0 as? ERC20Token }
        tokens.forEach { token in
            self.walletManagers[token.code] = ethWalletManager
            self.modalPresenter?.walletManagers[token.code] = ethWalletManager
            Store.perform(action: WalletChange(token).setSyncingState(.connecting))
            Store.perform(action: WalletChange(token).setMaxDigits(token.commonUnit.decimals))
            guard let state = token.state else { return }
            Store.perform(action: WalletChange(token).set(state.mutate(receiveAddress: ethWalletManager.address)))
        }
        ethWalletManager.tokens = tokens
    }

    private func didAttemptInitWallet() {
        DispatchQueue.main.async {
            self.didInitWallet = true
            if !self.hasPerformedWalletDependentInitialization {
                self.didInitWalletManager()
            }
        }
    }

    func launch(application: UIApplication, options: [UIApplication.LaunchOptionsKey: Any]?) {
        self.application = application
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalNever)
        
        UNUserNotificationCenter.current().delegate = notificationHandler
        EventMonitor.shared.register(.pushNotifications)
        
        setup()
        handleLaunchOptions(options)
        Reachability.addDidChangeCallback({ isReachable in
            self.isReachable = isReachable
        })
        updateAssetBundles()
        if !hasPerformedWalletDependentInitialization && didInitWallet {
            didInitWalletManager()
        }

        appRatingManager.start()
        
        // Set up the animation frames early during the startup process so that they're
        // ready to roll by the time the home screen is displayed.
        if UserDefaults.shouldShowBRDRewardsAnimation {
            RewardsIconView.prepareAnimationFrames()
        }
    }
    
    private func setup() {
        setupDefaults()
        setupAppearance()
        setupRootViewController()
        window.makeKeyAndVisible()
        offMainInitialization()

        // Start collecting analytics events. Once we have a wallet, startDataFetchers() will
        // notify `Backend.apiClient.analytics` so that it can upload events to the server.
        Backend.apiClient.analytics?.startCollectingEvents()
        
        //TODO:AUTH rename to uninit
        Store.subscribe(self, name: .reinitWalletManager(nil), callback: {
            if case .reinitWalletManager(let callback)? = $0 {
                if let callback = callback {
                    self.reinitWalletManager(callback: callback)
                }
            }
        })
        
        Store.lazySubscribe(self,
                            selector: { $0.isLoginRequired != $1.isLoginRequired && $1.isLoginRequired == false },
                            callback: { _ in self.didUnlockWallet() }
        )
    }
    
    func willEnterForeground() {
        guard !keyStore.noWallet else { return }
        appRatingManager.bumpLaunchCount()
        Backend.sendLaunchEvent()
        if shouldRequireLogin() {
            Store.perform(action: RequireLogin())
        }
        DispatchQueue.walletQueue.async {
            self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
        }
        updateTokenList {}
        updateAssetBundles()
        Backend.updateExchangeRates()
        Backend.updateFees()
        Backend.kvStore?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        Backend.apiClient.updateFeatureFlags()
        if let pigeonExchange = Backend.pigeonExchange, pigeonExchange.isPaired, !Store.state.isLoginRequired {
            pigeonExchange.fetchInbox()
        }
    }

    func didEnterBackground() {
        // disconnect synced peer managers
        Store.state.currencies.filter { $0.state?.syncState == .success }.forEach { currency in
            DispatchQueue.walletQueue.async {
                self.walletManagers[currency.code]?.peerManager?.disconnect()
            }
        }
        //Save the backgrounding time if the user is logged in
        if !Store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
        Backend.kvStore?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
    }
    
    func didUnlockWallet() {
        if let pigeonExchange = Backend.pigeonExchange, pigeonExchange.isPaired {
            pigeonExchange.fetchInbox()
        }
        //TODO:SL
        if let btcWalletManager = walletManagers[Currencies.btc.code] as? BTCWalletManager {
            btcWalletManager.updateSpendLimit()
        }
    }

    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        fetchCompletionHandler = completionHandler
    }

    private func didInitWalletManager() {
        guard let rootViewController = window.rootViewController as? RootNavigationController else { return }
        walletCoordinator = WalletCoordinator(walletManagers: walletManagers)
        Backend.connect(authenticator: keyStore as WalletAuthenticator,
                        currencies: Store.state.currencies,
                        walletManagers: walletManagers.map { $0.1 })
        Backend.sendLaunchEvent()

        checkForNotificationSettingsChange(appActive: true)
        
        if let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager {
            ethWalletManager.apiClient = Backend.apiClient
            if !UserDefaults.hasScannedForTokenBalances {
                ethWalletManager.discoverAndAddTokensWithBalance(in: Store.state.availableTokens) {
                    UserDefaults.hasScannedForTokenBalances = true
                }
            }
        }
        
        initTokenWallets()
        addTokenListChangeListener()
        Store.perform(action: PinLength.Set(keyStore.pinLength))
        rootViewController.showLoginIfNeeded()
        
        if let homeScreen = rootViewController.viewControllers.first as? HomeScreenViewController {
            // TODO: why is this needed...
            homeScreen.reload()
        }
        
        hasPerformedWalletDependentInitialization = true
        if modalPresenter != nil {
            Store.unsubscribe(modalPresenter!)
        }

        modalPresenter = ModalPresenter(keyStore: keyStore, walletManagers: walletManagers, window: window)
        startFlowController = StartFlowPresenter(keyMaster: keyStore,
                                                 rootViewController: rootViewController,
                                                 createHomeScreen: createHomeScreen,
                                                 createBuyScreen: createBuyScreen)

        urlController = URLController(walletAuthenticator: keyStore)
        if let url = launchURL {
            _ = urlController?.handleUrl(url)
            launchURL = nil
        }
        
        if keyStore.noWallet {
            addWalletCreationListener()
            Store.perform(action: ShowStartFlow())
        } else {
            DispatchQueue.walletQueue.async {
                self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
            }
            
            startDataFetchers()

            if let rescanNeeded = rescanNeeded {
                for currency in rescanNeeded {
                    // wait for peer manager to connect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        Store.trigger(name: .automaticRescan(currency))
                    }
                }
            }
            rescanNeeded = nil
        }
    }
    
    private func reinitWalletManager(callback: @escaping () -> Void) {
        Store.perform(action: Reset())
        self.setup()
        
        DispatchQueue.walletQueue.async {
            Backend.disconnectWallet()
            self.kvStoreCoordinator = nil
            self.walletManagers.values.forEach({ $0.resetForWipe() })
            self.walletManagers.removeAll()
            DispatchQueue.main.async {
                self.didInitWalletManager()
                callback()
            }
        }
    }

    private func setupEthInitialState(completion: @escaping () -> Void) {
        guard let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager else { return assertionFailure() }
        DispatchQueue.main.async {
            Store.perform(action: WalletChange(Currencies.eth).setSyncingState(.connecting))
            Store.perform(action: WalletChange(Currencies.eth).setMaxDigits(Currencies.eth.commonUnit.decimals))
            Store.perform(action: WalletID.Set(ethWalletManager.walletID))
        }
        updateTokenList {
            completion()
        }
    }

    private func shouldRequireLogin() -> Bool {
        let then = UserDefaults.standard.double(forKey: timeSinceLastExitKey)
        let timeout = UserDefaults.standard.double(forKey: shouldRequireLoginTimeoutKey)
        let now = Date().timeIntervalSince1970
        return now - then > timeout
    }

    private func setupDefaults() {
        if UserDefaults.standard.object(forKey: shouldRequireLoginTimeoutKey) == nil {
            UserDefaults.standard.set(60.0*3.0, forKey: shouldRequireLoginTimeoutKey) //Default 3 min timeout
        }
    }

    private func setupAppearance() {
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.font: UIFont.header]
        let backImage = #imageLiteral(resourceName: "BackArrowWhite").image(withInsets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 2.0, right: 0.0))
        UINavigationBar.appearance().backIndicatorImage = backImage
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = backImage
        // hide back button text
        UIBarButtonItem.appearance().setBackButtonBackgroundImage(#imageLiteral(resourceName: "TransparentPixel"), for: .normal, barMetrics: .default)
        UISwitch.appearance().onTintColor = Theme.accent
    }
    
    private func addHomeScreenHandlers(homeScreen: HomeScreenViewController, 
                                       navigationController: UINavigationController) {
        
        homeScreen.didSelectCurrency = { [unowned self] currency in
            guard let walletManager = self.walletManagers[currency.code] else { return }
            
            if Currencies.brd.code == currency.code, UserDefaults.shouldShowBRDRewardsAnimation {
                let name = self.makeEventName([EventContext.rewards.name, Event.openWallet.name])
                self.saveEvent(name, attributes: ["currency": currency.code])
            }
            
            let accountViewController = AccountViewController(currency: currency, walletManager: walletManager)
            navigationController.pushViewController(accountViewController, animated: true)
        }
        
        homeScreen.didTapBuy = {
            Store.perform(action: RootModalActions.Present(modal: .buy(currency: nil)))
        }
        
        homeScreen.didTapTrade = {
            Store.perform(action: RootModalActions.Present(modal: .trade))
        }
        
        homeScreen.didTapMenu = {
            self.modalPresenter?.presentMenu()
        }
        
        homeScreen.didTapAddWallet = {
            guard let kvStore = Backend.kvStore else { return }
            let vc = EditWalletsViewController(type: .add, kvStore: kvStore)
            navigationController.pushViewController(vc, animated: true)
        }
    }
        
    // Creates an instance of the buy screen. This may be invoked from the StartFlowPresenter if the user
    // goes through onboarding and decides to buy coin right away.
    private func createBuyScreen() -> BRWebViewController {
        let buyScreen = BRWebViewController(bundleName: C.webBundle,
                                            mountPoint: "/buy",
                                            walletAuthenticator: keyStore,
                                            walletManagers: walletManagers)
        buyScreen.startServer()
        buyScreen.preload()

        return buyScreen
    }
    
    // Creates an instance of the home screen. This may be invoked from StartFlowPresenter.presentOnboardingFlow().
    private func createHomeScreen(navigationController: UINavigationController) -> HomeScreenViewController {
        let homeScreen = HomeScreenViewController(walletAuthenticator: keyStore as WalletAuthenticator)
                
        addHomeScreenHandlers(homeScreen: homeScreen, navigationController: navigationController)
        
        return homeScreen
    }
    
    private func setupRootViewController() {
        let navigationController = RootNavigationController(keyMaster: keyStore)
                
        // If we're going to show the onboarding screen, the home screen will be created later
        // in StartFlowPresenter.presentOnboardingFlow(). Pushing the home screen here causes
        // the home screen to appear briefly before the onboarding screen is pushed.
        if !Store.state.shouldShowOnboarding {
            let homeScreen = createHomeScreen(navigationController: navigationController)
            
            navigationController.pushViewController(homeScreen, animated: false)
            
            // State restoration
            if let currency = Store.state.currencies.first(where: { $0.code == UserDefaults.selectedCurrencyCode }),
                let walletManager = self.walletManagers[currency.code],
                keyStore.noWallet == false {
                let accountViewController = AccountViewController(currency: currency, walletManager: walletManager)
                navigationController.pushViewController(accountViewController, animated: true)
            }
        }
                
        window.rootViewController = navigationController
    }

    private func startDataFetchers() {
        Backend.apiClient.updateFeatureFlags()
        Backend.apiClient.fetchAnnouncements()
        initKVStoreCoordinator()
        Backend.updateFees()
        Backend.updateExchangeRates()
        defaultsUpdater.refresh()
        Backend.apiClient.analytics?.onWalletReady()    // fires up analytics uploading
        if let pigeonExchange = Backend.pigeonExchange, pigeonExchange.isPaired, !Store.state.isPushNotificationsEnabled {
            pigeonExchange.startPolling()
        }
    }
    
    private func updateTokenList(completion: @escaping () -> Void) {
        guard let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager else { return assertionFailure() }
        let processTokens: ([ERC20Token]) -> Void = { tokens in
            var tokens = tokens.sorted(by: { $0.code.lowercased() < $1.code.lowercased() })
            if E.isDebug {
                tokens.append(Currencies.tst)
            }
            ethWalletManager.setAvailableTokens(tokens)
            DispatchQueue.main.async {
                Store.perform(action: ManageWallets.SetAvailableTokens(tokens))
            }
            print("[TokenList] tokens updated: \(tokens.count) tokens")
            completion()
        }
        
        let fm = FileManager.default
        guard let documentsDir = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return assertionFailure() }
        let cachedFilePath = documentsDir.appendingPathComponent("tokens.json").path
        
        if let embeddedFilePath = Bundle.main.path(forResource: "tokens", ofType: "json"), !fm.fileExists(atPath: cachedFilePath) {
            do {
                try fm.copyItem(atPath: embeddedFilePath, toPath: cachedFilePath)
                print("[TokenList] copied bundle tokens list to cache")
            } catch let e {
                print("[TokenList] unable to copy bundled \(embeddedFilePath) -> \(cachedFilePath): \(e)")
            }
        }
        // fetch from network and update cached copy on success or return the cached copy if fetch fails
        Backend.apiClient.getTokenList { result in
            switch result {
            case .success(let tokens):
                DispatchQueue.global(qos: .utility).async {
                    // update cache
                    do {
                        let data = try JSONEncoder().encode(tokens)
                        try data.write(to: URL(fileURLWithPath: cachedFilePath))
                    } catch let e {
                        print("[TokenList] failed to write to cache: \(e.localizedDescription)")
                    }
                }
                processTokens(tokens)
                
            case .error(let error):
                print("[TokenList] error fetching tokens: \(error)")
                var tokens = [ERC20Token]()
                do {
                    print("[TokenList] using cached token list")
                    let cachedData = try Data(contentsOf: URL(fileURLWithPath: cachedFilePath))
                    tokens = try JSONDecoder().decode([ERC20Token].self, from: cachedData)
                } catch let e {
                    print("[TokenList] error reading from cache: \(e)")
                    fatalError("unable to read token list!")
                }
                processTokens(tokens)
            }
        }
    }
    
    private func retryAfterIsReachable() {
        guard !keyStore.noWallet else { return }
        walletManagers.values.filter { $0 is BTCWalletManager }.map { $0.currency }.forEach {
            // reset sync state before re-connecting
            Store.perform(action: WalletChange($0).setSyncingState(.success))
        }
        DispatchQueue.walletQueue.async {
            self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
        }
        updateTokenList {}
        Backend.updateExchangeRates()
        Backend.updateFees()
        Backend.kvStore?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        Backend.apiClient.updateFeatureFlags()
    }

    /// Handles new wallet creation or recovery
    private func addWalletCreationListener() {
        Store.subscribe(self, name: .didCreateOrRecoverWallet, callback: { _ in
            self.walletManagers.removeAll() // remove the empty wallet managers
            guardProtected(queue: DispatchQueue.walletQueue) {
                self.initWallets(completion: self.didInitWalletManager)
            }
            Store.perform(action: LoginSuccess())
        })
    }
    
    private func updateAssetBundles() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let `self` = self else { return }
            Backend.apiClient.updateBundles { errors in
                for (n, e) in errors {
                    print("Bundle \(n) ran update. err: \(String(describing: e))")
                }
                DispatchQueue.main.async {
                    self.modalPresenter?.preloadSupportCenter()
                }
            }
        }
    }

    private func initKVStoreCoordinator() {
        guard let kvStore = Backend.kvStore else { return }
        guard kvStoreCoordinator == nil else { return }
        self.kvStoreCoordinator = KVStoreCoordinator(kvStore: kvStore)
        self.walletManagers.values.forEach({ $0.kvStore = kvStore })
        kvStore.syncAllKeys { [unowned self] error in
            print("KV finished syncing. err: \(String(describing: error))")
            self.kvStoreCoordinator?.setupStoredCurrencyList()
            self.kvStoreCoordinator?.retreiveStoredWalletInfo()
            self.kvStoreCoordinator?.listenForWalletChanges()
        }
    }

    private func offMainInitialization() {
        DispatchQueue.global(qos: .background).async {
            _ = Rate.symbolMap //Initialize currency symbol map
        }
    }

    private func handleLaunchOptions(_ options: [UIApplication.LaunchOptionsKey: Any]?) {
        if let url = options?[.url] as? URL {
            do {
                let file = try Data(contentsOf: url)
                if !file.isEmpty {
                    Store.trigger(name: .openFile(file))
                }
            } catch let error {
                print("Could not open file at: \(url), error: \(error)")
            }
        }
    }
    
    func willResignActive() {
        self.applyBlurEffect()        
        checkForNotificationSettingsChange(appActive: false)
    }
    
    func didBecomeActive() {
        removeBlurEffect()
        checkForNotificationSettingsChange(appActive: true)
    }
    
    private func checkForNotificationSettingsChange(appActive: Bool) {
        guard Backend.isConnected else { return }
        
        if appActive {
            // check if notification settings changed
            NotificationAuthorizer().areNotificationsAuthorized { authorized in
                DispatchQueue.main.async {
                    if authorized {
                        if !Store.state.isPushNotificationsEnabled {
                            self.saveEvent("push.enabledSettings")
                        }
                        UIApplication.shared.registerForRemoteNotifications()
                    } else {
                        if Store.state.isPushNotificationsEnabled, let pushToken = UserDefaults.pushToken {
                            self.saveEvent("push.disabledSettings")
                            Store.perform(action: PushNotifications.SetIsEnabled(false))
                            Backend.apiClient.deletePushNotificationToken(pushToken)
                        }
                    }
                }
            }
        } else {
            if !Store.state.isPushNotificationsEnabled, let pushToken = UserDefaults.pushToken {
                Backend.apiClient.deletePushNotificationToken(pushToken)
            }
        }
    }
    
    private func applyBlurEffect() {
        guard !Store.state.isLoginRequired && !Store.state.isPromptingBiometrics else { return }
        blurView.alpha = 1.0
        blurView.frame = window.frame
        window.addSubview(blurView)
    }
    
    private func removeBlurEffect() {
        let duration = Store.state.isLoginRequired ? 0.4 : 0.1 // keep content hidden if lock screen about to appear on top
        UIView.animate(withDuration: duration, animations: {
            self.blurView.alpha = 0.0
        }, completion: { _ in
            self.blurView.removeFromSuperview()
        })
    }

    private func addTokenListChangeListener() {
        Store.lazySubscribe(self, selector: {
            let oldTokens = Set($0.currencies.compactMap { ($0 as? ERC20Token)?.address })
            let newTokens = Set($1.currencies.compactMap { ($0 as? ERC20Token)?.address })
            return oldTokens != newTokens
        }, callback: { _ in
            self.initTokenWallets()
            Backend.updateExchangeRates()
        })
    }
}

extension ApplicationController {
    func open(url: URL) -> Bool {
        if let urlController = urlController {
            return urlController.handleUrl(url)
        } else {
            launchURL = url
            return false
        }
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            return open(url: userActivity.webpageURL!)
        }
        return false
    }
}

// MARK: - Push notifications
extension ApplicationController {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard UserDefaults.pushToken != deviceToken else { return }
        UserDefaults.pushToken = deviceToken
        Backend.apiClient.savePushNotificationToken(deviceToken)
        Store.perform(action: PushNotifications.SetIsEnabled(true))
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[PUSH] failed to register for remote notifications: \(error.localizedDescription)")
        Store.perform(action: PushNotifications.SetIsEnabled(false))
    }
}
