//
//  ReScanViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-10.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import Mixpanel

class ReScanViewController : UIViewController, Subscriber {

    init(store: Store) {
        self.store = store
        self.faq = .buildFaqButton(store: store, articleId: ArticleIds.reScan)
        super.init(nibName: nil, bundle: nil)
    }

    private let header = UILabel(font: .customBold(size: 26.0), color: .darkText)
    private let body = UILabel.wrapping(font: .systemFont(ofSize: 15.0))
    private let button = ShadowButton(title: S.ReScan.buttonTitle, type: .primary)
    private let footer = UILabel.wrapping(font: .customBody(size: 16.0), color: .secondaryGrayText)
    private let store: Store
    private let faq: UIButton

    deinit {
        store.unsubscribe(self)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
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
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: C.padding[2]) ])
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
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -C.padding[3]) ])
        button.constrain([
            button.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -C.padding[2]),
            button.heightAnchor.constraint(equalToConstant: C.Sizes.buttonHeight) ])
    }

    private func setInitialData() {
        view.backgroundColor = .whiteTint
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
            self.store.trigger(name: .rescan)
            Mixpanel.mainInstance().track(event: MixpanelEvents._20200112_DSR.rawValue)
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
 
    private var bodyText: NSAttributedString {
        let body = NSMutableAttributedString()
        let headerAttributes = [ NSAttributedStringKey.font: UIFont.customBold(size: 16.0),
                                 NSAttributedStringKey.foregroundColor: UIColor.darkText ]
        let bodyAttributes = [ NSAttributedStringKey.font: UIFont.customBody(size: 16.0),
                               NSAttributedStringKey.foregroundColor: UIColor.darkText ]

        body.append(NSAttributedString(string: "\(S.ReScan.subheader1)\n", attributes: headerAttributes))
        body.append(NSAttributedString(string: "\(S.ReScan.body1)\n\n", attributes: bodyAttributes))
        body.append(NSAttributedString(string: "\(S.ReScan.subheader2)\n", attributes: headerAttributes))
        body.append(NSAttributedString(string: "\(S.ReScan.body2)\n\n\(S.ReScan.body3)", attributes: bodyAttributes))
        return body
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
