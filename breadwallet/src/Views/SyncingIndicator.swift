//
//  SyncingIndicator.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-02-16.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

/// Small syncing progress indicator
class SyncingIndicator: UIView {
    
    enum Style {
        case home
        case account
    }
    
    // MARK: Vars
    private let style: Style
    private let label = UILabel(font: .customBold(size: 12.0), color: .transparentWhiteText)
    private let progressBar = ProgressBar()
    
    var progress: CGFloat = 0.0 {
        didSet {
            progressBar.setProgress(ratio: progress)
        }
    }
    
    var text: String = S.SyncingView.syncing {
        didSet {
            label.text = text
            progressBar.pulse()
        }
    }
    
    // MARK: Init
    
    init(style: Style) {
        self.style = style
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        addSubview(progressBar)
        addSubview(label)
        setupConstraints()
        
        label.font = (style == .home) ? .customBold(size: 12.0) : .customBody(size: 14.0)
        label.textAlignment = .right
        label.text = text
    }
    
    private func setupConstraints() {
        label.constrain([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        
        progressBar.constrain([
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressBar.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: C.padding[1]),
            progressBar.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1.0),
            progressBar.heightAnchor.constraint(equalToConstant: 4.0),
            progressBar.widthAnchor.constraint(equalToConstant: 34.0)
            ])
    }
    
    func pulse() {
        progressBar.pulse()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private class ProgressBar: UIView {
    private let progress: UIView
    private var progressWidth: NSLayoutConstraint!
    
    init(backgroundColor: UIColor = UIColor.white.withAlphaComponent(0.5),
         foregroundColor: UIColor = .white) {
        progress = UIView(color: foregroundColor)
        super.init(frame: .zero)
        self.backgroundColor = backgroundColor
        setup()
    }
    
    private func setup() {
        addSubview(progress)
        
        progressWidth = progress.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.0)
        progress.constrain([
            progress.leadingAnchor.constraint(equalTo: leadingAnchor),
            progress.topAnchor.constraint(equalTo: topAnchor),
            progress.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressWidth
            ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2.0
        layer.masksToBounds = true
        
        progress.layer.cornerRadius = layer.cornerRadius
        progress.layer.masksToBounds = true
    }
    
    /// Set progress ratio (0.0 to 1.0)
    func setProgress(ratio: CGFloat) {
        let ratio = max(0.0, min(ratio, 1.0))
        progressWidth.isActive = false
        progressWidth = progress.widthAnchor.constraint(equalTo: widthAnchor, multiplier: ratio)
        progressWidth.isActive = true
        
        UIView.animate(withDuration: 0.2) {
            self.progress.setNeedsLayout()
        }
    }
    
    /// pulse animation
    func pulse() {
        self.progress.layer.removeAllAnimations()
        self.progress.backgroundColor = .white
        
        guard !E.isScreenshots else { return } // looping animations cause UI tests to hang
        
        UIView.animate(withDuration: 1.0,
                       delay: 0.5,
                       options: [.repeat, .autoreverse],
                       animations: {
                        self.progress.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        }, completion: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
