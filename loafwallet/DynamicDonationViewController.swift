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
    var sender: Sender?
    var walletManager: WalletManager?
    var selectedRate: Rate?
    var minimumFractionDigits: Int = 2
    var isUsingBiometrics: Bool = false
    var balance: UInt64 = 0
    var donationAmount = kDonationAmount
    var initialDonation = kDonationAmountInDouble//Satoshis(rawValue: UInt64(kDonationAmountInDouble))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        configureDataAndFunction()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let store = store else {return}
        
        guard let fiatSymbol = store.state.currentRate?.currencySymbol else { return }
        let suffix = String(format: " %@", store.state.isLtcSwapped ? "(\(fiatSymbol))":"(Ł)")
         
        self.amountToDonateLabel.text = String(describing: donationAmount) + suffix
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
        donationAddressLabel.text = LWDonationAddress.litwalletHardware.address
        staticToLabel.text = S.Confirmation.to
        // LWAnalytics.logEventWithParameters(itemName:._20191105_VSC)

        var timeText = "2.5-5"
        if feeType == .economy {
            timeText = "5+"
        }
        processingTimeLabel.text = String(format: S.Confirmation.processingAndDonationTime, timeText)
 
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        buttonsView.addSubview(cancelButton)
        buttonsView.addSubview(sendButton)
        
     //   pickerHeaderLabel.text = "Choose:"//S.Donate.choose
        
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
            myself.totalCostLabel.text = String(myself.balance - UInt64(text)!)
            myself.walletManager.
        
            
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
        
        store.subscribe(self, selector: { $0.walletState.balance != $1.walletState.balance },
                        callback: {
                            if let balance = $0.walletState.balance {
                                self.balance = balance
                                //self.walletManager?.wallet?.feeForTxSize(<#T##size: Int##Int#>)
                            }
        })

        
           
 

        
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
//        guard let selectedRate = selectedRate else {
//            
//          print("XXX selectedRate past Guard")
//            return
//        }
        guard let sender = sender else {
           print("XXX feeType past Sender")
             return
         }
        
    //    let balance = sender.transaction.
        
         
        
        guard let fiatSymbol = store.state.currentRate?.currencySymbol else { return }
        let suffix = String(format: " %@", store.state.isLtcSwapped ? "(Ł)":"(\(fiatSymbol))")
         
        self.amountToDonateLabel.text = String(describing: kDonationAmount) + suffix
       
        self.sendAmountLabel.text = String(format: "Amount %@", store.state.isLtcSwapped ? "(Ł)":"(\(fiatSymbol))")
        self.networkFeeLabel.text = String(format: "Network %@", store.state.isLtcSwapped ? "(Ł)":"(\(fiatSymbol))")
        
//        isUsingBiometrics
//        let displayAmount = DisplayAmount(amount: amount, state: store.state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
//        let displayFee = DisplayAmount(amount: feeAmount, state: store.state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
//        let displayTotal = DisplayAmount(amount: amount + feeAmount, state: store.state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
//
//        networkFeeLabel.text = displayFee.description
//        totalCostLabel.text = displayTotal.description
       // amountLabel.text = displayAmount.combinedDescription
        //address.text = self.isDonation ? DonationAddress.firstLF : addressText
        
//        networkFeeLabel.text =  DisplayAmount(amount: feeAmount, state: store.state, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits)
//         DisplayAmount(amount: Satoshis(rawValue: feeType), state: store.state, selectedRate: rate, minimumFractionDigits: 0)
//       
            
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
        // amountToDonateLabel.text = String(describing: donationAmount -= 10000)
       
    }
    
    @IBAction func increaseDonationAction(_ sender: Any) {
       // amountToDonateLabel.text = String(describing: donationAmount += 10000)
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
