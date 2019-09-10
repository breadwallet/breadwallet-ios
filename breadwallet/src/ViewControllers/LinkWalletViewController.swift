//
//  LinkWalletViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-23.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

private let circleRadius: CGFloat = 40.0

class LinkWalletViewController: UIViewController {

    private let body = UIStackView()
    private let footer = UIStackView()
    private let buttonStack = UIStackView()
    private let footerBackground = UIView(color: .darkerBackground)
    private let bodyBackground = UIView(color: .darkerBackground)
    private let approve = BRDButton(title: S.LinkWallet.approve, type: .primary)
    private let decline = BRDButton(title: S.LinkWallet.decline, type: .secondary)
    private let logo = UIImageView(image: #imageLiteral(resourceName: "LogoCutout").withRenderingMode(.alwaysTemplate))
    private let logoBackground = MotionGradientView()
    private let logoFooter = UILabel(font: .customBold(size: 20.0), color: UIColor.fromHex("FAA43A"))
    private let titleLabel = UILabel(font: .customBody(size: 14.0), color: .white)
    private let note1 = UILabel.wrapping(font: .customBody(size: 14.0), color: .newWhite)
    private let note2 = UILabel(font: .customBold(size: 18.0), color: .white)
    private let note3 = UILabel.wrapping(font: .customBody(size: 14.0), color: .newWhite)
    private let info1 = UILabel(font: .customBold(size: 14.0), color: .white)
    private let info2 = UILabel.wrapping(font: .customBody(size: 14.0), color: .white)
    private let scrollView = UIScrollView()
    private let header = UIStackView()
    private var animator: UIViewPropertyAnimator?
    private let statusView = UIView()
    private let errorMessage = UILabel.wrapping(font: .customBody(size: 15.0), color: .white)
    private let circle = LinkStatusCircle(colour: .white)
    
    private let pairingRequest: WalletPairingRequest
    private let serviceDefinition: ServiceDefinition

    init(pairingRequest: WalletPairingRequest, serviceDefinition: ServiceDefinition) {
        self.pairingRequest = pairingRequest
        self.serviceDefinition = serviceDefinition
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviews()
        addConstraints()
        setInitialData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if pairingRequest.returnToURL != nil {
            Store.trigger(name: .registerForPushNotificationToken)
        }
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(scrollView)
        scrollView.addSubview(body)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(logoBackground)
        header.addArrangedSubview(logoFooter)
        header.addArrangedSubview(note1)
        header.addArrangedSubview(info1)
        body.addSubview(bodyBackground)
        body.addArrangedSubview(note2)
        body.addArrangedSubview(info2)
        logoBackground.addSubview(logo)
        view.addSubview(footer)
        footer.addSubview(footerBackground)
        footer.addArrangedSubview(note3)
        footer.addArrangedSubview(buttonStack)
        buttonStack.addArrangedSubview(decline)
        buttonStack.addArrangedSubview(approve)
    }

    private func addConstraints() {
        header.constrain([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.topAnchor.constraint(equalTo: safeTopAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        scrollView.alwaysBounceVertical = true
        scrollView.constrain([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footer.topAnchor)])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            body.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 30.0),
            body.widthAnchor.constraint(equalTo: scrollView.widthAnchor) ])
        logoBackground.constrain([
            logoBackground.heightAnchor.constraint(equalTo: logoBackground.widthAnchor, multiplier: logo.image!.size.height/logo.image!.size.width),
            logoBackground.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.36)])
        logo.constrain(toSuperviewEdges: nil)
        footer.constrain([
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.bottomAnchor.constraint(equalTo: safeBottomAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.heightAnchor.constraint(equalToConstant: 140.0)])
        footerBackground.constrain(toSuperviewEdges: nil)
        bodyBackground.constrain(toSuperviewEdges: UIEdgeInsets(top: 0, left: C.padding[2], bottom: 0, right: -C.padding[2]))
    }

    private func setInitialData() {
        view.backgroundColor = .darkBackground
        logo.tintColor = .darkBackground
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        setupStackViews()
        setButtonActions()
        setupLabels()
    }

    private func setupLabels() {
        titleLabel.text = S.LinkWallet.title.uppercased()
        note1.text = S.LinkWallet.domainTitle
        info1.text = serviceDefinition.domains.joined(separator: ", ")
        info1.numberOfLines = 0  // make sure the list of domains is not truncated
        note2.text = S.LinkWallet.permissionsTitle
        
        let capabilitiesList: [String] = serviceDefinition.capabilities.filter { !$0.description.isEmpty }.map {
            let scopes = $0.scopes.map { $0.description }.joined(separator: ", ")
            let format = Bundle.main.localizedString(forKey: $0.description, value: $0.description, table: nil)
            return "• " + String(format: format, scopes)
        }
        
        info2.text = capabilitiesList.joined(separator: "\n")
        note3.text = S.LinkWallet.disclaimer
        note1.textAlignment = .center
        note3.textAlignment = .center
        logoFooter.text = S.LinkWallet.logoFooter
    }

