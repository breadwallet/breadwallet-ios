//
//  SyncingIndicator.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-02-16.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

enum SyncingIndicatorStyle {
    case home
    case account
}

/// Small syncing progress indicator
class SyncingIndicator: UIView {
    
    // MARK: Vars
    private let style: SyncingIndicatorStyle
    private let label = UILabel()
    private let progressCircle: ProgressCircle
    private let circleSize: CGFloat = 14.0
    private var circleWidth: NSLayoutConstraint?

    var progress: CGFloat = 0.0 {
        didSet {
            progressCircle.setProgress(progress)
            updateTextLabel()
        }
    }

    var syncState: SyncState = .success {
        didSet {
            switch syncState {
            case .connecting:
                circleWidth?.constant = 0.0
                progressCircle.isHidden = true
                switch style {
                case .home:
                    self.text = S.SyncingView.connecting
                case .account:
                    self.text = ""
                }
                setNeedsLayout()
            case .syncing:
                progressCircle.isHidden = false
                circleWidth?.constant = circleSize
                self.text = S.SyncingView.syncing
                setNeedsLayout()
            case .success:
                self.text = ""
            }
        }
    }

    private var text: String = S.SyncingView.syncing {
        didSet {
            updateTextLabel()
        }
    }
    
    // MARK: Init
    
    init(style: SyncingIndicatorStyle) {
        self.style = style
        self.progressCircle = ProgressCircle(style: style)
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        addSubview(progressCircle)
        addSubview(label)
        setupConstraints()
        
        label.font = (style == .home) ? .customBold(size:12.0) : .customBody(size: 12.0)
        label.textColor = (style == .home) ? .transparentWhiteText : .lightText
        label.textAlignment = .right
        label.text = text
    }
    
    private func setupConstraints() {
        label.constrain([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor) ])
        let circlePadding = (SyncingHeaderView.height - circleSize)/2.0
        circleWidth = progressCircle.widthAnchor.constraint(equalToConstant: circleSize)
        progressCircle.constrain([
            progressCircle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0.0),
            progressCircle.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: C.padding[1]),
            progressCircle.topAnchor.constraint(equalTo: topAnchor, constant: circlePadding),
            progressCircle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -circlePadding),
            circleWidth])
    }

    private func updateTextLabel() {
        guard progress > 0.0 else {
            label.text = text
            return
        }

        let nf = NumberFormatter()
        nf.numberStyle = .percent
        nf.maximumFractionDigits = 0
        if text == S.SyncingView.syncing, let percent = nf.string(from: NSNumber(value: Float(progress))) {
            label.text = "\(text) \(percent)"
        } else {
            label.text = text
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ProgressCircle: UIView {
    private let circle = CAShapeLayer()
    private var hasPerformedLayout = false
    private let lineWidth: CGFloat = 2.0
    private let startBackgroundColor: UIColor
    private let style: SyncingIndicatorStyle

    init(style: SyncingIndicatorStyle) {
        self.style = style
        self.startBackgroundColor = (style == .home) ? .transparentWhiteText : UIColor.fromHex("828282")
        super.init(frame: .zero)
    }

    func setProgress(_ progress: CGFloat) {
        let start = CGFloat(3.0 * (.pi / 2.0))
        let end = start + CGFloat(2.0*(.pi) * progress)
        let path2 = UIBezierPath(arcCenter: bounds.center,
                                 radius: bounds.width/2.0,
                                 startAngle: start,
                                 endAngle: end,
                                 clockwise: true)
        circle.path = path2.cgPath
    }

    override func layoutSubviews() {
        guard !hasPerformedLayout else { hasPerformedLayout = true; return }
        clipsToBounds = false
        backgroundColor = .clear
        circle.fillColor = UIColor.clear.cgColor
        circle.strokeColor = startBackgroundColor.cgColor
        circle.lineWidth = 3.0
        circle.lineCap = CAShapeLayerLineCap.round
        layer.addSublayer(circle)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
