//
//  RecoveryKeyCompleteViewController.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-04-11.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

class RecoveryKeyCompleteViewController: BaseRecoveryKeyViewController {

    private var proceedToWallet: (() -> Void)?
    private var fromNewUserOnboarding: Bool = false
    
    private var lockTopConstraintConstant: CGFloat {
        let statusHeight = UIApplication.shared.statusBarFrame.height
        let navigationHeight = ((navigationController?.navigationBar.frame.height) ?? 44)
        if E.isIPhone6OrSmaller {
            return (UIScreen.main.bounds.height * 0.2) - statusHeight - navigationHeight
        } else {
            return 200 - statusHeight - navigationHeight
        }
    }

    private let lockSuccessIcon = UIImageView(image: UIImage(named: "RecoveryKeyLockImageSuccess"))
    private let headingLabel = UILabel()
    private let subheadingLabel = UILabel()
    private let continueButton = BRDButton(title: S.RecoverKeyFlow.goToWalletButtonTitle, type: .primary)

    init(fromOnboarding: Bool, proceedToWallet: (() -> Void)?) {
        super.init()
        self.fromNewUserOnboarding = fromOnboarding
        self.proceedToWallet = proceedToWallet
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var shouldShowGoToWalletButton: Bool {
        return fromNewUserOnboarding
    }
    
    override var closeButtonStyle: BaseRecoveryKeyViewController.CloseButtonStyle {
        return self.shouldShowGoToWalletButton ? super.closeButtonStyle : .close
    }
    
    override func onCloseButton() {
        dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.primaryBackground
        navigationItem.setHidesBackButton(true, animated: false)
        
        //
        // lock button
        //
        view.addSubview(lockSuccessIcon)
        
        lockSuccessIcon.contentMode = .scaleAspectFit
        view.addSubview(lockSuccessIcon)
        lockSuccessIcon.constrain([
            lockSuccessIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lockSuccessIcon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: lockTopConstraintConstant)
            ])
        
        //
        // labels
        //
        let titles = [S.RecoverKeyFlow.successHeading, S.RecoverKeyFlow.successSubheading]
        let fonts = [Theme.h2Title, Theme.body1]
        let colors = [Theme.primaryText, Theme.secondaryText]
        let xInsets: CGFloat = E.isSmallScreen ? 40 : 62
        
        // define anchor/constant pairs for the label top constraints
        let topConstraints: [(a: NSLayoutYAxisAnchor, c: CGFloat)] = [(lockSuccessIcon.bottomAnchor, 38),
                                                                      (headingLabel.bottomAnchor, 18)]

        for (i, label) in [headingLabel, subheadingLabel].enumerated() {
            view.addSubview(label)
            label.textAlignment = .center
            label.font = fonts[i]
            label.textColor = colors[i]
            label.numberOfLines = 0
            
            label.text = titles[i]
            
            label.constrain([
                label.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: xInsets),
                label.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -xInsets),
                label.topAnchor.constraint(equalTo: topConstraints[i].a, constant: topConstraints[i].c)
                ])
        }
        
        //
        // go-to-wallet button
        //
        if shouldShowGoToWalletButton {
            view.addSubview(continueButton)
            
            constrainContinueButton(continueButton)
            continueButton.tap = { [unowned self] in
                self.proceedToWallet?()
            }
        } else {
            showCloseButton()
        }
    }
}
