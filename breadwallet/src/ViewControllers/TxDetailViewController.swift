//
//  TxDetailViewController.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-18.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

private extension C {
    static let statusRowHeight: CGFloat = 48.0
    static let compactContainerHeight: CGFloat = 322.0
    static let expandedContainerHeight: CGFloat = 546.0
    static let detailsButtonHeight: CGFloat = 65.0
}

protocol TxDetaiViewControllerDelegate: class {
    func txDetailDidDismiss(detailViewController: TxDetailViewController)
}

class TxDetailViewController: UIViewController, Subscriber {
    
    // MARK: - Private Vars
    
    private let container = UIView()
    private let tapView = UIView()
    private let header: ModalHeaderView
    private let footer = UIView()
    private let separator = UIView()
    private let detailsButton = UIButton(type: .custom)
    private let tableView = UITableView()
    
    private weak var txDetailDelegate: TxDetaiViewControllerDelegate?
    
    private var containerHeightConstraint: NSLayoutConstraint!
    
    private var transaction: Transaction {
        didSet {
            reload()
        }
    }
    
    private var viewModel: TxDetailViewModel
    private var dataSource: TxDetailDataSource
    private var isExpanded: Bool = false
    
    private var compactContainerHeight: CGFloat {
        return (viewModel.status == .complete || viewModel.status == .invalid) ? C.compactContainerHeight : C.compactContainerHeight + C.statusRowHeight
    }
    
    private var expandedContainerHeight: CGFloat {
        let maxHeight = view.frame.height - C.padding[4]
        let contentHeight = header.frame.height + tableView.contentSize.height + footer.frame.height + separator.frame.height
        tableView.isScrollEnabled = contentHeight > maxHeight
        return min(maxHeight, contentHeight)
    }
    
    // MARK: - Init
    
    init(transaction: Transaction, delegate: TxDetaiViewControllerDelegate? = nil) {
        self.transaction = transaction
        self.viewModel = TxDetailViewModel(tx: transaction)
        self.dataSource = TxDetailDataSource(viewModel: viewModel)
        self.header = ModalHeaderView(title: "", style: .transaction, faqInfo: ArticleIds.transactionDetails, currency: transaction.currency)
        
        super.init(nibName: nil, bundle: nil)
        
        header.closeCallback = { [weak self] in
            self?.close()
        }

        self.txDetailDelegate = delegate

        setup()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerForKeyboardNotifications()
        
        // refresh if rate changes
        Store.lazySubscribe(self,
                            selector: { [weak self] oldState, newState in
                                guard let `self` = self else { return false }
                                return oldState[self.viewModel.currency]?.currentRate != newState[self.viewModel.currency]?.currentRate },
                            callback: { [weak self] _ in
                                self?.reload()
        })
        // refresh if tx state changes
        //TODO:CRYPTO hook up refresh logic to System/Wallet tx events IOS-1162
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag) {
            self.txDetailDelegate?.txDetailDidDismiss(detailViewController: self)
        }
    }
    
    private func setup() {
        addSubViews()
        addConstraints()
        setupActions()
        setInitialData()
    }
    
    private func addSubViews() {
        view.addSubview(tapView)
        view.addSubview(container)
        container.addSubview(header)
        container.addSubview(tableView)
        container.addSubview(footer)
        container.addSubview(separator)
        footer.addSubview(detailsButton)
    }
    
    private func addConstraints() {
        tapView.constrain(toSuperviewEdges: nil)
        container.constrain([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -C.padding[2]),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        
        containerHeightConstraint = container.heightAnchor.constraint(equalToConstant: compactContainerHeight)
        containerHeightConstraint.isActive = true
        
        header.constrainTopCorners(height: C.Sizes.headerHeight)
        tableView.constrain([
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: footer.topAnchor)
            ])
        
        footer.constrainBottomCorners(height: C.detailsButtonHeight)
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            separator.topAnchor.constraint(equalTo: footer.topAnchor, constant: 1.0),
            separator.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5) ])
        detailsButton.constrain(toSuperviewEdges: .zero)
    }
    
    private func setupActions() {
        let gr = UITapGestureRecognizer(target: self, action: #selector(close))
        tapView.addGestureRecognizer(gr)
        tapView.isUserInteractionEnabled = true
    }
    
    private func setInitialData() {
        container.layer.cornerRadius = C.Sizes.roundedCornerRadius
        container.layer.masksToBounds = true
        
        footer.backgroundColor = .white
        separator.backgroundColor = .secondaryShadow
        detailsButton.setTitleColor(.blueButtonText, for: .normal)
        detailsButton.setTitleColor(.blueButtonText, for: .selected)
        detailsButton.titleLabel?.font = .customBody(size: 16.0)
        
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 45.0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false
        tableView.isScrollEnabled = false
        tableView.showsVerticalScrollIndicator = false
        
        dataSource.registerCells(forTableView: tableView)
        
        tableView.dataSource = dataSource
        tableView.reloadData()
        
        detailsButton.setTitle(S.TransactionDetails.showDetails, for: .normal)
        detailsButton.setTitle(S.TransactionDetails.hideDetails, for: .selected)
        detailsButton.addTarget(self, action: #selector(onToggleDetails), for: .touchUpInside)
        
        header.setTitle(viewModel.title)
    }
    
    private func reload() {
        viewModel = TxDetailViewModel(tx: transaction)
        dataSource = TxDetailDataSource(viewModel: viewModel)
        dataSource.registerCells(forTableView: tableView)
        tableView.dataSource = dataSource
        tableView.reloadData()
    }
    
    deinit {
        Store.unsubscribe(self)
        NotificationCenter.default.removeObserver(self)
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
                self.containerHeightConstraint.constant = self.expandedContainerHeight
            } else {
                self.containerHeightConstraint.constant = self.compactContainerHeight
            }
            self.view.layoutIfNeeded()
        }, completion: { _ in })
    }
    
    @objc private func close() {
        if let delegate = transitioningDelegate as? ModalTransitionDelegate {
            delegate.reset()
        }
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Keyboard Handler
extension TxDetailViewController {
    fileprivate func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc fileprivate func keyboardWillShow(notification: NSNotification) {
        if let delegate = transitioningDelegate as? ModalTransitionDelegate {
            delegate.shouldDismissInteractively = false
        }
        if !isExpanded {
            onToggleDetails()
        }
        if let keyboardHeight = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        }
    }
    
    @objc fileprivate func keyboardWillHide(notification: NSNotification) {
        if let delegate = transitioningDelegate as? ModalTransitionDelegate {
            delegate.shouldDismissInteractively = true
        }
        UIView.animate(withDuration: 0.2, animations: {
            // adding inset in keyboardWillShow is animated by itself but removing is not
            self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        })
    }
}
