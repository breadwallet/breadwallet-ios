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


class DynamicDonationViewController: UIViewController, UITextFieldDelegate {
    
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

    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var networkFeeLabel: UILabel!
    @IBOutlet weak var totalCostLabel: UILabel!
    
    @IBOutlet weak var buttonsView: UIView!
    var cancelButton = ShadowButton(title: S.Button.cancel, type: .secondary)
    var sendButton = ShadowButton(title: S.Confirmation.send, type: .flatLitecoinBlue, image: (LAContext.biometricType() == .face ? #imageLiteral(resourceName: "FaceId") : #imageLiteral(resourceName: "TouchId")))
    
    var successCallback: (() -> Void)?
    var cancelCallback: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        configureData()
    }
    
    
    private func configureViews() {
        dialogView.layer.cornerRadius = 6.0
        dialogView.layer.masksToBounds = true
        
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurEffectView)
        view.sendSubview(toBack: blurEffectView)
        
        
        dialogTitle.text = S.Confirmation.title
        staticSendLabel.text = S.Confirmation.send
        staticAmountToDonateLabel.text = S.Confirmation.donateLabel
        staticToLabel.text = S.Confirmation.to
        staticNetworkFeeLabel.text = S.Confirmation.feeLabel
        staticTotalCostLabel.text = S.Confirmation.totalLabel
        processingTimeLabel.text = S.Confirmation.processingAndDonationTime
        donationAddressLabel.text = DonationAddress.firstLF
        
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        buttonsView.addSubview(cancelButton)
        buttonsView.addSubview(sendButton)
        
        let viewsDictionary = ["cancelButton": cancelButton, "sendButton": sendButton]
        var viewConstraints = [NSLayoutConstraint]()
    
        let constraintsHorizontal = NSLayoutConstraint.constraints(withVisualFormat: "H:|-20-[cancelButton(120)]-[sendButton(120)]-20-|", options: [], metrics: nil, views: viewsDictionary)
        viewConstraints += constraintsHorizontal
        
        let cancelConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-[cancelButton]-|", options: [], metrics: nil, views: viewsDictionary)

        viewConstraints += cancelConstraintVertical
        
        let sendConstraintVertical = NSLayoutConstraint.constraints(withVisualFormat: "V:|-[sendButton]-|", options: [], metrics: nil, views: viewsDictionary)

        viewConstraints += sendConstraintVertical
        
        NSLayoutConstraint.activate(viewConstraints)
        
        amountTextField.becomeFirstResponder()
    }
    
    
    private func configureData() {
         
 
        cancelButton.tap = strongify(self) { myself in
          myself.cancelCallback?()
        }
        sendButton.tap = strongify(self) { myself in
          myself.successCallback?()
        }
    }
     
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.sendAmountLabel.text = self.amountTextField.text
    }
    
}
