//
//  TxDetailCollectionViewCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxDetailCollectionViewCell : UICollectionViewCell {

    // MARK: - Private Vars
    
    private let header = ModalHeaderView(title: S.TransactionDetails.title, style: .dark)
    private var tableView = UITableView()
    private var dataSource: TxDetailDataSource!
    
    // MARK: - Public Vars
    
    var closeCallback: (() -> Void)? {
        didSet { header.closeCallback = closeCallback }
    }

    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    func set(info: TxDetailInfo) {
        dataSource = TxDetailDataSource(info: info)
        dataSource.registerCells(forTableView: tableView)
        tableView.dataSource = dataSource
        tableView.reloadData()
    }

    private func setup() {
        addSubViews()
        addConstraints()
        setInitialData()
    }

    private func addSubViews() {
        contentView.addSubview(header)
        contentView.addSubview(tableView)
    }

    private func addConstraints() {
        header.constrainTopCorners(height: C.Sizes.headerHeight)
        let tableHeight = (UIScreen.main.bounds.height - C.padding[1]) - C.Sizes.headerHeight
        tableView.pinTo(viewAbove: header, height: tableHeight)
    }

    private func setInitialData() {
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = .whiteTint
        tableView.rowHeight = UITableViewAutomaticDimension
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
