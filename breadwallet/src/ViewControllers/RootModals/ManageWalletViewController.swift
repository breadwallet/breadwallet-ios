//
//  ManageWalletViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-11.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class ManageWalletViewController: UIViewController, ModalPresentable, Subscriber {

    var parentView: UIView? //ModalPresentable
    private let textFieldLabel = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let textField = UITextField()
    private let separator = UIView(color: .secondaryShadow)
    fileprivate let body = UILabel.wrapping(font: .customBody(size: 13.0), color: .secondaryGrayText)
    fileprivate let maxWalletNameLength = 20

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        saveWalletName()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        Store.unsubscribe(self)
    }

    private func addSubviews() {
        view.addSubview(textFieldLabel)
        view.addSubview(textField)
        view.addSubview(separator)
        view.addSubview(body)
    }

    private func addConstraints() {
        textFieldLabel.constrain([
            textFieldLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            textFieldLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: C.padding[2]),
            textFieldLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]) ])
        textField.constrain([
            textField.leadingAnchor.constraint(equalTo: textFieldLabel.leadingAnchor),
            textField.topAnchor.constraint(equalTo: textFieldLabel.bottomAnchor),
            textField.trailingAnchor.constraint(equalTo: textFieldLabel.trailingAnchor) ])
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            separator.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: C.padding[2]),
            separator.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: separator.leadingAnchor),
            body.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: separator.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -C.padding[2]) ])
    }

    private func setData() {
        view.backgroundColor = .white
        textField.textColor = .darkText
        textField.font = .customBody(size: 14.0)
        textField.returnKeyType = .done
        textFieldLabel.text = S.ManageWallet.textFieldLabel
        textField.delegate = self

        // TODO:BCH
        self.textField.text = Currencies.btc.state?.name
        let creationDate = Currencies.btc.state?.creationDate ?? Date()
        if creationDate.timeIntervalSince1970 > 0 {
            let df = DateFormatter()
            df.dateFormat = "MMMM d, yyyy"
            body.text = "\(S.ManageWallet.description)\n\n\(S.ManageWallet.creationDatePrefix) \(df.string(from: creationDate))"
        } else {
            body.text = S.ManageWallet.description
        }
    }

    // MARK: - Keyboard Notifications
    @objc private func keyboardWillShow(notification: Notification) {
        copyKeyboardChangeAnimation(notification: notification)
    }

    @objc private func keyboardWillHide(notification: Notification) {
        copyKeyboardChangeAnimation(notification: notification)
    }

    private func copyKeyboardChangeAnimation(notification: Notification) {
        guard let info = KeyboardNotificationInfo(notification.userInfo) else { return }
        UIView.animate(withDuration: info.animationDuration, delay: 0, options: info.animationOptions, animations: {
            guard let parentView = self.parentView else { return }
            parentView.frame = parentView.frame.offsetBy(dx: 0, dy: info.deltaY)
        }, completion: nil)
    }

    func saveWalletName() {
        guard var name = textField.text else { return }
        if name.utf8.count > maxWalletNameLength {
            name = String(name[..<name.index(name.startIndex, offsetBy: maxWalletNameLength)])
        }
        //TODO:BCH multi-currency support
        Store.perform(action: WalletChange(Currencies.btc).setWalletName(name))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ManageWalletViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        saveWalletName()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return true }
        if text.utf8.count + string.utf8.count > maxWalletNameLength {
            return false
        } else {
            return true
        }
    }
}

extension ManageWalletViewController: ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.manageWallet
    }
    
    var faqCurrency: Currency? {
        return nil
    }

    var modalTitle: String {
        return S.ManageWallet.title
    }
}
