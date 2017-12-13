//
//  VerifyIdentityView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-09.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class VerifyIdentityView : UIView, Subscriber {

    var didTapVerify: ((RegistrationParams) -> Void)?
    var showError: ((String) -> Void)?
    private let title = UILabel(font: .customBold(size: 18.0))
    private let subheader = UILabel.wrapping(font: .customBody(size: 16.0))
    private let firstName = UITextField()
    private let lastName = UITextField()
    private let email = UITextField()
    private let country = ShadowButton(title: "Select Country", type: .secondary)
    private let verify = ShadowButton(title: "Verify", type: .primary)
    private let store: Store

    init(store: Store) {
        self.store = store
        super.init(frame: .zero)
        setupViews()
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        addSubview(title)
        addSubview(subheader)
        addSubview(firstName)
        addSubview(lastName)
        addSubview(email)
        addSubview(country)
        addSubview(verify)
    }

    private func addConstraints() {
        title.constrainTopCorners(sidePadding: C.padding[2], topPadding: C.padding[2])
        subheader.constrain([
            subheader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            subheader.topAnchor.constraint(equalTo: title.bottomAnchor, constant: C.padding[1]),
            subheader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]) ])
        firstName.constrain([
            firstName.leadingAnchor.constraint(equalTo: subheader.leadingAnchor),
            firstName.topAnchor.constraint(equalTo: subheader.bottomAnchor, constant: C.padding[1]),
            firstName.trailingAnchor.constraint(equalTo: subheader.trailingAnchor)])
        lastName.constrain([
            lastName.leadingAnchor.constraint(equalTo: subheader.leadingAnchor),
            lastName.topAnchor.constraint(equalTo: firstName.bottomAnchor, constant: C.padding[1]),
            lastName.trailingAnchor.constraint(equalTo: subheader.trailingAnchor)])
        email.constrain([
            email.leadingAnchor.constraint(equalTo: subheader.leadingAnchor),
            email.topAnchor.constraint(equalTo: lastName.bottomAnchor, constant: C.padding[1]),
            email.trailingAnchor.constraint(equalTo: subheader.trailingAnchor)])
        country.constrain([
            country.leadingAnchor.constraint(equalTo: subheader.leadingAnchor),
            country.topAnchor.constraint(equalTo: email.bottomAnchor, constant: C.padding[1]),
            country.trailingAnchor.constraint(equalTo: subheader.trailingAnchor)])
        verify.constrain([
            verify.topAnchor.constraint(equalTo: country.bottomAnchor, constant: C.padding[2]),
            verify.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            verify.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -C.padding[2])])
    }

    private func setInitialData() {
        title.textAlignment = .center
        title.text = "Verify Identity"
        subheader.text = "Identity verification is required for crowdsale participation"
        firstName.placeholder = "First Name"
        firstName.borderStyle = .roundedRect
        lastName.placeholder = "Last Name"
        lastName.borderStyle = .roundedRect
        email.placeholder = "Email"
        email.borderStyle = .roundedRect
        email.keyboardType = .emailAddress
        email.autocapitalizationType = .none
        verify.tap = strongify(self) { myself in
            guard let firstName = myself.firstName.text else { myself.showError?("No First Name"); return }
            guard let lastName = myself.lastName.text else { myself.showError?("No Last Name"); return }
            guard let email = myself.email.text else { myself.showError?("No Email"); return }
            guard let country = myself.store.state.walletState.crowdsale?.verificationCountryCode else {
                myself.showError?("Select a country"); return
            }
            guard let contractAddress = myself.store.state.walletState.crowdsale?.contract.address else { return }
            let params = RegistrationParams(first_name: firstName, last_name: lastName, email: email, redirect_uri: "http://google.ca", country: country, contract_address: contractAddress)
            myself.didTapVerify?(params)
        }

        country.tap = strongify(self) { myself in
            myself.store.perform(action: RootModalActions.Present(modal: .countryPicker))
        }
        store.subscribe(self, selector: { $0.walletState.crowdsale?.verificationCountryCode != $1.walletState.crowdsale?.verificationCountryCode }, callback: { state in
            if let code = state.walletState.crowdsale?.verificationCountryCode {
                self.country.title = "Country: \(code)"
            }
        })
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
