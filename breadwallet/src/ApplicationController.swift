//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import BRCrypto
import UserNotifications

private let timeSinceLastExitKey = "TimeSinceLastExit"
private let shouldRequireLoginTimeoutKey = "ShouldRequireLoginTimeoutKey"

class ApplicationController: Subscriber, Trackable {

    fileprivate var application: UIApplication?

    static let initialLaunchCount = 0
    
    let window = UIWindow()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?
    private var alertPresenter: AlertPresenter?
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

    private var launchURL: URL?
    private var urlController: URLController?
    private let notificationHandler = NotificationHandler()
    private var appRatingManager = AppRatingManager()
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private var isReachable = true {
        didSet {
            if oldValue == false && isReachable {
                self.retryAfterIsReachable()
            }
        }
    }

    // MARK: - Init/Launch

    init() {
        do {
            self.keyStore = try KeyStore.create()
        } catch let error { // only possible exception here should be if the keychain is inaccessible
            print("error initializing key store: \(error)")
            fatalError("error initializing key store")
        }

        isReachable = Reachability.isReachable
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
    
    private func bumpLaunchCount() {
        guard !keyStore.noWallet else { return }
        UserDefaults.appLaunchCount = (UserDefaults.appLaunchCount + 1)
    }
    
    private func setup() {
        setupDefaults()
        setupAppearance()
        setupRootViewController()
        window.makeKeyAndVisible()
        initializeAssets()
        
        alertPresenter = AlertPresenter(window: self.window)

        // Start collecting analytics events. Once we have a wallet, startBackendServices() will
        // notify `Backend.apiClient.analytics` so that it can upload events to the server.
        Backend.apiClient.analytics?.startCollectingEvents()

        appRatingManager.start()

        Store.subscribe(self, name: .didWipeWallet) { [unowned self] _ in
            self.modalPresenter = nil
            self.rootNavigationController?.viewControllers = []
            
            self.setupRootViewController()
            self.enterOnboarding()
        }
        
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
        
    private func enterOnboarding() {
        guardProtected(queue: DispatchQueue.main) {
            guard let startFlowController = self.startFlowController, self.keyStore.noWallet else { return assertionFailure() }
            startFlowController.startOnboarding { [unowned self] account in
                self.setupSystem(with: account)
                Store.perform(action: LoginSuccess())
            }
        }
    }
    
    /// Loads the account for initial launch and initializes the core system
    /// Prompts for login if account needs to be recreated from seed
    private func unlockExistingAccount() {
        guardProtected(queue: DispatchQueue.main) {
            guard let startFlowController = self.startFlowController, !self.keyStore.noWallet else { return assertionFailure() }
            Store.perform(action: PinLength.Set(self.keyStore.pinLength))
            startFlowController.startLogin { [unowned self] account in
                self.setupSystem(with: account)
            }
        }
    }
    
    /// Initialize the core system with an account
    private func setupSystem(with account: Account) {
        self.startBackendServices()
        self.setWalletInfo(account: account)
        authenticateWithBackend { jwt in
            self.coreSystem.create(account: account, authToken: jwt)

            self.modalPresenter = ModalPresenter(keyStore: self.keyStore,
                                                 system: self.coreSystem,
                                                 window: self.window,
                                                 alertPresenter: self.alertPresenter)
            
            // deep link handling
            self.urlController = URLController(walletAuthenticator: self.keyStore)
            if let url = self.launchURL {
                _ = self.urlController?.handleUrl(url)
                self.launchURL = nil
            }

            self.connect()
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
    
    private func setupDefaults() {
        if UserDefaults.standard.object(forKey: shouldRequireLoginTimeoutKey) == nil {
            UserDefaults.standard.set(60.0*3.0, forKey: shouldRequireLoginTimeoutKey) //Default 3 min timeout
        }
    }
    
    // MARK: - Lifecycle
    
    func willEnterForeground() {
        guard !keyStore.noWallet else { return }
        bumpLaunchCount()
        Backend.sendLaunchEvent()
        if shouldRequireLogin() {
            Store.perform(action: RequireLogin())
        }
        connect()
        updateAssetBundles()
        coreSystem.updateFees()
    }

    func didEnterBackground() {
        disconnect()
        //Save the backgrounding time if the user is logged in
        if !Store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }

        Backend.kvStore?.syncAllKeys { error in
            print("[KV] finished syncing. result: \(error == nil ? "ok" : error!.localizedDescription)")
            Store.trigger(name: .didSyncKVStore)
        }
    }
    
    func didUnlockWallet() {
        if let pigeonExchange = Backend.pigeonExchange, pigeonExchange.isPaired {
            pigeonExchange.fetchInbox()
        }
    }
    
    private func connect() {
        fetchBackendUpdates()
        coreSystem.connect()
    }
    
    private func disconnect() {
        coreSystem.disconnect()
    }

    private func shouldRequireLogin() -> Bool {
        let then = UserDefaults.standard.double(forKey: timeSinceLastExitKey)
        let timeout = UserDefaults.standard.double(forKey: shouldRequireLoginTimeoutKey)
        let now = Date().timeIntervalSince1970
        return now - then > timeout
    }
    
    private func retryAfterIsReachable() {
        guard !keyStore.noWallet else { return }
        connect()
    }
    
    func willResignActive() {
        self.applyBlurEffect()        
        checkForNotificationSettingsChange(appActive: false)
    }
    
    func didBecomeActive() {
        removeBlurEffect()
        checkForNotificationSettingsChange(appActive: true)
    }

    // MARK: Background Task Support

    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return assertionFailure() }
        UIApplication.shared.beginBackgroundTask {
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
        self.backgroundTaskID = .invalid
    }
    
    // MARK: Services/Assets
    
    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    }
    
    /// Initialize backend services. Should only be called once per session.
    private func startBackendServices() {
        Backend.connect(authenticator: keyStore as WalletAuthenticator)
        Backend.sendLaunchEvent()
        Backend.apiClient.analytics?.onWalletReady()
    }

    /// Initialize WalletInfo in KV-store. Needed prior to creating the System.
    private func setWalletInfo(account: Account) {
        guard let kvStore = Backend.kvStore, WalletInfo(kvStore: kvStore) == nil else { return }
        print("[KV] created new WalletInfo")
        let walletInfo = WalletInfo(name: S.AccountHeader.defaultWalletName)
        walletInfo.creationDate = account.timestamp
        _ = try? kvStore.set(walletInfo)
    }

    private func authenticateWithBackend(completion: @escaping (String?) -> Void) {
        //TODO:CRYPTO optimize for new/recovered wallets by pre-fetching auth token during pin entry
        let bdbAuthClient = AuthenticationClient(baseURL: URL(string: "https://\(C.bdbHost)")!, urlSession: URLSession.shared)
        keyStore.authenticateWithBlockchainDB(client: bdbAuthClient) { result in
            switch result {
            case .success(let jwt):
                assert(!jwt.isExpired)
                completion(jwt.token)
            case .failure(let error):
                print("[BDB] authentication failure: \(error)")
                assertionFailure()
                completion(nil)
            }
        }
    }
    
    /// Fetch updates from backend services.
    private func fetchBackendUpdates() {
        DispatchQueue.global(qos: .utility).async {
            Backend.kvStore?.syncAllKeys { error in
                print("[KV] finished syncing. result: \(error == nil ? "ok" : error!.localizedDescription)")
                Store.trigger(name: .didSyncKVStore)
                if let pigeonExchange = Backend.pigeonExchange, pigeonExchange.isPaired {
                    if !Store.state.isLoginRequired {
                        pigeonExchange.fetchInbox()
                    }
                    if !Store.state.isPushNotificationsEnabled {
                        pigeonExchange.startPolling()
                    }
                }
            }
        }

        Backend.apiClient.updateExperiments()
        Backend.updateExchangeRates()
        Backend.apiClient.fetchAnnouncements()
    }
    
    private func updateAssetBundles() {
        DispatchQueue.global(qos: .utility).async { [unowned self] in
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
    
    // MARK: - UI
    
    private func setupRootViewController() {
        let navigationController = RootNavigationController()
        window.rootViewController = navigationController
        
        startFlowController = StartFlowPresenter(keyMaster: keyStore,
                                                 rootViewController: navigationController,
                                                 createHomeScreen: createHomeScreen,
                                                 createBuyScreen: createBuyScreen)
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
        
        homeScreen.didTapMenu = { [unowned self] in
            self.modalPresenter?.presentMenu()
        }
        
        homeScreen.didTapManageWallets = { [unowned self] in
            guard let assetCollection = self.coreSystem.assetCollection else { return }
            let vc = ManageWalletsViewController(assetCollection: assetCollection, coreSystem: self.coreSystem)
            let nc = UINavigationController(rootViewController: vc)
            nc.setDarkStyle()
            navigationController.present(nc, animated: true, completion: nil)
        }
    }
    
    /// Creates an instance of the buy screen. This may be invoked from the StartFlowPresenter if the user
    /// goes through onboarding and decides to buy coin right away.
    private func createBuyScreen() -> BRWebViewController {
        let buyScreen = BRWebViewController(bundleName: C.webBundle,
                                            mountPoint: "/buy",
                                            walletAuthenticator: keyStore)
        buyScreen.startServer()
        buyScreen.preload()
        
        return buyScreen
    }
    
    /// Creates an instance of the home screen. This may be invoked from StartFlowPresenter.presentOnboardingFlow().
    private func createHomeScreen(navigationController: UINavigationController) -> HomeScreenViewController {
        let homeScreen = HomeScreenViewController(walletAuthenticator: keyStore as WalletAuthenticator)
        
        addHomeScreenHandlers(homeScreen: homeScreen, navigationController: navigationController)
        
        return homeScreen
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
}
