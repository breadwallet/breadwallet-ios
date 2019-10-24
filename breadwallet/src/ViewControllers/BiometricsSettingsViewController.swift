//
//  BiometricsSettingsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-27.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import LocalAuthentication

class BiometricsSettingsViewController: UIViewController, Subscriber, Trackable {

    lazy var biometricType = LAContext.biometricType()
        
    var explanatoryText: String {
        return biometricType == .touch ? S.TouchIdSettings.explanatoryText : S.FaceIDSettings.explanatoryText
    }
    
    var unlockTitleText: String {
        return biometricType == .touch ? S.TouchIdSettings.unlockTitleText : S.FaceIDSettings.unlockTitleText
    }
    
    var transactionsTitleText: String {
        return biometricType == .touch ? S.TouchIdSettings.transactionsTitleText : S.FaceIDSettings.transactionsTitleText
    }
    
    var imageName: String {
        return biometricType == .touch ? "TouchId-Large" : "FaceId-Large"
    }
    
    private let imageView = UIImageView()
    
    private let explanationLabel = UILabel.wrapping(font: Theme.body1, color: Theme.secondaryText)
    
    // Toggle for enabling Touch ID or Face ID to unlock the BRD app.
    private let unlockTitleLabel = UILabel.wrapping(font: Theme.body1, color: Theme.primaryText)
    
    // Toggle for enabling Touch ID or Face ID for sending money.
    private let transactionsTitleLabel = UILabel.wrapping(font: Theme.body1, color: Theme.primaryText)

    private let unlockToggle = UISwitch()
    private let transactionsToggle = UISwitch()
    
    private let unlockToggleSeparator = UIView()
    private let transactionsToggleSeparator = UIView()
    
    private var hasSetInitialValueForUnlockToggle = false
    private var hasSetInitialValueForTransactions = false
    
    private var walletAuthenticator: WalletAuthenticator
    
    init(_ walletAuthenticator: WalletAuthenticator) {
        self.walletAuthenticator = walletAuthenticator
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setWhiteStyle()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        [imageView,
         explanationLabel, unlockTitleLabel, transactionsTitleLabel,
         unlockToggle, transactionsToggle,
         unlockToggleSeparator, transactionsToggleSeparator].forEach({ view.addSubview($0) })
        
        setUpAppearance()
        addConstraints()
        setData()
        addFaqButton()
    }
    
    private func setUpAppearance() {
        view.backgroundColor = Theme.primaryBackground
        explanationLabel.textAlignment = .center
        
        unlockToggleSeparator.backgroundColor = Theme.tertiaryBackground
        transactionsToggleSeparator.backgroundColor = Theme.tertiaryBackground
        
        [unlockTitleLabel, transactionsTitleLabel].forEach({
            $0.adjustsFontSizeToFitWidth = true
            $0.minimumScaleFactor = 0.5
        })
            
    }
    
    private func addConstraints() {
        
        let screenHeight: CGFloat = UIScreen.main.bounds.height
        let topMarginPercent: CGFloat = 0.08
        let imageTopMargin: CGFloat = (screenHeight * topMarginPercent)
        let leftRightMargin: CGFloat = 40.0
        
        imageView.constrain([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: imageTopMargin)
            ])
        
