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
    
    let dismissButton = UIButton.rounded(title: S.Button.dismiss)
    let continueButton = UIButton.rounded(title: S.Button.continueAction)
    let prompt: Prompt
    
    let title = UILabel(font: .customBold(size: 16.0), color: .darkGray)
    let body = UILabel.wrapping(font: .customBody(size: 14.0), color: .darkGray)
    let container = UIView()
    
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
        container.addSubview(title)
        container.addSubview(body)
        container.addSubview(dismissButton)
        if shouldAddContinueButton {
            container.addSubview(continueButton)
        }
    }
    
    func setupConstraints() {
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1],
                                                           left: 10.0,
                                                           bottom: -C.padding[1],
                                                           right: -10.0))
        title.constrain([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: C.padding[2])])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: C.padding[1])])
        dismissButton.constrain([
            dismissButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: C.padding[2]),
            dismissButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            dismissButton.heightAnchor.constraint(equalToConstant: 44.0),
            dismissButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2])])
        
        if shouldAddContinueButton {
            continueButton.constrain([
                continueButton.topAnchor.constraint(equalTo: dismissButton.topAnchor),
                continueButton.leadingAnchor.constraint(equalTo: dismissButton.trailingAnchor, constant: C.padding[1]),
                continueButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
                continueButton.widthAnchor.constraint(equalTo: dismissButton.widthAnchor),
                continueButton.bottomAnchor.constraint(equalTo: dismissButton.bottomAnchor)])
        }
    }
    
    func styleDismissButton() {
        dismissButton.backgroundColor = .lightGray
        dismissButton.setTitleColor(.white, for: .normal)
    }
    
    func styleContinueButton() {
        continueButton.backgroundColor = .statusIndicatorActive
        continueButton.setTitleColor(.white, for: .normal)
    }
    
    private func setupStyle() {
        styleDismissButton()
        styleContinueButton()
        
        container.backgroundColor = containerBackgroundColor
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
