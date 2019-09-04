//
//  HomeScreenViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-27.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class HomeScreenViewController: UIViewController, Subscriber, Trackable {

    private let walletAuthenticator: WalletAuthenticator
    private let assetList = AssetListTableView()
    private let subHeaderView = UIView()
    private let logo = UIImageView(image: UIImage(named: "LogoGradientSmall"))
    private let total = UILabel(font: Theme.h1Title, color: Theme.primaryText)
    private let totalAssetsLabel = UILabel(font: Theme.caption, color: Theme.tertiaryText)
    private let debugLabel = UILabel(font: .customBody(size: 12.0), color: .transparentWhiteText) // debug info
    private let prompt = UIView()
    private var promptHiddenConstraint: NSLayoutConstraint!
    private let toolbar = UIToolbar()
    private var toolbarButtons = [UIButton]()
    private let notificationHandler = NotificationHandler()
    
    private var shouldShowBuyAndSell: Bool {
        return (Store.state.experimentWithName(.buyAndSell)?.active ?? false) && (Store.state.defaultCurrencyCode == C.usdCurrencyCode)
    }
    
    private var buyButtonTitle: String {
        return shouldShowBuyAndSell ? S.HomeScreen.buyAndSell : S.HomeScreen.buy
    }
    
    private let buyButtonIndex = 0
    private let tradeButtonIndex = 1
    private let menuButtonIndex = 2
    
    private var buyButton: UIButton? {
        guard toolbarButtons.count == 3 else { return nil }
        return toolbarButtons[buyButtonIndex]
    }
    
    private var tradeButton: UIButton? {
        guard toolbarButtons.count == 3 else { return nil }
        return toolbarButtons[tradeButtonIndex]
    }
    
    private var tradeNotificationImage: UIImageView?
    
    var didSelectCurrency: ((Currency) -> Void)?
    var didTapManageWallets: (() -> Void)?
    var didTapBuy: (() -> Void)?
    var didTapTrade: (() -> Void)?
    var didTapMenu: (() -> Void)?
    
    var okToShowPrompts: Bool {
        // On the initial display we need to load the walletes in the asset list table view first.
        // There's already a lot going on, so don't show the home-screen prompts right away.
        return !Store.state.displayCurrencies.isEmpty
    }

    // MARK: -
    
    init(walletAuthenticator: WalletAuthenticator) {
        self.walletAuthenticator = walletAuthenticator
        super.init(nibName: nil, bundle: nil)
    }

    func reload() {
        setInitialData()
        setupSubscriptions()
        assetList.reload()
        attemptShowPrompt()
    }

    override func viewDidLoad() {
        assetList.didSelectCurrency = didSelectCurrency
        assetList.didTapAddWallet = didTapManageWallets
        addSubviews()
        addConstraints()
        setInitialData()
        setupSubscriptions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.asyncAfter(deadline: .now() + promptDelay) { [unowned self] in
            self.attemptShowPrompt()
            
            if !Store.state.isLoginRequired {
                NotificationAuthorizer().showNotificationsOptInAlert(from: self, callback: { _ in
                    self.notificationHandler.checkForInAppNotifications()
                })
            }
        }

        updateTotalAssets()
    }
    
    // MARK: Setup

    private func addSubviews() {
        view.addSubview(subHeaderView)
        subHeaderView.addSubview(logo)
        subHeaderView.addSubview(totalAssetsLabel)
        subHeaderView.addSubview(total)
        subHeaderView.addSubview(debugLabel)
        view.addSubview(prompt)
        view.addSubview(toolbar)
    }

    private func addConstraints() {
        let headerHeight: CGFloat = 30.0
        let toolbarHeight: CGFloat = 74.0

        subHeaderView.constrain([
            subHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0.0),
            subHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            subHeaderView.heightAnchor.constraint(equalToConstant: headerHeight) ])

        total.constrain([
            total.trailingAnchor.constraint(equalTo: subHeaderView.trailingAnchor, constant: -C.padding[2]),
            total.centerYAnchor.constraint(equalTo: subHeaderView.topAnchor, constant: C.padding[1])
            ])

        totalAssetsLabel.constrain([
            totalAssetsLabel.trailingAnchor.constraint(equalTo: total.trailingAnchor),
            totalAssetsLabel.bottomAnchor.constraint(equalTo: total.topAnchor)
            ])
        
        logo.constrain([
            logo.leadingAnchor.constraint(equalTo: subHeaderView.leadingAnchor, constant: C.padding[2]),
            logo.centerYAnchor.constraint(equalTo: total.centerYAnchor)
            ])

        debugLabel.constrain([
            debugLabel.leadingAnchor.constraint(equalTo: logo.leadingAnchor),
            debugLabel.bottomAnchor.constraint(equalTo: logo.topAnchor, constant: -4.0)])
        
        promptHiddenConstraint = prompt.heightAnchor.constraint(equalToConstant: 0.0)
        prompt.constrain([
            prompt.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            prompt.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            prompt.topAnchor.constraint(equalTo: subHeaderView.bottomAnchor),
            promptHiddenConstraint
            ])
        
        addChildViewController(assetList, layout: {
            assetList.view.constrain([
                assetList.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                assetList.view.topAnchor.constraint(equalTo: prompt.bottomAnchor),
                assetList.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                assetList.view.bottomAnchor.constraint(equalTo: toolbar.topAnchor)])
        })
        
        toolbar.constrain([
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: -C.padding[1]),
            toolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: C.padding[1]),
            toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight) ])
    }

    private func setInitialData() {
        view.backgroundColor = .darkBackground
        subHeaderView.backgroundColor = .darkBackground
        subHeaderView.clipsToBounds = false
        
        navigationItem.titleView = UIView()
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.shadowImage = #imageLiteral(resourceName: "TransparentPixel")
        navigationController?.navigationBar.setBackgroundImage(#imageLiteral(resourceName: "TransparentPixel"), for: .default)
        
        logo.contentMode = .center
        
        total.textAlignment = .right
        total.text = "0"
        title = ""
        
        if E.isTestnet && !E.isScreenshots {
            debugLabel.text = "(Testnet)"
            debugLabel.isHidden = false
        } else if (E.isTestFlight || E.isDebug), let debugHost = UserDefaults.debugBackendHost {
            debugLabel.text = "[\(debugHost)]"
            debugLabel.isHidden = false
        } else {
            debugLabel.isHidden = true
        }
        
        totalAssetsLabel.text = S.HomeScreen.totalAssets
        
        setupToolbar()
        updateTotalAssets()
    }
    
    //Returns the added image view so that it can be kept track of for removing later
    private func addNotificationIndicatorToButton(button: UIButton) -> UIImageView? {
        guard (button.subviews.last as? UIImageView) == nil else { return nil }    // make sure we didn't already add the bell
        guard let buttonImageView = button.imageView else { return nil }
        let buyImageFrame = buttonImageView
        let bellImage = UIImage(named: "notification-bell")

        let bellImageView = UIImageView(image: bellImage)
        bellImageView.contentMode = .center

        let bellWidth = bellImage?.size.width ?? 0
        let bellHeight = bellImage?.size.height ?? 0
        
        let bellXOffset = buyImageFrame.center.x + 4
        let bellYOffset = buyImageFrame.center.y - bellHeight + 2.0
        
        bellImageView.frame = CGRect(x: bellXOffset, y: bellYOffset, width: bellWidth, height: bellHeight)
        
        button.addSubview(bellImageView)
        return bellImageView
    }
    
    private func setupToolbar() {
        let buttons = [(buyButtonTitle, #imageLiteral(resourceName: "buy"), #selector(buy)),
                       (S.HomeScreen.trade, #imageLiteral(resourceName: "trade"), #selector(trade)),
                       (S.HomeScreen.menu, #imageLiteral(resourceName: "menu"), #selector(menu))].map { (title, image, selector) -> UIBarButtonItem in
                        let button = UIButton.vertical(title: title, image: image)
                        button.tintColor = .navigationTint
                        button.addTarget(self, action: selector, for: .touchUpInside)
                        return UIBarButtonItem(customView: button)
        }
                
        let paddingWidth = C.padding[2]
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [
            flexibleSpace,
            buttons[0],
            flexibleSpace,
            buttons[1],
            flexibleSpace,
            buttons[2],
            flexibleSpace
        ]
        
        let buttonWidth = (view.bounds.width - (paddingWidth * CGFloat(buttons.count+1))) / CGFloat(buttons.count)
        let buttonHeight = CGFloat(44.0)
        buttons.forEach {
            $0.customView?.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight)
        }
        
        // Stash the UIButton's wrapped by the toolbar items in case we need add a badge later.
        buttons.forEach { (toolbarButtonItem) in
            if let button = toolbarButtonItem.customView as? UIButton {
                self.toolbarButtons.append(button)
            }
        }

        toolbar.isTranslucent = false
        toolbar.barTintColor = Theme.secondaryBackground
    }
    
    private func setupSubscriptions() {
        Store.unsubscribe(self)
        
        Store.subscribe(self, selector: {
            var result = false
            let oldState = $0
            let newState = $1
            $0.displayCurrencies.forEach { currency in
                result = result || oldState[currency]?.balance != newState[currency]?.balance
                result = result || oldState[currency]?.currentRate?.rate != newState[currency]?.currentRate?.rate
            }
            return result
        },
                        callback: { _ in
                            self.updateTotalAssets()
        })
        
        // prompts
        Store.subscribe(self, name: .didUpgradePin, callback: { _ in
            if self.currentPromptView?.type == .upgradePin {
                self.currentPromptView = nil
            }
        })
        Store.subscribe(self, name: .didWritePaperKey, callback: { _ in
            if self.currentPromptView?.type == .paperKey {
                self.currentPromptView = nil
            }
        })
        
        Store.subscribe(self, selector: {
            return ($0.experiments ?? nil) != ($1.experiments ?? nil)
        }, callback: { _ in
            // Do a full reload of the toolbar so it's laid out correctly with updated button titles.
            self.setupToolbar()
            self.saveEvent("experiment.buySellMenuButton", attributes: ["show": self.shouldShowBuyAndSell ? "true" : "false"])
        })
    }
        
    private func updateTotalAssets() {
        let fiatTotal: Decimal = Store.state.displayCurrencies.map {
            guard let balance = Store.state[$0]?.balance,
                let rate = Store.state[$0]?.currentRate else { return 0.0 }
            let amount = Amount(amount: balance,
                                rate: rate)
            return amount.fiatValue
            }.reduce(0.0, +)
        
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencySymbol = Store.state.orderedWallets.first?.currentRate?.currencySymbol ?? ""
        
        self.total.text = format.string(from: fiatTotal as NSDecimalNumber)
    }
    
    // MARK: Actions
    
    @objc private func buy() {
        saveEvent("currency.didTapBuyBitcoin", attributes: [ "buyAndSell": shouldShowBuyAndSell ? "true" : "false" ])
        didTapBuy?()
    }
    
    @objc private func trade() {
        saveEvent("currency.didTapTrade", attributes: [:])
        UserDefaults.didTapTradeNotification = true
        didTapTrade?()
        tradeNotificationImage?.removeFromSuperview()
        tradeNotificationImage = nil
    }
    
    @objc private func menu() { didTapMenu?() }
    
    // MARK: - Prompt
    
    private let promptDelay: TimeInterval = 0.6
    private let inAppNotificationDelay: TimeInterval = 3.0
    
    private var currentPromptView: PromptView? {
        didSet {
            if currentPromptView != oldValue {
                var afterFadeOut: TimeInterval = 0.0
                if let oldPrompt = oldValue {
                    afterFadeOut = 0.15
                    UIView.animate(withDuration: 0.2, animations: {
                        oldValue?.alpha = 0.0
                    }, completion: { _ in
                        oldPrompt.removeFromSuperview()
                    })
                }
                
                if let newPrompt = currentPromptView {
                    newPrompt.alpha = 0.0
                    prompt.addSubview(newPrompt)
                    newPrompt.constrain(toSuperviewEdges: .zero)
                    prompt.layoutIfNeeded()
                    promptHiddenConstraint.isActive = false

                    // fade-in after fade-out and layout
                    UIView.animate(withDuration: 0.2, delay: afterFadeOut + 0.15, options: .curveEaseInOut, animations: {
                        newPrompt.alpha = 1.0
                    })
                    
                } else {
                    promptHiddenConstraint.isActive = true
                }
                
                // layout after fade-out
                UIView.animate(withDuration: 0.2, delay: afterFadeOut, options: .curveEaseInOut, animations: {
                    self.view.layoutIfNeeded()
                })
            }
        }
    }
    
    private func attemptShowPrompt() {
        guard okToShowPrompts else { return }
        guard currentPromptView == nil else { return }
        
        if let nextPrompt = PromptFactory.nextPrompt(walletAuthenticator: walletAuthenticator) {
            self.saveEvent("prompt.\(nextPrompt.name).displayed")
            
            // didSet {} for 'currentPromptView' will display the prompt view
            currentPromptView = PromptFactory.createPromptView(prompt: nextPrompt, presenter: self)
            
            nextPrompt.didPrompt()
            
            guard let prompt = currentPromptView else { return }
            
            prompt.dismissButton.tap = { [unowned self] in
                self.saveEvent("prompt.\(nextPrompt.name).dismissed")
                self.currentPromptView = nil
            }
            
            if !prompt.shouldHandleTap {
                prompt.continueButton.tap = { [unowned self] in
                    // TODO:BCH move out of home screen
                    
                    if let trigger = nextPrompt.trigger {
                        Store.trigger(name: trigger)
                    }
                    self.saveEvent("prompt.\(nextPrompt.name).trigger")
                    self.currentPromptView = nil
                }                
            }
            
        } else {
            currentPromptView = nil
        }
    }
    
    // MARK: -

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
