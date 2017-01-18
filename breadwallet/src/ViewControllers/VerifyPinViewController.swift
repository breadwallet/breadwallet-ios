//
//  VerifyPinViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

typealias VerifyPinCallback = (String, UIViewController) -> Void

class VerifyPinViewController : UIViewController {

    init(callback: @escaping VerifyPinCallback) {
        self.callback = callback
        super.init(nibName: nil, bundle: nil)
    }

    private let callback: VerifyPinCallback
    private let textField = UITextField()

    override func viewDidLoad() {
        view.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
        view.addSubview(textField)
        textField.borderStyle = .roundedRect
        textField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        textField.keyboardType = .numberPad
        textField.constrain([
            textField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            textField.widthAnchor.constraint(equalToConstant: 200.0),
            textField.heightAnchor.constraint(equalToConstant: 44.0) ])
        textField.becomeFirstResponder()
    }

    @objc private func textFieldDidChange(textField: UITextField) {
        guard let text = textField.text else { return }
        callback(text, self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
