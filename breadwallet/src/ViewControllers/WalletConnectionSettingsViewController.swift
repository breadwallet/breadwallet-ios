// 
//  WalletConnectionSettingsViewController.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-08-28.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit
import BRCrypto

class WalletConnectionSettingsViewController: UIViewController {

    private let walletConnectionSettings: WalletConnectionSettings
    private var currency: Currency {
        return Currencies.btc.instance!
    }

    // views
    private let imageView = UIImageView()
    private let explanationLabel = UILabel.wrapping(font: Theme.body1, color: Theme.secondaryText)
    // Toggle for enabling Touch ID or Face ID to unlock the BRD app.
    private let switchLabel = UILabel.wrapping(font: Theme.body1, color: Theme.primaryText)
    private let toggleSwitch = UISwitch()

    // MARK: - Lifecycle

    init(walletConnectionSettings: WalletConnectionSettings) {
        self.walletConnectionSettings = walletConnectionSettings
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        [imageView, explanationLabel, switchLabel, toggleSwitch].forEach { view.addSubview($0) }
        setUpAppearance()
        addConstraints()
        bindData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setWhiteStyle()
    }

    private func setUpAppearance() {
        view.backgroundColor = Theme.primaryBackground
        explanationLabel.textAlignment = .center
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

        switchLabel.constrain([
            switchLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: C.padding[2]),
            switchLabel.topAnchor.constraint(equalTo: explanationLabel.bottomAnchor, constant: C.padding[5])
            ])

        toggleSwitch.constrain([
            toggleSwitch.centerYAnchor.constraint(equalTo: switchLabel.centerYAnchor),
            toggleSwitch.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -C.padding[2]),
            toggleSwitch.leftAnchor.constraint(greaterThanOrEqualTo: switchLabel.rightAnchor, constant: C.padding[1])
            ])
    }

    private func bindData() {
        imageView.image = UIImage(named: "")
        explanationLabel.text = S.WalletConnectionSettings.explanatoryText
        switchLabel.text = S.WalletConnectionSettings.switchLabel

        let selectedMode = walletConnectionSettings.mode(for: currency)
        toggleSwitch.isOn = selectedMode == WalletConnectionMode.api_only

        toggleSwitch.valueChanged = { [weak self] in
            guard let `self` = self else { return }
            let newMode = self.toggleSwitch.isOn
                ? WalletConnectionMode.api_only
                : WalletConnectionMode.p2p_only
            self.walletConnectionSettings.set(mode: newMode, for: self.currency)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
