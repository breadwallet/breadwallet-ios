//
//  TxDetailViewController.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

private extension C {
    static let compactContainerHeight: CGFloat = 300.0
    static let expandedContainerHeight: CGFloat = 464.0
    static let detailsButtonHeight: CGFloat = 65.0
}

class TxDetailViewController: UIViewController, Subscriber {
    
    // MARK: - Private Vars
    
    private let container = UIView()
    private let header = ModalHeaderView(title: S.TransactionDetails.title, style: .transaction)
    private let footer = UIView()
    private let separator = UIView()
    private let detailsButton = UIButton(type: .custom)
    private let tableView = UITableView()
    
    private var containerHeightConstraint: NSLayoutConstraint!
    
    private let viewModel: TxDetailViewModel
    private var dataSource: TxDetailDataSource
    private var isExpanded: Bool = false
    
    // MARK: - Init
    
    init(transaction: Transaction) {
        viewModel = TxDetailViewModel(tx: transaction)
        dataSource = TxDetailDataSource(viewModel: viewModel)
        
        super.init(nibName: nil, bundle: nil)
        
        header.closeCallback = { [weak self] in
            if let delegate = self?.transitioningDelegate as? ModalTransitionDelegate {
                delegate.reset()
            }
            self?.dismiss(animated: true, completion: nil)
        }
        
        setup()
    }
    
    deinit {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    private func setup() {
        addSubViews()
        addConstraints()
        setInitialData()
    }
    
    private func addSubViews() {
        view.addSubview(container)
        container.addSubview(header)
        container.addSubview(tableView)
        container.addSubview(footer)
        container.addSubview(separator)
        footer.addSubview(detailsButton)
    }
    
    private func addConstraints() {
        container.constrain([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        
        containerHeightConstraint = container.heightAnchor.constraint(equalToConstant: C.compactContainerHeight)
        containerHeightConstraint.isActive = true
        
        header.constrainTopCorners(height: C.Sizes.headerHeight)
        tableView.constrain([
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        
        footer.constrainBottomCorners(height: C.detailsButtonHeight)
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            separator.topAnchor.constraint(equalTo: footer.topAnchor, constant: 1.0),
            separator.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])
        detailsButton.constrain(toSuperviewEdges: .zero)
    }
    
    private func setInitialData() {
        container.layer.cornerRadius = C.Sizes.roundedCornerRadius
        container.layer.masksToBounds = true
        
        footer.backgroundColor = .white
        separator.backgroundColor = .separatorGray
        detailsButton.setTitleColor(.blueButtonText, for: .normal)
        detailsButton.setTitleColor(.blueButtonText, for: .selected)
        detailsButton.titleLabel?.font = .customBody(size: 16.0)
        
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 41.0
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.allowsSelection = false
        tableView.isScrollEnabled = false
        tableView.showsVerticalScrollIndicator = false
        
        dataSource.registerCells(forTableView: tableView)
        
        tableView.dataSource = dataSource
        tableView.reloadData()
        
        detailsButton.setTitle(S.TransactionDetails.showDetails, for: .normal)
        detailsButton.setTitle(S.TransactionDetails.hideDetails, for: .selected)
        detailsButton.addTarget(self, action: #selector(onToggleDetails), for: .touchUpInside)
        
        header.title = viewModel.title
        
    }
    
    private func setupTransaction() {
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: -
    
    @objc private func onToggleDetails() {
        isExpanded = !isExpanded
        detailsButton.isSelected = isExpanded
        
        UIView.spring(0.7, animations: {
            if self.isExpanded {
                self.containerHeightConstraint.constant = C.expandedContainerHeight
            } else {
                self.containerHeightConstraint.constant = C.compactContainerHeight
            }
            self.view.layoutIfNeeded()
        }) { _ in }
    }
}
