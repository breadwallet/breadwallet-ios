//
//  WarningConfirmationViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 2/18/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation
import UIKit

class WarningConfirmationViewController: UIViewController {
  
  @IBOutlet weak var warningContentTextView: UITextView!
  @IBOutlet weak var confirmButton: UIButton!
  
  
  override func viewDidLoad() {
    self.title = "Paper Phrase Warning"
  }
  
}
