//
//  ScanViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-12.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ScanViewController: UIViewController {

    override func viewDidLoad() {
        view.backgroundColor = .white

        let close = UIButton.close()
        view.addSubview(close)
        close.constrain([
                close.constraint(.leading, toView: view, constant: C.padding[2]),
                close.constraint(.bottom, toView: view, constant: -C.padding[2]),
                close.constraint(.width, constant: 44.0),
                close.constraint(.height, constant: 44.0)
            ])
        close.addTarget(self, action: #selector(ScanViewController.closeTapped), for: .touchUpInside)
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }

}
