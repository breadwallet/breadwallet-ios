//
//  RecoverWalletIntroViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-23.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class RecoverWalletIntroViewController : UIViewController {

    //MARK: - Public
    init(didTapNext: @escaping () -> Void) {
        self.didTapNext = didTapNext
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let didTapNext: () -> Void
    private let header = UIView(color: .purple)
    private let nextButton = ShadowButton(title: "Next", type: .primary)

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(nextButton)
        nextButton.constrain([
            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            nextButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[3]),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            nextButton.heightAnchor.constraint(equalToConstant: C.Sizes.buttonHeight) ])
        nextButton.tap = didTapNext
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
