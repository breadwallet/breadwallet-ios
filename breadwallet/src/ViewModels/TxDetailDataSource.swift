//
//  TxDetailDataSource.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxDetailDataSource: NSObject {
    
    // MARK: - Types
    
    enum Field: String {
        case amount
        case status
        case memo
        case timestamp
        case address
        case startingBalance
        case endingBalance
        case exchangeRate
        case blockHeight
        case transactionId
        
        var title: String {
            switch self {
            case .status:
                return S.TransactionDetails.statusHeader
            case .memo:
                return S.TransactionDetails.commentsHeader
            case .timestamp:
                return S.TransactionDetails.timestampHeader
            case .address:
                return S.TransactionDetails.addressHeader
            case .startingBalance:
                return S.TransactionDetails.startingBalanceHeader
            case .endingBalance:
                return S.TransactionDetails.endingBalanceHeader
            case .exchangeRate:
                return S.TransactionDetails.exchangeRateHeader
            case .blockHeight:
                return S.TransactionDetails.blockHeightLabel
            case .transactionId:
                return S.TransactionDetails.txHashHeader
                
            default:
                return ""
            }
        }
        
        var cellType: UITableViewCell.Type {
            switch self {
            case .amount:
                return TxAmountCell.self
            case .status:
                return TxStatusCell.self
            case .memo:
                return TxMemoCell.self
            case .address, .transactionId:
                return TxAddressCell.self
            default:
                return TxLabelCell.self
            }
        }
        
        func registerCell(forTableView tableView: UITableView) {
            tableView.register(cellType, forCellReuseIdentifier: self.rawValue)
        }
    }
    
    // MARK: - Vars
    
    fileprivate var fields: [Field]
    fileprivate let viewModel: TxDetailViewModel
    
    // MARK: - Init
    
    init(viewModel: TxDetailViewModel) {
        self.viewModel = viewModel
        
        // define visible rows and order
        fields = [
            .amount,
            .status,
            //.memo, optional
            .timestamp,
            .address,
            .startingBalance,
            .endingBalance,
            .exchangeRate,
            .blockHeight,
            .transactionId
        ]
        
        if viewModel.comment != nil {
            fields.insert(.memo, at: 2)
        }
    }
    
    func registerCells(forTableView tableView: UITableView) {
        fields.forEach { $0.registerCell(forTableView: tableView) }
    }
}

// MARK: -
extension TxDetailDataSource: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fields.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let field = fields[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: field.rawValue,
                                                 for: indexPath)
        
        if let rowCell = cell as? TxDetailRowCell {
            rowCell.title = field.title
        }

        switch field {
        case .amount:
            let amountCell = cell as! TxAmountCell
            amountCell.set(fiatAmount: viewModel.fiatAmount, tokenAmount: viewModel.amount)
            break
    
        case .status:
            let statusCell = cell as! TxStatusCell
            statusCell.set(txInfo: viewModel)
            
        case .memo:
            let memoCell = cell as! TxMemoCell
            memoCell.set(viewModel: viewModel)
            
        case .timestamp:
            let labelCell = cell as! TxLabelCell
            labelCell.value = viewModel.longTimestamp
            
        case .address:
            let addressCell = cell as! TxAddressCell
            addressCell.set(address: viewModel.displayAddress)
            
        case .startingBalance:
            let labelCell = cell as! TxLabelCell
            labelCell.value = viewModel.startingBalance
            
        case .endingBalance:
            let labelCell = cell as! TxLabelCell
            labelCell.value = viewModel.endingBalance
            
        case .exchangeRate:
            let labelCell = cell as! TxLabelCell
            labelCell.value = viewModel.exchangeRate
            
        case .blockHeight:
            let labelCell = cell as! TxLabelCell
            labelCell.value = viewModel.blockHeight
            
        case .transactionId:
            let addressCell = cell as! TxAddressCell
            addressCell.set(address: viewModel.transactionHash)
        }
        
        return cell
    }
    
}
