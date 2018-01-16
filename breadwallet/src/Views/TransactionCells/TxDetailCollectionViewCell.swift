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

    func set(viewModel: TxDetailViewModel, store: Store) {
        dataSource = TxDetailDataSource(viewModel: viewModel, store: store)
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
        tableView.constrain([
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
    }

    private func setInitialData() {
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.allowsSelection = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let maskLayer = CAShapeLayer()
        maskLayer.path = UIBezierPath(roundedRect: bounds,
                                      byRoundingCorners: [.topLeft, .topRight],
                                      cornerRadii: CGSize(width: C.Sizes.roundedCornerRadius, height: C.Sizes.roundedCornerRadius)).cgPath
        layer.mask = maskLayer
    }
}
