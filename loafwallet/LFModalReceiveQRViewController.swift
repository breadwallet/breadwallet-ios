//
//  LFModalReceiveQRViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 11/17/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//
 
import UIKit
  
class LFModalReceiveQRViewController: UIViewController {
    
    @IBOutlet weak var modalView: UIView!
    @IBOutlet weak var qrImageView: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var receiveModalTitleLabel: UILabel!
 
    var dismissQRModalAction: (() -> ())?

    @IBAction func didCancelAction(_ sender: Any) {
        dismissQRModalAction?()
    }
    
    override func viewWillAppear(_ animated: Bool) {

    }
      
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blurEffectView)
        view.sendSubview(toBack: blurEffectView)
         
        modalView.layer.cornerRadius = 15
        modalView.clipsToBounds = true
        
        addressLabel.text = ""
        receiveModalTitleLabel.text = ""
    }
}
