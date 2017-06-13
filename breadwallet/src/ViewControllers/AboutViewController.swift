//
//  AboutViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-05.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import SafariServices

class AboutViewController : UIViewController {

    private let titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)

    //TODO - replace circle and subheader with real logo
    private let circle = GradientCircle()
    private let subheader = UILabel(font: .customBody(size: 20.0), color: .darkText)
    private let blog = AboutCell(text: S.About.blog)
    private let twitter = AboutCell(text: S.About.twitter)
    private let reddit = AboutCell(text: S.About.reddit)
    private let terms = UIButton(type: .system)
    private let privacy = UIButton(type: .system)
    private let separator: UILabel = {
        let separator = UILabel(font: .customBody(size: 13.0), color: .secondaryGrayText)
        separator.text = "|"
        separator.textAlignment = .center
        return separator
    }()
    private let footer = UILabel(font: .customBody(size: 13.0), color: .secondaryGrayText)
    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setData()
        setActions()
    }

    private func addSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(circle)
        view.addSubview(subheader)
        view.addSubview(blog)
        view.addSubview(twitter)
        view.addSubview(reddit)
        view.addSubview(separator)
        view.addSubview(terms)
        view.addSubview(privacy)
        view.addSubview(footer)
    }

    private func addConstraints() {
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: C.padding[2]) ])
        circle.constrain([
            circle.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[4]),
            circle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            circle.heightAnchor.constraint(equalToConstant: GradientCircle.defaultSize),
            circle.widthAnchor.constraint(equalToConstant: GradientCircle.defaultSize) ])
        subheader.constrain([
            subheader.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: C.padding[1]),
            subheader.centerXAnchor.constraint(equalTo: view.centerXAnchor) ])
        blog.constrain([
            blog.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: C.padding[2]),
            blog.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blog.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
        twitter.constrain([
            twitter.topAnchor.constraint(equalTo: blog.bottomAnchor, constant: C.padding[2]),
            twitter.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            twitter.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])
        reddit.constrain([
            reddit.topAnchor.constraint(equalTo: twitter.bottomAnchor, constant: C.padding[2]),
            reddit.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            reddit.trailingAnchor.constraint(equalTo: view.trailingAnchor) ])

        separator.constrain([
            separator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            separator.topAnchor.constraint(equalTo: reddit.bottomAnchor, constant: C.padding[2])])
        terms.constrain([
            terms.centerYAnchor.constraint(equalTo: separator.centerYAnchor),
            terms.trailingAnchor.constraint(equalTo: separator.leadingAnchor, constant: -C.padding[1]) ])
        privacy.constrain([
            privacy.centerYAnchor.constraint(equalTo: separator.centerYAnchor),
            privacy.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: C.padding[1]) ])
        footer.constrain([
            footer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            footer.topAnchor.constraint(equalTo: separator.bottomAnchor) ])
    }

    private func setData() {
        view.backgroundColor = .whiteTint
        titleLabel.text = S.About.title
        subheader.text = "Bread"
        terms.setTitle(S.About.terms, for: .normal)
        terms.titleLabel?.font = UIFont.customBody(size: 13.0)
        privacy.setTitle(S.About.privacy, for: .normal)
        privacy.titleLabel?.font = UIFont.customBody(size: 13.0)
        footer.textAlignment = .center
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            footer.text = String(format: S.About.footer, "\(version)")
        }
    }

    private func setActions() {
        blog.button.tap = { [weak self] in
            self?.presentURL(string: "https://breadwallet.com/blog/")
        }
        twitter.button.tap = { [weak self] in
            self?.presentURL(string: "https://twitter.com/breadwalletapp")
        }
        reddit.button.tap = { [weak self] in
            self?.presentURL(string: "https://reddit.com/r/breadwallet/")
        }
        //TODO - find this link
        terms.tap = { [weak self] in
            self?.presentURL(string: "https://breadwallet.com/terms?")
        }
        privacy.tap = { [weak self] in
            self?.presentURL(string: "https://breadwallet.com/privacy-policy")
        }
    }

    private func presentURL(string: String) {
        let vc = SFSafariViewController(url: URL(string: string)!)
        self.present(vc, animated: true, completion: nil)
    }
}