    private func setupStackViews() {
        header.axis = .vertical
        header.alignment = .center
        header.spacing = C.padding[3]
        header.layoutMargins = UIEdgeInsets(top: C.padding[2], left: C.padding[6], bottom: C.padding[1], right: C.padding[6])
        header.isLayoutMarginsRelativeArrangement = true

        header.setCustomSpacing(C.padding[1], after: logoBackground)
        header.setCustomSpacing(C.padding[1], after: note1)

        body.axis = .vertical
        body.alignment = .center
        body.spacing = C.padding[1]
        body.layoutMargins = UIEdgeInsets(top: C.padding[2], left: C.padding[3], bottom: C.padding[2], right: C.padding[3])
        body.isLayoutMarginsRelativeArrangement = true

        buttonStack.distribution = .fillEqually
        buttonStack.axis = .horizontal
        buttonStack.alignment = .fill
        buttonStack.spacing = C.padding[1]
        buttonStack.layoutMargins = UIEdgeInsets(top: C.padding[1], left: C.padding[1], bottom: C.padding[1], right: C.padding[1])
        buttonStack.isLayoutMarginsRelativeArrangement = true

        footer.distribution = .fillEqually
        footer.axis = .vertical
        footer.alignment = .fill
        footer.spacing = C.padding[1]
        footer.layoutMargins = UIEdgeInsets(top: C.padding[1], left: C.padding[1], bottom: C.padding[1], right: C.padding[1])
        footer.isLayoutMarginsRelativeArrangement = true
    }

    private func setButtonActions() {
        approve.tap = { [unowned self] in
            self.showStatusView()
            Store.trigger(name: .linkWallet(self.pairingRequest, true, { result in
                switch result {
                case .success:
                    self.showSuccess()
                case .error(let message):
                    self.showFailure(message: message)
                }
            }))
        }

        decline.tap = { [unowned self] in
            Store.trigger(name: .linkWallet(self.pairingRequest, false, { _ in
                self.stopAnimators()
                self.dismiss(animated: true, completion: nil)
            }))
        }
    }

    private func showStatusView() {
        UIView.animate(withDuration: C.animationDuration, animations: {
            self.header.alpha = 0.0
            self.body.alpha = 0.0
            self.footer.alpha = 0.0
        }, completion: { _ in
            self.header.isHidden = true
            self.body.isHidden = true
            self.footer.isHidden = true
            self.addStatusView()
        })
    }

    private func addStatusView() {
        view.addSubview(statusView)
        statusView.constrain([
            statusView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusView.heightAnchor.constraint(equalToConstant: 200.0),
            statusView.widthAnchor.constraint(equalToConstant: 200.0) ])
        statusView.addSubview(circle)
        circle.constrain([
            circle.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            circle.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
            circle.heightAnchor.constraint(equalToConstant: circleRadius*2.0),
            circle.widthAnchor.constraint(equalToConstant: circleRadius*2.0) ])
        DispatchQueue.main.async {
            self.circle.drawCircleWithRepeat()
        }
    }

    private func showSuccess() {
        DispatchQueue.main.async {
            self.circle.drawCheckBox()
            self.dismissAfterDelay {
                if self.pairingRequest.returnToURL == nil {
                    Store.trigger(name: .registerForPushNotificationToken)
                }
            }
        }
    }

    private func showFailure(message: String) {
        statusView.subviews.forEach {
            $0.removeFromSuperview()
        }
        statusView.addSubview(errorMessage)
        errorMessage.text = message
        errorMessage.constrain(toSuperviewEdges: nil)
        dismissAfterDelay()
    }

    private func dismissAfterDelay(completion: (() -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: {
            self.stopAnimators()
            self.dismiss(animated: true, completion: completion)
        })
    }

    private func stopAnimators() {
        animator?.stopAnimation(true)
        animator?.finishAnimation(at: .current)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LinkWalletViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = scrollView.contentOffset.y
        guard yOffset > 0  else {
            animator?.fractionComplete = 0.0
            return
        }
        let full: CGFloat = 40.0
        let progress = min(yOffset/full, 1.0)
        addAnimator()
        animator?.fractionComplete = progress
    }

    private func addAnimator() {
        guard animator == nil else { return }
        animator = UIViewPropertyAnimator(duration: 2, curve: .easeInOut) {
            [self.titleLabel, self.note1, self.info1, self.logoFooter].forEach { view in
                view.alpha = 0.0
                view.isHidden = true
            }
        }
    }
}
