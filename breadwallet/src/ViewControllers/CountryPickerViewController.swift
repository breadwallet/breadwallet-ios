//
//  CountryPickerViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-10.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

private struct Country : Codable {
    let name: String
    let alpha3Code: String
}

class CountryPickerViewController : UIViewController, ModalPresentable {

    var parentView: UIView?
    private var countries: [Country] = []
    private let picker = UIPickerView()
    private let store: Store

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        if let contriesPath = Bundle.main.path(forResource: "countries", ofType: "plist") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: contriesPath))
                countries = try PropertyListDecoder().decode([Country].self, from: data)
            } catch let e {
                assert(false, e.localizedDescription)
            }
        }
        picker.delegate = self
        picker.dataSource = self
        view.addSubview(picker)
        picker.constrain(toSuperviewEdges: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let code = countries[picker.selectedRow(inComponent: 0)].alpha3Code
        if let crowdsale = store.state.walletState.crowdsale {
            let newCrowdsale = Crowdsale(startTime: crowdsale.startTime, endTime: crowdsale.endTime, minContribution: crowdsale.minContribution, maxContribution: crowdsale.maxContribution, contract: crowdsale.contract, rate: crowdsale.rate, verificationCountryCode: code, weiRaised: crowdsale.weiRaised, cap: crowdsale.cap)
            store.perform(action: WalletChange.set(store.state.walletState.mutate(crowdSale: newCrowdsale)))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension CountryPickerViewController : UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return countries.count
    }
}

extension CountryPickerViewController : UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(countries[row].name)"
    }

}

extension CountryPickerViewController : ModalDisplayable {
    var faqArticleId: String? {
        return nil
    }

    var modalTitle: String {
        return "Select Country"
    }
}
