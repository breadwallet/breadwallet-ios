//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore
import BRCrypto
import UserNotifications

private let timeSinceLastExitKey = "TimeSinceLastExit"
private let shouldRequireLoginTimeoutKey = "ShouldRequireLoginTimeoutKey"

class ApplicationController: Subscriber, Trackable {

    fileprivate var application: UIApplication?

    let window = UIWindow()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))

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

    private let coreSystem = CoreSystem()
    private var keyStore: KeyStore!
    private var kvStoreCoordinator: KVStoreCoordinator?

    private var launchURL: URL?
    private var urlController: URLController?
    private let notificationHandler = NotificationHandler()
    private var appRatingManager = AppRatingManager()

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
    }

    private func enterOnboarding() {
        assert(keyStore.noWallet)
        startFlowController?.showStartFlow()
    }

    /// Prompts to unlock the wallet for initial launch, then setup the system
    private func unlockExistingAccount() {
        assert(!keyStore.noWallet)
        guard let rootNavigationController = rootNavigationController else { return assertionFailure() }
        rootNavigationController.promptForLogin(keyMaster: keyStore) { [unowned self] account in
            self.setupSystem(with: account)
        }
    }

    /// Initialize the core system with an account
    private func setupSystem(with account: Account) {
        coreSystem.create(account: account)

        Backend.connect(authenticator: keyStore as WalletAuthenticator)
        Backend.sendLaunchEvent()

        //TODO:CRYPTO
        modalPresenter = ModalPresenter(keyStore: keyStore,
                                        system: coreSystem,
                                        window: window)

        //TODO:CRYPTO
//        urlController = URLController(walletAuthenticator: keyStore)
//        if let url = launchURL {
//            _ = urlController?.handleUrl(url)
//            launchURL = nil
//        }

        connectWallets()
    }

    /// didFinishLaunchingWithOptions
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
    }
    
    private func setup() {
        setupDefaults()
        setupAppearance()
        setupRootViewController()
        window.makeKeyAndVisible()
        initializeAssets()

        // Start collecting analytics events. Once we have a wallet, startDataFetchers() will
        // notify `Backend.apiClient.analytics` so that it can upload events to the server.
        Backend.apiClient.analytics?.startCollectingEvents()

        appRatingManager.start()

        //TODO:CRYPTO refactor create/recover
        Store.subscribe(self, name: .didCreateOrRecoverWallet(nil), callback: {
            guard case .didCreateOrRecoverWallet(let account?)? = $0 else { return assertionFailure() }
            assert(self.coreSystem.state == .uninitialized)
            self.setupSystem(with: account)
            Store.perform(action: LoginSuccess())
        })

        //TODO:CRYPTO refactor wipe
        Store.subscribe(self, name: .reinitWalletManager(nil), callback: {
            guard case .reinitWalletManager(_)? = $0 else { return assertionFailure() }
            Store.perform(action: Reset())
            self.kvStoreCoordinator = nil
            self.setupRootViewController()
            self.enterOnboarding()
        })
        
        Store.lazySubscribe(self,
                            selector: { $0.isLoginRequired != $1.isLoginRequired && $1.isLoginRequired == false },
                            callback: { _ in self.didUnlockWallet() }
        )

        if keyStore.noWallet {
            enterOnboarding()
        } else {
            unlockExistingAccount()
        }
    }
    
    func willEnterForeground() {
        guard !keyStore.noWallet else { return }
        appRatingManager.bumpLaunchCount()
        Backend.sendLaunchEvent()
        if shouldRequireLogin() {
            Store.perform(action: RequireLogin())
        }
        connectWallets()
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
        disconnectWallets()
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
        //TODO:CRYPTO spend limit
//        if let btcWalletManager = walletManagers[Currencies.btc.code] as? BTCWalletManager {
//            btcWalletManager.updateSpendLimit()
//        }
    }

    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    }

    //TODO:CRYPTO
    /*
    private func didInitWalletManager() {
        guard let rootViewController = window.rootViewController as? RootNavigationController else { return }
        walletCoordinator = WalletCoordinator(walletManagers: walletManagers)
        Backend.connect(authenticator: keyStore as WalletAuthenticator,
                        currencies: Store.state.currencies,
                        walletManagers: walletManagers.map { $0.1 })
        Backend.sendLaunchEvent()

        checkForNotificationSettingsChange(appActive: true)
        
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
            connectWallets()
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
        guard let ethWalletManager = ethWalletManager else { return }
        DispatchQueue.main.async {
            Store.perform(action: WalletChange(Currencies.eth).setSyncingState(.connecting))
            Store.perform(action: WalletChange(Currencies.eth).setMaxDigits(Currencies.eth.commonUnit.decimals))
            Store.perform(action: WalletID.Set(ethWalletManager.walletID))
        }
        ethWalletManager.updateTokenList {
            completion()
        }
    }
    */

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
            guard let wallet = self.coreSystem.wallet(for: currency) else { return }

            //TODO:CRYPTO need a new way of checking for BRD
            if currency.isBRDToken, UserDefaults.shouldShowBRDRewardsAnimation {
                let name = self.makeEventName([EventContext.rewards.name, Event.openWallet.name])
                self.saveEvent(name, attributes: ["currency": currency.code])
            }
            
            let accountViewController = AccountViewController(wallet: wallet)
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
                                            walletAuthenticator: keyStore)
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
        let navigationController = RootNavigationController()
        window.rootViewController = navigationController

        startFlowController = StartFlowPresenter(keyMaster: keyStore,
                                                 rootViewController: navigationController,
                                                 createHomeScreen: createHomeScreen,
                                                 createBuyScreen: createBuyScreen)
    }

    private func connectWallets() {
        //TODO:CRYPTO p2p sync management
        // connect only one of BTC or BCH depending on which was last used (to save bandwidth)
        coreSystem.connect()
        startDataFetchers()
    }

    private func disconnectWallets() {
        coreSystem.disconnect()
    }

    private func startDataFetchers() {
        Backend.apiClient.updateFeatureFlags()
        Backend.apiClient.fetchAnnouncements()
        initKVStoreCoordinator() //TODO:CRYPTO this depends on the token list
        Backend.updateFees()
        Backend.updateExchangeRates()
        Backend.apiClient.analytics?.onWalletReady()    // fires up analytics uploading
        if let pigeonExchange = Backend.pigeonExchange, pigeonExchange.isPaired, !Store.state.isPushNotificationsEnabled {
            pigeonExchange.startPolling()
        }
    }
    
    private func retryAfterIsReachable() {
        guard !keyStore.noWallet else { return }
        connectWallets()
        Backend.updateExchangeRates()
        Backend.updateFees()
        Backend.kvStore?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        Backend.apiClient.updateFeatureFlags()
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
        kvStore.syncAllKeys { [unowned self] error in
            print("KV finished syncing. err: \(String(describing: error))")
            self.kvStoreCoordinator?.setupStoredCurrencyList()
            self.kvStoreCoordinator?.retreiveStoredWalletInfo()
            self.kvStoreCoordinator?.listenForWalletChanges()
        }
    }

    /// background init of assets / animations
    private func initializeAssets() {
        DispatchQueue.global(qos: .background).async {
            _ = Rate.symbolMap //Initialize currency symbol map
        }

        updateAssetBundles()

        // Set up the animation frames early during the startup process so that they're
        // ready to roll by the time the home screen is displayed.
        RewardsIconView.prepareAnimationFrames()
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

    //TODO:CRYPTO
    /*
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
    */
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