        explanationLabel.constrain([
            explanationLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: leftRightMargin),
            explanationLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -leftRightMargin),
            explanationLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: C.padding[2])
            ])
        
        //
        // unlock BRD toggle and associated labels
        //
        
        unlockTitleLabel.constrain([
            unlockTitleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: C.padding[2]),
            unlockTitleLabel.rightAnchor.constraint(equalTo: unlockToggle.leftAnchor, constant: -C.padding[2]),
            unlockTitleLabel.topAnchor.constraint(equalTo: explanationLabel.bottomAnchor, constant: C.padding[5])
            ])
        
        unlockToggle.constrain([
            unlockToggle.centerYAnchor.constraint(equalTo: unlockTitleLabel.centerYAnchor),
            unlockToggle.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -C.padding[2])
            ])
        
        unlockToggleSeparator.constrain([
            unlockToggleSeparator.topAnchor.constraint(equalTo: unlockTitleLabel.bottomAnchor, constant: C.padding[1]),
            unlockToggleSeparator.leftAnchor.constraint(equalTo: view.leftAnchor),
            unlockToggleSeparator.rightAnchor.constraint(equalTo: view.rightAnchor),
            unlockToggleSeparator.heightAnchor.constraint(equalToConstant: 1.0)
            ])
        
        //
        // send money toggle and associated labels
        //

        transactionsTitleLabel.constrain([
            transactionsTitleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: C.padding[2]),
            transactionsTitleLabel.rightAnchor.constraint(equalTo: transactionsToggle.leftAnchor, constant: -C.padding[2]),
            transactionsTitleLabel.topAnchor.constraint(equalTo: unlockTitleLabel.bottomAnchor, constant: C.padding[5])
            ])
        
        transactionsToggle.constrain([
            transactionsToggle.centerYAnchor.constraint(equalTo: transactionsTitleLabel.centerYAnchor),
            transactionsToggle.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -C.padding[2])
            ])

        unlockToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        transactionsToggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        transactionsToggleSeparator.constrain([
            transactionsToggleSeparator.topAnchor.constraint(equalTo: transactionsTitleLabel.bottomAnchor, constant: C.padding[1]),
            transactionsToggleSeparator.leftAnchor.constraint(equalTo: view.leftAnchor),
            transactionsToggleSeparator.rightAnchor.constraint(equalTo: view.rightAnchor),
            transactionsToggleSeparator.heightAnchor.constraint(equalToConstant: 1.0)
            ])

    }

    private func setData() {
        imageView.image = UIImage(named: imageName)
        explanationLabel.text = explanatoryText
        unlockTitleLabel.text = unlockTitleText
        transactionsTitleLabel.text = transactionsTitleText
        
        unlockToggle.isOn = walletAuthenticator.isBiometricsEnabledForUnlocking
        transactionsToggle.isOn = walletAuthenticator.isBiometricsEnabledForTransactions
        transactionsToggle.isEnabled = unlockToggle.isOn
        
        unlockToggle.valueChanged = { [weak self] in
            guard let `self` = self else { return }
            self.toggleChanged(toggle: self.unlockToggle)
            self.saveEvent("event.enableBiometrics",
                           attributes: ["isEnabled": "\(self.unlockToggle.isOn)", "type": "unlock"])
        }
        
        transactionsToggle.valueChanged = { [weak self] in
            guard let `self` = self else { return }
            self.toggleChanged(toggle: self.transactionsToggle)
            self.saveEvent("event.enableBiometrics",
                           attributes: ["isEnabled": "\(self.transactionsToggle.isOn)", "type": "sending"])
        }
    }

    private func toggleChanged(toggle: UISwitch) {
        if toggle == unlockToggle {
            
            // If the unlock toggle is off, the transactions toggle is forced to off and disabled.
            // i.e., Only allow Touch/Face ID for sending transactions if the user has enabled Touch/Face ID
            // for unlocking the app.
            if !toggle.isOn {
                self.walletAuthenticator.isBiometricsEnabledForUnlocking = false
                self.walletAuthenticator.isBiometricsEnabledForTransactions = false
                
                self.transactionsToggle.setOn(false, animated: true)
            } else {
                if LAContext.canUseBiometrics || E.isSimulator {
                    
                    LAContext.checkUserBiometricsAuthorization(callback: { (result) in
                        if result == .success {
                            self.walletAuthenticator.isBiometricsEnabledForUnlocking = true
                        } else {
                            self.unlockToggle.setOn(false, animated: true)
                        }
                    })
                    
                } else {
                    self.presentCantUseBiometricsAlert()
                    self.unlockToggle.setOn(false, animated: true)
                }
            }
            
            self.transactionsToggle.isEnabled = self.unlockToggle.isOn
            
        } else if toggle == transactionsToggle {
            self.walletAuthenticator.isBiometricsEnabledForTransactions = toggle.isOn
        }
    }
    
    private func addFaqButton() {
        let negativePadding = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        negativePadding.width = -16.0
        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.enableTouchId)
        faqButton.tintColor = .white
        navigationItem.rightBarButtonItems = [negativePadding, UIBarButtonItem(customView: faqButton)]
    }

    fileprivate func presentCantUseBiometricsAlert() {
        let unavailableAlertTitle = LAContext.biometricType() == .face ? S.FaceIDSettings.unavailableAlertTitle : S.TouchIdSettings.unavailableAlertTitle
        let unavailableAlertMessage = LAContext.biometricType() == .face ? S.FaceIDSettings.unavailableAlertMessage : S.TouchIdSettings.unavailableAlertMessage
        
        let alert = UIAlertController(title: unavailableAlertTitle,
                                      message: unavailableAlertMessage,
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: nil))

        alert.addAction(UIAlertAction(title: S.Button.settings, style: .default, handler: { _ in
            guard let url = URL(string: "App-Prefs:root") else { return }
            UIApplication.shared.open(url)
        }))

        present(alert, animated: true, completion: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
