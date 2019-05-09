//
//  RecoveryKeyCompleteViewController.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-04-11.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import UIKit

class RecoveryKeyCompleteViewController: BaseRecoveryKeyViewController {

    private var proceedToWallet: (() -> Void)?
    
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

    init(proceedToWallet: (() -> Void)?) {
        super.init()
        self.proceedToWallet = proceedToWallet
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .primaryBackground
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
        let fonts = [UIFont.h2Title, UIFont.body1]
        let colors = [UIColor.primaryText, UIColor.secondaryText]
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
        view.addSubview(continueButton)
        
        constrainContinueButton(continueButton)
        continueButton.tap = { [unowned self] in
            self.proceedToWallet?()
        }
    }
}
