//
//  SyncProgressHeaderView.swift
//  loafwallet
//
//  Created by Kerry Washington on 12/21/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import UIKit

class SyncProgressHeaderView: UITableViewCell, Subscriber {

    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var noSendImageView: UIImageView!
    
    var progress: CGFloat = 0.0 {
        didSet {
            progressView.alpha = 1.0
            progressView.progress = Float(progress)
            progressView.setNeedsDisplay()
        }
    }
    var headerMessage: SyncState = .success {
       didSet {
            switch headerMessage {
            case .connecting: headerLabel.text = S.SyncingHeader.connecting
            case .syncing: headerLabel.text = S.SyncingHeader.syncing
            case .success:
                headerLabel.text = ""
            }
        headerLabel.setNeedsDisplay()
        }
    }
    var timestamp: UInt32 = 0 {
        didSet {
            timestampLabel.text = dateFormatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
            timestampLabel.setNeedsDisplay()
        }
    }
    var isRescanning: Bool = false {
        didSet {
            if isRescanning {
            headerLabel.text = S.SyncingHeader.rescanning
            timestampLabel.text =   ""
            progressView.alpha = 0.0
            noSendImageView.alpha = 0.0
            } else {
            headerLabel.text = ""
            timestampLabel.text =   ""
            progressView.alpha = 1.0
            noSendImageView.alpha = 0.0
            }
        }
    }
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return df
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 2) 
    } 
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
