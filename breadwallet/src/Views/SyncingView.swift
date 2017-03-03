//
//  SyncingView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

private let progressHeight: CGFloat = 8.0

class SyncingView : UIView {

    init() {
        super.init(frame: .zero)
        setup()
    }

    var progress: CGFloat = 0.01 {
        didSet {
            progressForegroundWidth?.isActive = false
            progressForegroundWidth = progressForeground.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: progress)
            progressForegroundWidth?.isActive = true
            progressForeground.setNeedsDisplay()
        }
    }

    private let header = UILabel(font: .customBold(size: 14.0))
    private let date = UILabel(font: .customBody(size: 13.0))

    private let progressBackground: UIView = {
        let view = UIView()
        view.layer.cornerRadius = progressHeight/2.0
        view.layer.masksToBounds = true
        view.backgroundColor = .secondaryShadow
        return view
    }()

    private let progressForeground: UIView = {
        let view = GradientView()
        view.layer.cornerRadius = progressHeight/2.0
        view.layer.masksToBounds = true
        return view
    }()

    private var progressForegroundWidth: NSLayoutConstraint?

    private func setup() {
        addSubview(header)
        addSubview(date)
        addSubview(progressBackground)
        progressBackground.addSubview(progressForeground)

        header.constrain([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            header.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]) ])

        progressBackground.constrain([
            progressBackground.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            progressBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            progressBackground.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[2]),
            progressBackground.heightAnchor.constraint(equalToConstant: progressHeight) ])

        date.constrain([
            date.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            date.topAnchor.constraint(equalTo: progressBackground.bottomAnchor, constant: C.padding[1]) ])

        progressForegroundWidth = progressForeground.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: progress)
        progressForeground.constrain([
            progressForegroundWidth,
            progressForeground.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressForeground.centerYAnchor.constraint(equalTo: progressBackground.centerYAnchor),
            progressForeground.heightAnchor.constraint(equalTo: progressBackground.heightAnchor) ])

        setData()
    }

    private func setData() {
        header.text = "Syncing"
        date.text = "March 3, 2017"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
