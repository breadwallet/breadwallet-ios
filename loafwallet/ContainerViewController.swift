//
//  ContainerViewController.swift
//  loafwallet
//
//  Created by Kerry Washington on 4/7/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation
import UIKit

class ContainerViewController: UIViewController {
  
  override func viewDidLoad() {
    
  }
}

extension ContainerViewController: ModalDisplayable {
  
  var faqArticleId: String? {
    return nil
  }
  
  var modalTitle: String {
    return ""
  }
}
