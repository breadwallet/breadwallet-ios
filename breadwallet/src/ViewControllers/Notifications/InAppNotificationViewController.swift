//
//  InAppNotificationViewController.swift
//  breadwallet
//
//  Created by rrrrray-BRD-mac on 2019-06-04.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import UIKit

class InAppNotificationViewController: UIViewController, Trackable {

    private let notification: BRDMessage
    private var image: UIImage?
    
    private let titleLabel = UILabel.wrapping(font: Theme.h2Title, color: Theme.primaryText)
    private let bodyLabel = UILabel.wrapping(font: Theme.body1, color: Theme.secondaryText)
    private let imageView = UIImageView()
    private let ctaButton = BRDButton(title: "", type: .primary)
    
    private let imageSizePercent: CGFloat = 0.74
    private let contentTopMarginPercent: CGFloat = 0.1
    private let textMarginPercent: CGFloat = 0.14
    
    private var imageTopConstraint: CGFloat = 52
    private var imageSize: CGFloat = 280
    private var textLeftRightMargin: CGFloat = 54
    
    // MARK: - initialization
    
    init(_ notification: BRDMessage, image: UIImage?) {
        self.notification = notification
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
   
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
        
    // MARK: - view lifecycle
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logEvent(.appeared)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = Theme.primaryBackground
        
        calculateMarginsAndSizes()
        addCloseButton()
        setUpAppearance()
        addSubviews()
        addConstraints()
    }
    
    // MARK: - misc/setup
    
    @objc private func onCloseButton() {
        dismiss(animated: true, completion: { [weak self] in
            guard let `self` = self else { return }
            self.logEvent(.dismissed)
        })
    }
    
    private func addCloseButton() {
        let close = UIBarButtonItem(image: UIImage(named: "CloseModern"),
                                    style: .plain,
                                    target: self,
                                    action: #selector(onCloseButton))
        close.tintColor = .white
        navigationItem.rightBarButtonItem = close
    }
    
    private func calculateMarginsAndSizes() {
        let screenHeight = UIScreen.main.bounds.height
        let screenWidth = UIScreen.main.bounds.width
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let contentTop = (screenHeight * contentTopMarginPercent) - statusBarHeight
        
        imageTopConstraint = contentTop
        imageSize = screenWidth * imageSizePercent
        textLeftRightMargin = screenWidth * textMarginPercent
    }
    
    private func loadImage() {
        if let preloadedImage = self.image {
            imageView.image = preloadedImage
        } else if let urlString = notification.imageUrl, !urlString.isEmpty {
            UIImage.fetchAsync(from: urlString) { [weak self] (image) in
                guard let `self` = self else { return }
                if let image = image {
                    self.imageView.image = image
                }
            }
        }
    }
    
    private func setUpAppearance() {
        
        //
        // image view
        //
        
        imageView.contentMode = .center
        imageView.backgroundColor = Theme.secondaryBackground
        imageView.clipsToBounds = true
        loadImage()
        
        //
        // text fields
        //
        
        titleLabel.textAlignment = .center
        bodyLabel.textAlignment = .center
        
        if let title = notification.title {
            titleLabel.text = title
        }

        if let body = notification.body {
            bodyLabel.text = body
        }
        
        //
        // CTA (call-to-action) button
        //
        
        if let cta = notification.cta, !cta.isEmpty {
            ctaButton.title = cta
            
            ctaButton.tap = { [weak self] in
                guard let `self` = self else { return }
                
                self.dismiss(animated: true, completion: {
                    self.logEvent(.notificationCTAButton)
                    
                    if let ctaUrl = self.notification.ctaUrl, !ctaUrl.isEmpty, let url = URL(string: ctaUrl) {
                        // The UIApplication extension will ensure we handle the url correctly, including deep links.
                        UIApplication.shared.open(url)
                    }
                })
            }

        } else {
            ctaButton.isHidden = true
        }
    }
    
    private func addSubviews() {
        view.addSubview(imageView)
        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(ctaButton)
    }
    
    private func addConstraints() {
        
        imageView.constrain([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: imageTopConstraint),
            imageView.widthAnchor.constraint(equalToConstant: imageSize),
            imageView.heightAnchor.constraint(equalToConstant: imageSize),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])
    
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 24),
            titleLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: textLeftRightMargin),
            titleLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -textLeftRightMargin)
            ])
        
        bodyLabel.constrain([
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: C.padding[2]),
            bodyLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: textLeftRightMargin),
            bodyLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -textLeftRightMargin)
            ])
        
        ctaButton.constrain([
            ctaButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: C.padding[2]),
            ctaButton.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -C.padding[2]),
            ctaButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -C.padding[2]),
            ctaButton.heightAnchor.constraint(equalToConstant: C.Sizes.buttonHeight)
        ])
    }
    
    // MARK: - event logging
    
    private func logEvent(_ event: Event) {
        let name = makeEventName([EventContext.inAppNotifications.name, Screen.inAppNotification.name, event.name])
        saveEvent(name, attributes: [ BRDMessage.Keys.id.rawValue: notification.id ?? "",
                                      BRDMessage.Keys.message_id.rawValue: notification.messageId ?? "",
                                      BRDMessage.Keys.cta_url.rawValue: notification.ctaUrl ?? ""])
    }
}
