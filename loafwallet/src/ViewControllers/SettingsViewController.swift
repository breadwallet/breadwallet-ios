//
//  SettingsViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-30.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//
import UIKit
import LocalAuthentication

class SettingsViewController : UITableViewController, CustomTitleView {
 
  init(sections: [String], rows: [String: [Setting]], optionalTitle: String? = nil) {
        self.sections = sections
        if UserDefaults.isBiometricsEnabled {
            self.rows = rows
        } else {
            var tempRows = rows
            let biometricsLimit = LAContext.biometricType() == .face ? S.Settings.faceIdLimit : S.Settings.touchIdLimit
            tempRows["Manage"] = tempRows["Manage"]?.filter { $0.title != biometricsLimit }
            self.rows = tempRows
        }

        customTitle = optionalTitle ?? S.Settings.title
        titleLabel.text = optionalTitle ?? S.Settings.title
        super.init(style: .plain)
    }
 
    private let sections: [String]
    private var rows: [String: [Setting]]
    private let cellIdentifier = "CellIdentifier"
    internal var titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)
    let customTitle: String
    private var walletIsEmpty = true

    override func viewDidLoad() {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 48.0))
         
        if #available(iOS 11.0, *) {
            guard let textColor = UIColor(named: "labelTextColor"),
            let backGroundColor = UIColor(named: "lfBackgroundColor") else {
                NSLog("ERROR: Custom color not found")
                return
            }

            headerView.backgroundColor = backGroundColor
            tableView.backgroundColor = backGroundColor
            titleLabel = UILabel(font: .customBold(size: 26.0), color: textColor)

        } else {
            headerView.backgroundColor = .liteWalletBlue
            tableView.backgroundColor = .clear
            titleLabel = UILabel(font: .customBold(size: 26.0), color: .darkText)
        }
             
        headerView.addSubview(titleLabel)
        titleLabel.constrain(toSuperviewEdges: UIEdgeInsetsMake(0, C.padding[2], 0, 0))
        tableView.register(SeparatorCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.tableHeaderView = headerView
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none 
         
        addCustomTitle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows[sections[section]]?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)

        if let setting = rows[sections[indexPath.section]]?[indexPath.row] {
            cell.textLabel?.text = setting.title
            cell.textLabel?.font = .customBody(size: 16.0)
             
            let label = UILabel(font: .customMedium(size: 14.0), color: .grayTextTint)
            label.text = setting.accessoryText?()
            label.sizeToFit()
            cell.accessoryView = label
            if sections[indexPath.section] == "About" {
                cell.selectionStyle = .none
            }
            
            if #available(iOS 11.0, *),
                let  textColor = UIColor(named: "labelTextColor") {
                cell.textLabel?.textColor = textColor
                label.textColor = textColor
            } else {
                cell.textLabel?.textColor = .darkText
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 44))
        let label = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
        let separator = UIView()
        
        if #available(iOS 11.0, *),
            let  backgroundColor = UIColor(named: "lfBackgroundColor"),
            let labelTextColor = UIColor(named:"labelTextColor") {
            view.backgroundColor = backgroundColor
            label.textColor = labelTextColor
        } else {
            view.backgroundColor = .whiteTint
        }
        
        view.addSubview(label)
        switch sections[section] {
        case "About":
            label.text = S.Settings.about
        case "Wallet":
            label.text = S.Settings.wallet
        case "Manage":
            label.text = S.Settings.manage
        case "Support":
            label.text = S.Settings.support
        case "Blockchain":
            label.text = S.Settings.blockchain
        default:
            label.text = ""
        }
        
        separator.backgroundColor = .secondaryShadow
        view.addSubview(separator)
        separator.constrain([
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0) ])

        label.constrain([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: C.padding[2]),
            label.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -4.0) ])

        return view
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let setting = rows[sections[indexPath.section]]?[indexPath.row] {
            setting.callback()
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 47.0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 48.0
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScrollForCustomTitle(yOffset: scrollView.contentOffset.y)
    }

    override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        scrollViewWillEndDraggingForCustomTitle(yOffset: targetContentOffset.pointee.y)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
