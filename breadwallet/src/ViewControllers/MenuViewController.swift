//
//  MenuViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class MenuViewController: UIViewController {

    let close = UIButton.close()
    var didDismiss: (() -> Void)?


    deinit {
        print("making sure deinit called")
    }

    override func viewDidLoad() {
        view.backgroundColor = .white

        view.layer.cornerRadius = 6.0
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowRadius = 4.0
        view.layer.shadowOffset = .zero

        view.addSubview(close)

        close.constrain([
                close.constraint(.leading, toView: view, constant: C.padding[2]),
                close.constraint(.top, toView: view, constant: C.padding[2]),
                close.constraint(.width, constant: 44.0),
                close.constraint(.height, constant: 44.0)
            ])

        close.addTarget(self, action: #selector(MenuViewController.closeTapped), for: .touchUpInside)
    }

    //Even though the status bar is hidden for this view,
    //it still needs to be set to light as it will temporarily
    //transition to black when this view gets presented
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: {
            self.didDismiss?()
        })
    }
}
