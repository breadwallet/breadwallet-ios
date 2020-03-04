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

    private var titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)
    private let logo = UIImageView(image: #imageLiteral(resourceName: "coinBlueWhite"))
    private let logoBackground = UIView()
    private let blog = AboutCell(text: S.About.blog)
    private let twitter = AboutCell(text: S.About.twitter)
    private let reddit = AboutCell(text: S.About.reddit)
    private let privacy = UIButton(type: .system)
    private let footer = UILabel(font: .customBody(size: 13.0), color: .secondaryGrayText)
    override func viewDidLoad() {
        if #available(iOS 11.0, *),
            let labelTextColor = UIColor(named:"labelTextColor"),
        let backgroundColor = UIColor(named: "lfBackgroundColor") {
            titleLabel.textColor = labelTextColor
            privacy.tintColor = labelTextColor
            view.backgroundColor = backgroundColor
         } else {
            privacy.tintColor = .liteWalletBlue
            view.backgroundColor = .whiteTint
        }
        
        addSubviews()
        addConstraints()
        setData()
        setActions()
    }

    private func addSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(logoBackground)
        logoBackground.addSubview(logo)
        view.addSubview(blog)
        view.addSubview(twitter)
        view.addSubview(reddit)
        view.addSubview(privacy)
        view.addSubview(footer)
    }

    private func addConstraints() {
        titleLabel.constrain([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: C.padding[2]) ])
        logoBackground.constrain([
            logoBackground.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoBackground.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[3]),
            logoBackground.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.2),
            logoBackground.heightAnchor.constraint(equalTo: logoBackground.widthAnchor, multiplier: 1.0) ])
        logo.constrain(toSuperviewEdges: nil)
        blog.constrain([
            blog.topAnchor.constraint(equalTo: logoBackground.bottomAnchor, constant: C.padding[2]),
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
        privacy.constrain([
            privacy.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            privacy.topAnchor.constraint(equalTo: reddit.bottomAnchor, constant: C.padding[2])])
        footer.constrain([
            footer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            footer.topAnchor.constraint(equalTo: privacy.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 80)])
    }

    private func setData() {
        
        titleLabel.text = S.Settings.socialLinks
        privacy.setTitle(S.About.privacy, for: .normal)
        privacy.titleLabel?.font = UIFont.customBody(size: 13.0)
        footer.textAlignment = .center
        footer.numberOfLines = 4
        footer.text = String(format: S.About.footer, AppVersion.string)
        logo.contentMode = .scaleAspectFill
    }

    private func setActions() {
        blog.button.tap = strongify(self) { myself in
            myself.presentURL(string: "https://loafwallet.org")
        }
        twitter.button.tap = strongify(self) { myself in
            myself.presentURL(string: "https://twitter.com/Litewallet_App")
        }
        reddit.button.tap = strongify(self) { myself in
            myself.presentURL(string: "https://www.reddit.com/r/Litewallet/")
        }
        privacy.tap = strongify(self) { myself in
            myself.presentURL(string: "http://loafwallet.org/policy.html")
        }
    }

    private func presentURL(string: String) {
        let vc = SFSafariViewController(url: URL(string: string)!)
        self.present(vc, animated: true, completion: nil)
    }
}
