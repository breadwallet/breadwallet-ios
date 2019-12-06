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
import SafariServices

class WalletConnectionSettingsViewController: UIViewController, Trackable {

    private let walletConnectionSettings: WalletConnectionSettings
    private var currency: Currency {
        return Currencies.btc.instance!
    }
    private let modeChangeCallback: (WalletConnectionMode) -> Void

    // views
    private let animatedBlockSetLogo = AnimatedBlockSetLogo()
    private let header = UILabel.wrapping(font: Theme.h3Accent, color: Theme.primaryText)
    private let explanationLabel = UITextView()
    private let footerLabel = UILabel.wrapping(font: Theme.caption, color: Theme.secondaryText)
    private let toggleSwitch = UISwitch()
    private let footerLogo = UIImageView(image: UIImage(named: "BlocksetLogoWhite"))
    private let mainBackground = UIView(color: Theme.secondaryBackground)
    private let footerBackground = UIView(color: Theme.secondaryBackground)
    
    // MARK: - Lifecycle

    init(walletConnectionSettings: WalletConnectionSettings,
         modeChangeCallback: @escaping (WalletConnectionMode) -> Void) {
        self.walletConnectionSettings = walletConnectionSettings
        self.modeChangeCallback = modeChangeCallback
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        [mainBackground, footerBackground, animatedBlockSetLogo, header, explanationLabel, toggleSwitch, footerLabel, footerLogo].forEach { view.addSubview($0) }
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
        mainBackground.layer.cornerRadius = 4.0
        footerBackground.layer.cornerRadius = 4.0
        mainBackground.clipsToBounds = true
        footerBackground.clipsToBounds = true
        
        // Clip the main view so that the block animation doesn't show when back gesture is active
        view.clipsToBounds = true
        
        if E.isIPhone5 {
            animatedBlockSetLogo.isHidden = true
            animatedBlockSetLogo.constrain([
                animatedBlockSetLogo.heightAnchor.constraint(equalToConstant: 0.0),
                animatedBlockSetLogo.widthAnchor.constraint(equalToConstant: 0.0)])
        }
    }

    private func addConstraints() {
        let screenHeight: CGFloat = UIScreen.main.bounds.height
        let topMarginPercent: CGFloat = 0.08
        let imageTopMargin: CGFloat = E.isIPhone6 ? 8.0 : (screenHeight * topMarginPercent)
        let containerTopMargin: CGFloat = E.isIPhone6 ? 0.0 : -C.padding[2]
        let leftRightMargin: CGFloat = 54.0

        mainBackground.constrain([
            mainBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            mainBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            mainBackground.topAnchor.constraint(equalTo: animatedBlockSetLogo.topAnchor, constant: containerTopMargin),
            mainBackground.bottomAnchor.constraint(equalTo: toggleSwitch.bottomAnchor, constant: C.padding[4]) ])
        
        animatedBlockSetLogo.constrain([
            animatedBlockSetLogo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animatedBlockSetLogo.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: imageTopMargin)
            ])

        header.constrain([
            header.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            header.topAnchor.constraint(equalTo: animatedBlockSetLogo.bottomAnchor, constant: E.isIPhone5 ? C.padding[2] : C.padding[4])])
        
        explanationLabel.constrain([
            explanationLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: leftRightMargin),
            explanationLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -leftRightMargin),
            explanationLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2])
            ])

        toggleSwitch.constrain([
            toggleSwitch.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toggleSwitch.topAnchor.constraint(equalTo: explanationLabel.bottomAnchor, constant: C.padding[3])
            ])
        
        footerLabel.constrain([
            footerLabel.bottomAnchor.constraint(equalTo: footerBackground.topAnchor, constant: -C.padding[1]),
            footerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
        
        footerLogo.constrain([
            footerLogo.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -52.0),
            footerLogo.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        
        footerBackground.constrain([
            footerBackground.topAnchor.constraint(equalTo: footerLogo.topAnchor, constant: -C.padding[2]),
            footerBackground.leadingAnchor.constraint(equalTo: footerLogo.leadingAnchor, constant: -C.padding[2]),
            footerBackground.trailingAnchor.constraint(equalTo: footerLogo.trailingAnchor, constant: C.padding[2]),
            footerBackground.bottomAnchor.constraint(equalTo: footerLogo.bottomAnchor, constant: C.padding[2])
            ])
    }

    private func bindData() {
        title = S.WalletConnectionSettings.viewTitle
        header.text = S.WalletConnectionSettings.header
        footerLabel.text = S.WalletConnectionSettings.footerTitle
        
        let selectedMode = walletConnectionSettings.mode(for: currency)
        toggleSwitch.isOn = selectedMode == WalletConnectionMode.api_only
        
        //This needs to be done in the next run loop or else the animations don't
        //start in the right spot
        DispatchQueue.main.async {
            self.animatedBlockSetLogo.isOn = self.toggleSwitch.isOn
        }
        
        toggleSwitch.valueChanged = { [weak self] in
            guard let `self` = self else { return }
            
            // Fast sync can only be turned on via the toggle.
            // It needs to be turned off by the confirmation alert.
            if self.toggleSwitch.isOn {
                self.setMode()
            } else {
                self.confirmToggle()
            }
        }
        
        setupLink()
    }
    
    private func setMode() {
        let newMode = toggleSwitch.isOn
            ? WalletConnectionMode.api_only
            : WalletConnectionMode.p2p_only
        walletConnectionSettings.set(mode: newMode, for: currency)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        animatedBlockSetLogo.isOn.toggle()
        saveEvent(makeToggleEvent())
        self.modeChangeCallback(newMode)
    }
    
    private func confirmToggle() {
        let alert = UIAlertController(title: "", message: S.WalletConnectionSettings.confirmation, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .cancel, handler: { _ in
            self.toggleSwitch.setOn(true, animated: true)
        }))
        alert.addAction(UIAlertAction(title: S.WalletConnectionSettings.turnOff, style: .default, handler: { _ in
            self.setMode()
        }))
        present(alert, animated: true)
    }
    
    private func setupLink() {
        let string = NSMutableAttributedString(string: S.WalletConnectionSettings.explanatoryText)
        let linkRange = string.mutableString.range(of: S.WalletConnectionSettings.link)
        if linkRange.location != NSNotFound {
            string.addAttribute(.link, value: NSURL(string: "https://www.brd.com/blog/fastsync-explained")!, range: linkRange)
        }
        explanationLabel.attributedText = string
        explanationLabel.delegate = self
        
        explanationLabel.isEditable = false
        explanationLabel.backgroundColor = .clear
        explanationLabel.font = Theme.body1
        explanationLabel.textColor = Theme.secondaryText
        explanationLabel.textAlignment = .center
        
        //TODO:CYRPTO - is there a way to make this false but also
        // keep the link working?
        //explanationLabel.isSelectable = false
        explanationLabel.isScrollEnabled = false
    }
    
    private func makeToggleEvent() -> String {
        let event = toggleSwitch.isOn ? Event.enable.name : Event.disable.name
        return makeEventName([EventContext.fastSync.name, currency.code, event])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension WalletConnectionSettingsViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        let vc = SFSafariViewController(url: URL)
        self.present(vc, animated: true, completion: nil)
        return false
    }
}
