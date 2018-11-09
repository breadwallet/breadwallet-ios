//
//  ReScanViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-10.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class ReScanViewController: UIViewController, Subscriber {

    init(currency: Currency) {
        self.currency = currency
        self.faq = .buildFaqButton(articleId: ArticleIds.reScan, currency: currency)
        super.init(nibName: nil, bundle: nil)
    }

    private let currency: Currency
    private let header = UILabel(font: .customBold(size: 26.0), color: .white)
    private let body = UILabel.wrapping(font: .systemFont(ofSize: 15.0))
    private let button = BRDButton(title: S.ReScan.buttonTitle, type: .primary)
    private let footer = UILabel.wrapping(font: .customBody(size: 16.0), color: .white)
    private let faq: UIButton

    deinit {
        Store.unsubscribe(self)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
        
        // need to be connected to p2p network and synced up before rescan can be initated
        Store.trigger(name: .retrySync(self.currency))
        Store.subscribe(self, selector: { $0[self.currency]?.syncState != $1[self.currency]?.syncState },
                        callback: { state in
                            guard let syncState = state[self.currency]?.syncState else { return }
                            self.button.isEnabled = syncState == .success
        })
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(faq)
        view.addSubview(body)
        view.addSubview(button)
        view.addSubview(footer)
    }

    private func addConstraints() {
        header.constrain([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            header.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2]) ])
        faq.constrain([
            faq.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            faq.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            faq.widthAnchor.constraint(equalToConstant: 44.0),
            faq.heightAnchor.constraint(equalToConstant: 44.0) ])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            body.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: faq.trailingAnchor) ])
        footer.constrain([
            footer.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: faq.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor, constant: -C.padding[3]) ])
        button.constrain([
            button.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -C.padding[2]),
            button.heightAnchor.constraint(equalToConstant: C.Sizes.buttonHeight) ])
    }

    private func setInitialData() {
        view.backgroundColor = .darkBackground
        faq.tintColor = .navigationTint
        header.text = S.ReScan.header
        body.attributedText = bodyText
        footer.text = S.ReScan.footer
        button.tap = { [weak self] in
            self?.presentRescanAlert()
        }
    }

    private func presentRescanAlert() {
        let alert = UIAlertController(title: S.ReScan.alertTitle, message: S.ReScan.alertMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.cancel, style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: S.ReScan.alertAction, style: .default, handler: { _ in
            Store.trigger(name: .rescan(self.currency))
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    private var bodyText: NSAttributedString {
        let body = NSMutableAttributedString()
        let headerAttributes = [ NSAttributedStringKey.font: UIFont.customBold(size: 16.0),
                                 NSAttributedStringKey.foregroundColor: UIColor.white ]
        let bodyAttributes = [ NSAttributedStringKey.font: UIFont.customBody(size: 16.0),
                               NSAttributedStringKey.foregroundColor: UIColor.white ]

        body.append(NSAttributedString(string: "\(S.ReScan.subheader2)\n", attributes: headerAttributes))
        body.append(NSAttributedString(string: "\(S.ReScan.body2)\n\n\(S.ReScan.body3)", attributes: bodyAttributes))
        return body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
