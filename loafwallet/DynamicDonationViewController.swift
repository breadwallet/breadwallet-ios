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


class DynamicDonationViewController: UIViewController {

    @IBOutlet weak var dialogView: UIView!
    @IBOutlet weak var dialogTopAnchorConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var dialogTitle: UILabel!
    
    @IBOutlet weak var staticSendLabel: UILabel!
    @IBOutlet weak var staticToLabel: UILabel!
    @IBOutlet weak var processingTimeLabel: UILabel!
    
    @IBOutlet weak var sendAmountLabel: UILabel!
    @IBOutlet weak var donationAddressLabel: UILabel!
    
    @IBOutlet weak var staticAmountToDonateLabel: UILabel!
    @IBOutlet weak var staticNetworkFeeLabel: UILabel!
    @IBOutlet weak var staticTotalCostLabel: UILabel!
    @IBOutlet weak var amountToDonateLabel: UILabel!
    
 
    @IBOutlet weak var networkFeeLabel: UILabel!
    @IBOutlet weak var totalCostLabel: UILabel!
    @IBOutlet weak var buttonsView: UIView!
    @IBOutlet weak var containerView: UIView!
    
    @IBOutlet weak var firstColumnConstraint: NSLayoutConstraint!
    @IBOutlet weak var lastColumnConstraint: NSLayoutConstraint!
    @IBOutlet weak var accountPickerView: UIPickerView!
    
    
    var cancelButton = ShadowButton(title: S.Button.cancel, type: .secondary)
    var sendButton = ShadowButton(title: S.Confirmation.send, type: .flatLitecoinBlue, image: (LAContext.biometricType() == .face ? #imageLiteral(resourceName: "FaceId") : #imageLiteral(resourceName: "TouchId")))
    
    var successCallback: (() -> Void)?
    var cancelCallback: (() -> Void)?
    
    var store: Store?
    var feeType: Fee?
//    var feeAmount: Satoshis?
    var selectedRate: Rate?
    var minimumFractionDigits: Int = 2
    var isUsingBiometrics: Bool = false
    var balance: UInt64 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        configureDataAndFunction()
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
        staticSendLabel.text = S.Confirmation.send
        staticAmountToDonateLabel.text = S.Confirmation.donateLabel
        staticToLabel.text = S.Confirmation.to
        staticNetworkFeeLabel.text = S.Confirmation.feeLabel
        staticTotalCostLabel.text = S.Confirmation.totalLabel
        donationAddressLabel.text = DonationAddress.firstLF
        staticToLabel.text = S.Confirmation.to
        
        var timeText = "2.5-5"
        if feeType == .economy {
            timeText = "5+"
        }
        processingTimeLabel.text = String(format: S.Confirmation.processingAndDonationTime, timeText)
 
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
        
        let keyboardVC = PinPadViewController(style: .clear, keyboardType: .decimalPad, maxDigits: store.state.maxDigits)
        self.addChildViewController(keyboardVC, layout: {
            containerView.addSubview(keyboardVC.view)
            keyboardVC.view.constrain([
                keyboardVC.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                keyboardVC.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                keyboardVC.view.heightAnchor.constraint(equalToConstant: containerView.frame.height) ])
        })
         
        
        keyboardVC.ouputDidUpdate = { [weak self] text in
             guard let myself = self else { return }
            myself.amountToDonateLabel.text = text
            myself.sendAmountLabel.text = text
            
           // store.state.isLtcSwapped
            
        }
        
        keyboardVC.didUpdateFrameWidth = { [weak self] frame in
        guard let myself = self else { return }
            myself.firstColumnConstraint.constant = frame.width
            myself.lastColumnConstraint.constant = frame.width
            myself.view.layoutIfNeeded()
        }
         
    }
    
    
    private func configureDataAndFunction() {
          
        cancelButton.tap = strongify(self) { myself in
          myself.cancelCallback?()
        }
        sendButton.tap = strongify(self) { myself in
          myself.successCallback?()
        }
          
        guard let store = store else {
          print("XXX store past Guard")
            return
        }
        
//        guard let balance = balance else {
//          print("XXX balance past Guard")
//            return
//        }
//
        guard let feeType = feeType else {
          print("XXX feeType past Guard")
            return
        }
        
//        guard let feeAmount = feeAmount else {
//          print("XXX feeAmount past Guard")
//            return
//        }
        guard let selectedRate = selectedRate else {
            
          print("XXX selectedRate past Guard")
            return
        }
        
        print("XXX past Guard")
//        isUsingBiometrics
//        let displayAmount = DisplayAmount(amount: amount, state: store.state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
//        let displayFee = DisplayAmount(amount: feeAmount, state: store.state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
//        let displayTotal = DisplayAmount(amount: amount + feeAmount, state: store.state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
//
//        networkFeeLabel.text = displayFee.description
//        totalCostLabel.text = displayTotal.description
       // amountLabel.text = displayAmount.combinedDescription
        //address.text = self.isDonation ? DonationAddress.firstLF : addressText
         
       
            
//        sendLabel.text = isDonation ? S.Confirmation.donateLabel :
//        S.Confirmation.amountLabel
//        send.text = displayAmount.description
//        feeLabel.text = S.Confirmation.feeLabel
//        fee.text = displayFee.description
//
//        totalLabel.text = S.Confirmation.totalLabel
//        total.text = displayTotal.description
        
  
        
    }
    
    @IBAction func reduceDonationAction(_ sender: Any) {
        
    }
    @IBAction func increaseDonationAction(_ sender: Any) {
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
        let title = LWDonationAddress.allValues[row]
        let label = UILabel()
        label.textAlignment = .center
        label.attributedText = NSAttributedString(string: title.rawValue, attributes: [NSAttributedString.Key.font : UIFont.barloweRegular(size: 17), NSAttributedString.Key.foregroundColor: UIColor.white])
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.donationAddressLabel.text = LWDonationAddress.allValues[row].address
    }
}
