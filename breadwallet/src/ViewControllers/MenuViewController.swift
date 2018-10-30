//
//  MenuViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-30.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class MenuViewController : UITableViewController {
    
    init(items: [MenuItem], title: String, faqButton: UIButton? = nil) {
        self.items = items
        self.faqButton = faqButton
        super.init(style: .plain)
        self.title = title
    }

    private let items: [MenuItem]
    private var visibleItems: [MenuItem] {
        return items.filter { $0.shouldShow() }
    }
    private let faqButton: UIButton?
    
    func reloadMenu() {
        var index: Int = 0
        for item: MenuItem in items {
            updateMenuItem(item: item, index: index)
            index += 1
        }
    }
    
    private func updateMenuItem(item: MenuItem, index: Int) {
        guard let updateTitle = item.getUpdatedTitle else { return }
        let newTitle = updateTitle()
        
        var menuItem = item
        menuItem.title = newTitle
        
        guard let cell = tableView.cellForRow(at: IndexPath(item: index, section: 0)) as? MenuCell else { return }
        cell.textLabel?.text = newTitle
    }
    
    override func viewDidLoad() {
        tableView.register(MenuCell.self, forCellReuseIdentifier: MenuCell.cellIdentifier)
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = .darkBackground
        tableView.rowHeight = 48.0
        
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        
        if let button = faqButton {
            button.tintColor = .navigationTint
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MenuCell.cellIdentifier, for: indexPath) as? MenuCell else { return UITableViewCell() }
        cell.set(item: visibleItems[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let menuItem = visibleItems[indexPath.row]
        menuItem.callback()
                
        tableView.deselectRow(at: indexPath, animated: true)
        
        updateMenuItem(item: menuItem, index: indexPath.row)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
