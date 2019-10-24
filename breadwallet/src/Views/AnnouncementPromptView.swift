//
//  AnnouncementPromptView.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-02-25.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

class AnnouncementPromptView: PromptView {

    private let announcement: Announcement
    private let footnoteLabel: UILabel = UILabel()
    
    override var containerBackgroundColor: UIColor {
        return .darkPromptBackground
    }

    init(prompt: AnnouncementBasedPrompt) {
        self.announcement = prompt.announcement
        super.init(prompt: prompt)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setup() {
        super.setup()
        
        title.textColor = .darkPromptTitleColor
        body.textColor = .darkPromptBodyColor
        
        imageView.contentMode = .scaleAspectFit
        if let imageName = prompt.imageName {
            imageView.image = UIImage(named: imageName)
        } else {
            imageView.isHidden = true
        }
        
        continueButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        continueButton.sizeToFit()
        
        if let actions = announcement.actions(for: .initialDisplay), !actions.isEmpty, let action = actions.first {
            continueButton.setTitle(action.titleText, for: .normal)
            
            if let url = action.url {
                continueButton.tap = {
                    Store.trigger(name: .openPlatformUrl(url))
                    DispatchQueue.main.async { [unowned self] in
                        if let handler = self.dismissButton.tap {
                            handler()
                        }
                    }
                }
            }
        }
        
        dismissButton.setTitle("", for: .normal)

        footnoteLabel.numberOfLines = 0
        footnoteLabel.textColor = body.textColor
        footnoteLabel.font = UIFont.customBody(size: 9)
        footnoteLabel.text = prompt.footnote
    }
    
    override var shouldHandleTap: Bool {
        // Return 'true' because we want to handle a tap on the Continue button.
        return true
    }
    
    override func styleDismissButton() {
        let closeButtonImage = UIImage(named: "Close-X-small")
        dismissButton.setImage(closeButtonImage, for: .normal)
        dismissButton.backgroundColor = .clear
        dismissButton.tintColor = .white
    }

    override func styleContinueButton() {
        continueButton.backgroundColor = .clear
        continueButton.setBackgroundImage(UIImage(), for: .disabled)
        continueButton.setBackgroundImage(UIImage.imageForColor(.submitButtonEnabledBlue), for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.layer.cornerRadius = 2
        continueButton.titleLabel?.font = UIFont.customMedium(size: 14)
    }

    override func addSubviews() {
        super.addSubviews()
        addSubview(imageView)
        addSubview(footnoteLabel)
    }
    
    override func setupConstraints() {
        let verticalMargin: CGFloat = 22
        let leftMargin: CGFloat = 22
        
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1],
                                                           left: 10.0,
                                                           bottom: -C.padding[1],
                                                           right: -10.0))
        
        dismissButton.constrain([
            dismissButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            dismissButton.rightAnchor.constraint(equalTo: container.rightAnchor, constant: -C.padding[1]),
            dismissButton.widthAnchor.constraint(equalToConstant: 24),
            dismissButton.heightAnchor.constraint(equalToConstant: 24)
            ])
        
        imageView.constrain([
            imageView.widthAnchor.constraint(equalToConstant: 34),
            imageView.heightAnchor.constraint(equalToConstant: 34),
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: verticalMargin),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leftMargin)
            ])
        
        title.constrain([
            title.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: C.padding[2]),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -34),
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 28)
            ])
        
        body.constrain([
            body.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: C.padding[1])])
        
        continueButton.constrain([
            continueButton.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 12),
            continueButton.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            continueButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        
        footnoteLabel.constrain([
            footnoteLabel.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: (C.padding[1] / 2)),
            footnoteLabel.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            footnoteLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -C.padding[2]),
            footnoteLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -(verticalMargin))
            ])
    }
    
}
