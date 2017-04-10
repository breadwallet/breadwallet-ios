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

    var progress: CGFloat = 0.0 {
        didSet {
            progressForegroundWidth?.isActive = false
            progressForegroundWidth = progressForeground.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: progress)
            progressForegroundWidth?.isActive = true
            progressForeground.setNeedsDisplay()
        }
    }

    var timestamp: UInt32 = 0 {
        didSet {
            date.text = dateFormatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
        }
    }

    func setError(message: String) {
        header.text = message
        header.textColor = .cameraGuideNegative
        retry.isHidden = false
    }

    func resetAfterError() {
        setInitialData()
        header.textColor = .darkText
        retry.isHidden = true
    }

    private let header = UILabel(font: .customBold(size: 14.0))
    private let date = UILabel(font: .customBody(size: 13.0))

    let retry: UIButton = {
        let retry = UIButton(type: .system)
        retry.tintColor = C.defaultTintColor
        retry.setTitle(S.SyncingView.retry, for: .normal)
        return retry
    }()

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

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM. d, yyyy"
        return df
    }()

    private var progressForegroundWidth: NSLayoutConstraint?

    private func setup() {
        addSubview(header)
        addSubview(date)
        addSubview(progressBackground)
        addSubview(retry)

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
        retry.constrain([
            retry.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            retry.trailingAnchor.constraint(equalTo: progressBackground.trailingAnchor) ])

        setInitialData()
    }

    private func setInitialData() {
        header.text = S.SyncingView.header
        date.text = ""
        retry.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
