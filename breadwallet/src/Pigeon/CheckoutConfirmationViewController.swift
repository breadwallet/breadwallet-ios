
//
//  CheckoutConfirmationViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-31.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

class CheckoutConfirmationViewController : UIViewController {

    private let header = UIView(color: .darkerBackground)
    private let titleLabel = UILabel(font: .customBold(size: 18.0), color: .white)
    private let footer = UIStackView()
    private let body = UIStackView()
    private let footerBackground = UIView(color: .darkerBackground)
    private let buy = BRDButton(title: "Buy", type: .primary)
    private let cancel = BRDButton(title: "Cancel", type: .secondary)
    private let logo = UIImageView(image: #imageLiteral(resourceName: "CCCLogo"))
    private let coinName = UILabel(font: .customBody(size: 28.0), color: .white)
    private let amount = UILabel(font: .customBody(size: 16.0), color: .white)

    private let request: PigeonRequest

    init(request: PigeonRequest) {
        self.request = request
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(body)
        view.addSubview(footer)
        header.addSubview(titleLabel)
        footer.addSubview(footerBackground)
        body.addArrangedSubview(logo)
        body.addArrangedSubview(coinName)
        body.addArrangedSubview(amount)
        footer.addArrangedSubview(cancel)
        footer.addArrangedSubview(buy)
    }

    private func addConstraints() {
        header.constrainTopCorners(sidePadding: 0.0, topPadding: 0.0)
        header.constrain([
            header.heightAnchor.constraint(equalToConstant: 64.0)])
        titleLabel.constrain([
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor)])
        body.constrain([
            body.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            body.topAnchor.constraint(equalTo: header.bottomAnchor),
            body.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        logo.constrain([
            logo.heightAnchor.constraint(equalTo: logo.widthAnchor, multiplier: logo.image!.size.height/logo.image!.size.width),
            logo.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.34)])
        footer.constrain([
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.bottomAnchor.constraint(equalTo: safeBottomAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footer.heightAnchor.constraint(equalToConstant: 44.0 + C.padding[2])])
        footerBackground.constrain(toSuperviewEdges: nil)
    }

    private func setInitialData() {
        view.backgroundColor = .darkBackground
        setupStackViews()
        titleLabel.text = "Confirmation"
        coinName.text = "Container Crypto Coin"
        amount.text = "Send \(request.purchaseAmount.description) to purchase CCC"
        buy.tap = {
            self.dismiss(animated: true, completion: nil)
        }
        cancel.tap = {
            self.dismiss(animated: true, completion: nil)
        }
    }

    private func setupStackViews() {
        body.axis = .vertical
        body.alignment = .center
        body.spacing = C.padding[3]
        body.layoutMargins = UIEdgeInsets(top: C.padding[4], left: C.padding[1], bottom: C.padding[1], right: C.padding[1])
        body.isLayoutMarginsRelativeArrangement = true

        footer.distribution = .fillEqually
        footer.axis = .horizontal
        footer.alignment = .fill
        footer.spacing = C.padding[1]
        footer.layoutMargins = UIEdgeInsets(top: C.padding[1], left: C.padding[1], bottom: C.padding[1], right: C.padding[1])
        footer.isLayoutMarginsRelativeArrangement = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
