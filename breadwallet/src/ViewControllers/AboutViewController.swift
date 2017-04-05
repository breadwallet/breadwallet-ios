//
//  AboutViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-05.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

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
        view.backgroundColor = .white
        view.tintColor = C.defaultTintColor
        titleLabel.text = S.About.title
        subheader.text = "Bread"
        terms.setTitle(S.About.terms, for: .normal)
        terms.titleLabel?.font = UIFont.customBody(size: 13.0)
        privacy.setTitle(S.About.privacy, for: .normal)
        privacy.titleLabel?.font = UIFont.customBody(size: 13.0)
        footer.textAlignment = .center
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            footer.text = "\(S.About.footer) \(version)"
        }
    }
}
