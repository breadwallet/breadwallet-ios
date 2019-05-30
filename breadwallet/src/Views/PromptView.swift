//
//  PromptView.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-02-07.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import UIKit

/**
 *  A view that is displayed at the top of a screen such as the home screen, typically
 *  alerting the user of some action that needs to be performed, such as adding a device
 *  passcode or writing down the paper key.
 */
class PromptView: UIView {
    
    init(prompt: Prompt) {
        self.prompt = prompt
        super.init(frame: .zero)
        setup()
    }
    
    let dismissButton = UIButton(type: .custom)
    let continueButton = UIButton(type: .custom)
    let prompt: Prompt
    
    let imageView = UIImageView()
    let title = UILabel(font: Theme.body1, color: Theme.primaryText)
    let body = UILabel.wrapping(font: Theme.body2, color: Theme.secondaryText)
    let container = UIView()
    
    private let imageViewSize: CGFloat = 32.0
    
    var type: PromptType {
        return self.prompt.type
    }
    
    var shouldHandleTap: Bool {
        return false
    }
    
    var shouldAddContinueButton: Bool {
        return true
    }
    
    func setup() {
        addSubviews()
        setupConstraints()
        setupStyle()
        
        title.numberOfLines = 0
        
        title.text = prompt.title
        body.text = prompt.body
    }
    
    var containerBackgroundColor: UIColor {
        return .whiteBackground
    }
    
    func addSubviews() {
        addSubview(container)
        container.addSubview(imageView)
        container.addSubview(title)
        container.addSubview(body)
        container.addSubview(dismissButton)
        if shouldAddContinueButton {
            container.addSubview(continueButton)
        }
    }
    
    func setupConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1],
                                                           left: C.padding[2],
                                                           bottom: -C.padding[1],
                                                           right: -C.padding[2]))
        
        imageView.constrain([
            imageView.heightAnchor.constraint(equalToConstant: imageViewSize),
            imageView.widthAnchor.constraint(equalToConstant: imageViewSize),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20.0),
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 20.0)
            ])

        dismissButton.constrain([
            dismissButton.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2]),
            dismissButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            dismissButton.heightAnchor.constraint(equalToConstant: 24.0),
            dismissButton.widthAnchor.constraint(equalToConstant: 24.0)
            ])

        title.constrain([
            title.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 20.0),
            title.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: 12.0),
            title.centerYAnchor.constraint(equalTo: dismissButton.centerYAnchor)
            ])

        body.constrain([
            body.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: C.padding[1]),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2])
            ])

        if shouldAddContinueButton {
            continueButton.constrain([
                continueButton.heightAnchor.constraint(equalToConstant: 48),
                continueButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: (C.padding[1] / 2)),
                continueButton.leadingAnchor.constraint(equalTo: body.leadingAnchor),
                continueButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12.0)
                ])
        }
    }
    
    func styleDismissButton() {
        let normalImg = UIImage(named: "CloseModern")?.tinted(with: Theme.tertiaryText)
        let highlightedImg = UIImage(named: "CloseModern")?.tinted(with: Theme.tertiaryText.withAlphaComponent(0.5))
        
        dismissButton.setImage(normalImg, for: .normal)
        dismissButton.setImage(highlightedImg, for: .highlighted)
    }
    
    func styleContinueButton() {
        continueButton.setTitleColor(Theme.accent, for: .normal)
        continueButton.setTitleColor(Theme.accent.withAlphaComponent(0.5), for: .disabled)
        continueButton.setTitleColor(Theme.accentHighlighted, for: .highlighted)
        continueButton.titleLabel?.font = Theme.primaryButton
        
        continueButton.setTitle(S.Button.continueAction, for: .normal)
    }
    
    private func setupStyle() {
        styleDismissButton()
        styleContinueButton()
        
        imageView.backgroundColor = Theme.tertiaryBackground
        imageView.layer.cornerRadius = imageViewSize / 2.0
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ExclamationStandalone")
        
        container.backgroundColor = Theme.secondaryBackground
        container.layer.cornerRadius = 4.0
        container.layer.shadowRadius = 4.0
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        container.layer.borderColor = UIColor.black.withAlphaComponent(0.12).cgColor
        container.layer.borderWidth = 1.0
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
