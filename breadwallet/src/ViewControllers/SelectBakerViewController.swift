// 
//  StakeSelectViewController.swift
//  breadwallet
//
//  Created by Jared Wheeler on 2/10/21.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class SelectBakerViewController: UIViewController, Subscriber, Trackable, ModalPresentable, UITableViewDataSource, UITableViewDelegate {
    
    private let currency: Currency
    private let loadingSpinner = UIActivityIndicatorView(style: .whiteLarge)
    private var bakers: [Baker]?
    private let tableView = UITableView()
    var parentView: UIView? //ModalPresentable
    
    init(currency: Currency) {
        self.currency = currency
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        tableView.register(SelectBakerCell.self, forCellReuseIdentifier: SelectBakerCellIds.selectBakerCell.rawValue)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.isHidden = true
        
        tableView.constrain([
            tableView.constraint(.leading, toView: view, constant: 0.0),
            tableView.constraint(.trailing, toView: view, constant: 0.0),
            tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0.0),
            tableView.constraint(.height, constant: 600),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0.0) ])
        
        setInitialData()
    }
    
    private func setInitialData() {
        showLoadingIndicator(true)
        ExternalAPIClient.shared.send(BakersRequest()) { [weak self] response in
            guard case .success(let data) = response else { return }
            
            self?.bakers = data.filter({ baker -> Bool in
                return baker.freeSpace > 0
            })
            self?.tableView.reloadData()
            self?.tableView.isHidden = false
            self?.showLoadingIndicator(false)
        }
    }
    
    func showLoadingIndicator(_ show: Bool) {
        guard show else {
            loadingSpinner.removeFromSuperview()
            return
        }
        loadingSpinner.color = UIColor.black
        view.addSubview(loadingSpinner)
        loadingSpinner.constrain([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        
        loadingSpinner.startAnimating()
    }
    
    // MARK: - Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bakers?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let baker = bakers?[indexPath.row]
        let cellIdentifier = SelectBakerCellIds.selectBakerCell.rawValue
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        if let cell = cell as? SelectBakerCell {
            cell.set(baker)
        }
        return cell
    }
    
    // MARK: - Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let baker = bakers?[indexPath.row] {
            Store.trigger(name: .didSelectBaker(baker))
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return SelectBakerCell.CellHeight
    }
}

// MARK: - ModalDisplayable

extension SelectBakerViewController: ModalDisplayable {
    var faqArticleId: String? {
        return "staking"
    }
    
    var faqCurrency: Currency? {
        return currency
    }

    var modalTitle: String {
        return S.Staking.selectBakerTitle
    }
}
