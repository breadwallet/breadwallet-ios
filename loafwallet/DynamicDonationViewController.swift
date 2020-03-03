//
//  DynamicDonationViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 2/18/20.
//  Copyright © 2020 Litecoin Foundation. All rights reserved.
//

import Foundation
import UIKit
import LocalAuthentication
import FirebaseAnalytics


class DynamicDonationViewController: UIViewController, Subscriber {

    @IBOutlet weak var dialogView: UIView!
    @IBOutlet weak var dialogTitle: UILabel!
    
    @IBOutlet weak var staticSendLabel: UILabel!
    @IBOutlet weak var processingTimeLabel: UILabel!
    
    @IBOutlet weak var sendAmountLabel: UILabel!
    @IBOutlet weak var donationAddressLabel: UILabel!
    
    @IBOutlet weak var staticAmountToDonateLabel: UILabel!
    @IBOutlet weak var staticNetworkFeeLabel: UILabel!
    @IBOutlet weak var staticTotalCostLabel: UILabel!
     
    @IBOutlet weak var networkFeeLabel: UILabel!
    @IBOutlet weak var totalCostLabel: UILabel!
    @IBOutlet weak var buttonsView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var accountPickerView: UIPickerView!
    @IBOutlet weak var donationSlider: UISlider!
    @IBOutlet weak var decreaseDonationButton: UIButton!
    @IBOutlet weak var increaseDonationButton: UIButton!
    @IBOutlet weak var donationValueLabel: UILabel!
    
    
    var cancelButton = ShadowButton(title: S.Button.cancel, type: .secondary)
    var donateButton = ShadowButton(title: S.Donate.word, type: .flatLitecoinBlue, image: (LAContext.biometricType() == .face ? #imageLiteral(resourceName: "FaceId") : #imageLiteral(resourceName: "TouchId")))

    var successCallback: (() -> Void)?
    var cancelCallback: (() -> Void)?
    
    var store: Store?
    var feeType: FeeType?
    var senderClass: Sender?
    var selectedRate: Rate?
    var minimumFractionDigits: Int = 2
    var isUsingBiometrics: Bool = false
    var balance: UInt64 = 0
    var finalDonationAmount = Satoshis(rawValue: kDonationAmount)
    var finalDonationAddress = LWDonationAddress.litwalletHardware.address
    var finalDonationMemo = LWDonationAddress.litwalletHardware.rawValue

    let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    let impactFeedbackGenerator: (
        light: UIImpactFeedbackGenerator,
        heavy: UIImpactFeedbackGenerator) = (
            UIImpactFeedbackGenerator(style: .light),
            UIImpactFeedbackGenerator(style: .heavy)
    )
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        configureDataAndFunction()
    }
    
    private func configureViews() {
        
        selectionFeedbackGenerator.prepare()
        impactFeedbackGenerator.light.prepare()
        impactFeedbackGenerator.heavy.prepare()
        dialogView.layer.cornerRadius = 6.0
        dialogView.layer.masksToBounds = true
        
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurEffectView)
        view.sendSubview(toBack: blurEffectView)
        
        dialogTitle.text = S.Donate.titleConfirmation
        staticSendLabel.text = S.Confirmation.staticAddressLabel.capitalizingFirstLetter()
        staticAmountToDonateLabel.text = S.Confirmation.donateLabel
        staticNetworkFeeLabel.text = S.Confirmation.feeLabel
        staticTotalCostLabel.text = S.Confirmation.totalLabel
        donationAddressLabel.text = LWDonationAddress.litwalletHardware.address
  
        processingTimeLabel.text = String(format: S.Confirmation.processingAndDonationTime, "2.5-5")
        
        donationSlider.setValue(Float(kDonationAmount/balance), animated: true)
        donationSlider.addTarget(self, action: #selector(sliderDidChange), for: .valueChanged)
        donationSlider.minimumValue = Float(Double(kDonationAmount)/Double(balance))
        donationSlider.maximumValue = 1.0
          
        let amount = Satoshis(rawValue: UInt64(kDonationAmount))
        updateDonationLabels(donationAmount: amount)
        setupButtonLayouts()
    }
    
    private func setupButtonLayouts() {
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        donateButton.translatesAutoresizingMaskIntoConstraints = false
        buttonsView.addSubview(cancelButton)
        buttonsView.addSubview(donateButton)
        
        let viewsDictionary = ["cancelButton": cancelButton, "donateButton": donateButton]
        var viewConstraints = [NSLayoutConstraint]()
    
        let constraintsHorizontal = NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[cancelButton(170)]-8-[donateButton(170)]-10-|", options: [], metrics: nil, views: viewsDictionary)
        viewConstraints += constraintsHorizontal
        
        let cancelConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-[cancelButton]-|", options: [], metrics: nil, views: viewsDictionary)
        viewConstraints += cancelConstraintVertical
        
        let sendConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-[donateButton]-|", options: [], metrics: nil, views: viewsDictionary)
        
        viewConstraints += sendConstraintVertical
        NSLayoutConstraint.activate(viewConstraints)
    }
    
    private func configureDataAndFunction() {
          
        cancelButton.tap = strongify(self) { myself in
          myself.cancelCallback?()
          LWAnalytics.logEventWithParameters(itemName: ._20200225_DCD)
        }
        donateButton.tap = strongify(self) { myself in
          myself.successCallback?()
        }
         
        guard let store = store else {
            NSLog("ERROR: Store not initialized")
            return
        }
        
        store.subscribe(self, selector: { $0.walletState.balance != $1.walletState.balance },
                        callback: {
                            if let balance = $0.walletState.balance {
                                self.balance = balance
                            }
        })
    }
    
    private func maxAmountLessFees() -> Float {
        var adjustedBalance = Float(Double(balance))
        if let sender = senderClass {
            let maxFee = sender.feeForTx(amount: balance)
            adjustedBalance = Float(Double(balance) - Double(maxFee))
        }
        return adjustedBalance
    }
    
    private func updateDonationLabels(donationAmount: Satoshis) {
        
        guard let sender = senderClass else {
            NSLog("ERROR: Sender not initialized")
            return
        }
        guard let state = store?.state else {
            NSLog("ERROR: State not initialized")
            return
        }
        
        self.finalDonationAmount = donationAmount
        sendAmountLabel.text = DisplayAmount(amount: donationAmount, state: state, selectedRate: state.currentRate, minimumFractionDigits: minimumFractionDigits).combinedDescription
        let feeAmount = sender.feeForTx(amount: donationAmount.rawValue)
        networkFeeLabel.text = DisplayAmount(amount:Satoshis(rawValue: feeAmount), state: state, selectedRate: state.currentRate, minimumFractionDigits: minimumFractionDigits).combinedDescription
        totalCostLabel.text = DisplayAmount(amount: donationAmount + Satoshis(rawValue: feeAmount), state: state, selectedRate: state.currentRate, minimumFractionDigits: minimumFractionDigits).combinedDescription
        donationValueLabel.text = totalCostLabel.text
    }
 
    @objc func sliderDidChange() {
        let newDonationValue = donationSlider.value*maxAmountLessFees()
        updateDonationLabels(donationAmount: Satoshis(rawValue: UInt64(newDonationValue)))
        selectionFeedbackGenerator.selectionChanged()
    }
    
    @IBAction func reduceDonationAction(_ sender: Any) {
        impactFeedbackGenerator.light.impactOccurred()

          if donationSlider.value >= Float(kDonationAmount/balance) {
            let newValue = donationSlider.value - Float(Double(1000000)/Double(balance))
            if newValue >= donationSlider.minimumValue {
                donationSlider.setValue(newValue, animated: true)
                let newDonationValue = donationSlider.value*maxAmountLessFees()
                updateDonationLabels(donationAmount: Satoshis(rawValue: UInt64(newDonationValue)))
            }
        }
    }
    
    @IBAction func increaseDonationAction(_ sender: Any) {
        impactFeedbackGenerator.heavy.impactOccurred()

            let newValue = donationSlider.value + Float( Double(1000000)/Double(balance))
            if newValue <= 1.0 {
                donationSlider.setValue(newValue, animated: true)
                let newDonationValue = donationSlider.value*maxAmountLessFees()
                updateDonationLabels(donationAmount: Satoshis(rawValue: UInt64(newDonationValue)))
            }
    }
}

extension DynamicDonationViewController: UIPickerViewDataSource, UIPickerViewDelegate {
   
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return LWDonationAddress.allValues.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let title = S.Donate.toThe + " " + LWDonationAddress.allValues[row].rawValue
        let label = UILabel()
        label.textAlignment = .center
        label.attributedText = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font : UIFont.barloweRegular(size: 17), NSAttributedString.Key.foregroundColor: UIColor.black])
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.donationAddressLabel.text = LWDonationAddress.allValues[row].address
        self.finalDonationAddress = LWDonationAddress.allValues[row].address
        self.finalDonationMemo = LWDonationAddress.allValues[row].rawValue
    }
}
