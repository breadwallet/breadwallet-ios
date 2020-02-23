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


class DynamicDonationViewController: UIViewController, Subscriber {

    @IBOutlet weak var dialogView: UIView!
    @IBOutlet weak var dialogTopAnchorConstraint: NSLayoutConstraint!
    
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
    @IBOutlet weak var donationValueLabel: UILabel!
    
    var cancelButton = ShadowButton(title: S.Button.cancel, type: .secondary)
    var sendButton = ShadowButton(title: S.Confirmation.send, type: .flatLitecoinBlue, image: (LAContext.biometricType() == .face ? #imageLiteral(resourceName: "FaceId") : #imageLiteral(resourceName: "TouchId")))
    
    var successCallback: (() -> Void)?
    var cancelCallback: (() -> Void)?
    
    var store: Store?
    var feeType: Fee?
    var senderClass: Sender?
    var selectedRate: Rate?
    var minimumFractionDigits: Int = 2
    var isUsingBiometrics: Bool = false
    var balance: UInt64 = 0
    var donationAmount = kDonationAmount
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        configureDataAndFunction()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    private func configureViews() {
        
        guard let store = self.store else {
            NSLog("ERROR: Store must not be nil")
            return
        }
        
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
 
        var timeText = "2.5-5"
        if feeType == .economy {
            timeText = "5+"
        }
        processingTimeLabel.text = String(format: S.Confirmation.processingAndDonationTime, timeText)
        
        donationSlider.setValue(Float(kDonationAmount/balance), animated: true)
        donationSlider.addTarget(self, action: #selector(sliderDidChange), for: .valueChanged)
        donationSlider.minimumValue = Float(Double(kDonationAmount)/Double(balance))
        donationSlider.maximumValue = 1.0
        
        donationValueLabel.text = String(format:"%5.5f",(Double(kDonationAmount) / Double(100000000))) + " Ł" + "\n\(selectedRate?.rate ?? 0.0)"
        let amount = Satoshis(rawValue: UInt64(kDonationAmount))
        updateDonationLabels(donationAmount: amount)
        setupButtonLayouts()
    }
   
    
    private func setupButtonLayouts() {
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        buttonsView.addSubview(cancelButton)
        buttonsView.addSubview(sendButton)
        
        let viewsDictionary = ["cancelButton": cancelButton, "sendButton": sendButton]
        var viewConstraints = [NSLayoutConstraint]()
    
        let constraintsHorizontal = NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[cancelButton(160)]-10-[sendButton(160)]-10-|", options: [], metrics: nil, views: viewsDictionary)
        viewConstraints += constraintsHorizontal
        
        let cancelConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-[cancelButton]-|", options: [], metrics: nil, views: viewsDictionary)
        viewConstraints += cancelConstraintVertical
        
        let sendConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-[sendButton]-|", options: [], metrics: nil, views: viewsDictionary)
        
        viewConstraints += sendConstraintVertical
        NSLayoutConstraint.activate(viewConstraints)
    }
    
    private func configureDataAndFunction() {
          
        cancelButton.tap = strongify(self) { myself in
          myself.cancelCallback?()
        }
        sendButton.tap = strongify(self) { myself in
          myself.successCallback?()
        }
         
        guard let store = store else {
          print("ERROR: Store not initialized")
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
        
        guard let sender = senderClass else {return}
        guard let state = store?.state else {return}
        
        sendAmountLabel.text = DisplayAmount(amount: donationAmount, state: state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits).description
        let feeAmount = sender.feeForTx(amount: donationAmount.rawValue)
        networkFeeLabel.text = DisplayAmount(amount:Satoshis(rawValue: feeAmount), state: state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits).description
        totalCostLabel.text = DisplayAmount(amount: donationAmount + Satoshis(rawValue: feeAmount), state: state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits).description
    }
 
    @objc func sliderDidChange() {
        let newDonationValue = donationSlider.value*maxAmountLessFees()
        updateDonationLabels(donationAmount: Satoshis(rawValue: UInt64(newDonationValue)))
        let newDonationFloatValue = donationSlider.value*Float(Double(balance))/Float(Double(100000000))
        donationValueLabel.text = String(format:"%5.5f",newDonationFloatValue) + " Ł"
    }
    
    @IBAction func reduceDonationAction(_ sender: Any) {
          if donationSlider.value >= Float(kDonationAmount/balance) {
            let newValue = donationSlider.value - Float(Double(1000000)/Double(balance))
            if newValue >= donationSlider.minimumValue {
                donationSlider.setValue(newValue, animated: true)
                let newDonationValue = donationSlider.value*maxAmountLessFees()
                updateDonationLabels(donationAmount: Satoshis(rawValue: UInt64(newDonationValue)))
                let newDonationFloatValue = donationSlider.value*Float(Double(balance))/Float(Double(100000000))
                donationValueLabel.text = String(format:"%5.5f",newDonationFloatValue) + " Ł"
            }
        }
    }
    
    @IBAction func increaseDonationAction(_ sender: Any) {
            let newValue = donationSlider.value + Float( Double(1000000)/Double(balance))
            if newValue <= 1.0 {
                donationSlider.setValue(newValue, animated: true)
                let newDonationValue = donationSlider.value*maxAmountLessFees()
                updateDonationLabels(donationAmount: Satoshis(rawValue: UInt64(newDonationValue)))
                let newDonationFloatValue = donationSlider.value*Float(Double(balance))/Float(Double(100000000))
                donationValueLabel.text = String(format:"%5.5f",newDonationFloatValue) + " Ł"
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
        label.shadowColor = .black
        label.shadowOffset = CGSize(width: 1, height: 1)
        label.attributedText = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font : UIFont.barloweRegular(size: 17), NSAttributedString.Key.foregroundColor: UIColor.white])
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.donationAddressLabel.text = LWDonationAddress.allValues[row].address
    }
}
