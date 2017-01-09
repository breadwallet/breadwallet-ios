//
//  AccountViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AccountViewController: UIViewController, Trackable, Subscriber {

    private let store: Store
    private let headerView = AccountHeaderView()
    private let footerView = AccountFooterView()
    private let notificationView = SyncProgressView()
    private let transactions = TransactionsTableViewController()
    private let headerHeight: CGFloat = 136.0
    private let footerHeight: CGFloat = 56.0

    var sendCallback: (() -> Void)? {
        didSet { footerView.sendCallback = sendCallback }
    }
    var receiveCallback: (() -> Void)? {
        didSet { footerView.receiveCallback = receiveCallback }
    }
    var menuCallback: (() -> Void)? {
        didSet { footerView.menuCallback = menuCallback }
    }

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        addTransactionsView()

        view.addSubview(headerView)
        view.addSubview(footerView)
        view.addSubview(notificationView)
        headerView.constrainTopCorners(sidePadding: 0, topPadding: 0)
        headerView.constrain([
            headerView.constraint(.height, constant: headerHeight) ])

        footerView.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        footerView.constrain([
            footerView.constraint(.height, constant: footerHeight) ])

        notificationView.constrain([
            notificationView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            notificationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            notificationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            notificationView.heightAnchor.constraint(equalToConstant: 48.0) ])


        store.subscribe(self, selector: {$0.walletState != $1.walletState },
                        callback: { state in
                            self.notificationView.progress = state.walletState.syncProgress
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        saveEvent("accout:did_appear")
    }

    private func addTransactionsView() {
        addChildViewController(transactions, layout: {
            transactions.view.constrain(toSuperviewEdges: nil)
            transactions.tableView.contentInset = UIEdgeInsets(top: headerHeight + C.padding[2], left: 0, bottom: footerHeight + C.padding[2], right: 0)
            transactions.tableView.scrollIndicatorInsets = UIEdgeInsets(top: headerHeight, left: 0, bottom: footerHeight, right: 0)
        })
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
