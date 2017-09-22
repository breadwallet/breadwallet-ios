//
//  SearchHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

enum SearchFilterType {
    case sent
    case received
    case pending
    case complete
    case text(String)

    var description: String {
        switch self {
        case .sent:
            return S.Search.sent
        case .received:
            return S.Search.received
        case .pending:
            return S.Search.pending
        case .complete:
            return S.Search.complete
        case .text(_):
            return ""
        }
    }

    var filter: TransactionFilter {
        switch self {
        case .sent:
            return { $0.direction == .sent }
        case .received:
            return { $0.direction == .received }
        case .pending:
            return { $0.isPending }
        case .complete:
            return { !$0.isPending }
        case .text(let text):
            return { transaction in
                let loweredText = text.lowercased()
                if transaction.hash.lowercased().contains(loweredText) {
                    return true
                }
                if let address = transaction.toAddress {
                    if address.lowercased().contains(loweredText) {
                        return true
                    }
                }
                if let metaData = transaction.metaData {
                    if metaData.comment.lowercased().contains(loweredText) {
                        return true
                    }
                }
                return false
            }
        }
    }
}

extension SearchFilterType : Equatable {}

func ==(lhs: SearchFilterType, rhs: SearchFilterType) -> Bool {
    switch (lhs, rhs) {
    case (.sent, .sent):
        return true
    case (.received, .received):
        return true
    case (.pending, .pending):
        return true
    case (.complete, .complete):
        return true
    case (.text(_), .text(_)):
        return true
    default:
        return false
    }
}


typealias TransactionFilter = (Transaction) -> Bool

class SearchHeaderView : UIView {

    init() {
        super.init(frame: .zero)
    }

    var didCancel: (() -> Void)?
    var didChangeFilters: (([TransactionFilter]) -> Void)?
    var hasSetup = false

    func triggerUpdate() {
        didChangeFilters?(filters.map { $0.filter })
    }

    private let searchBar = UISearchBar()
    private let sent = ShadowButton(title: S.Search.sent, type: .search)
    private let received = ShadowButton(title: S.Search.received, type: .search)
    private let pending = ShadowButton(title: S.Search.pending, type: .search)
    private let complete = ShadowButton(title: S.Search.complete, type: .search)
    private let cancel = UIButton(type: .system)
    fileprivate var filters: [SearchFilterType] = [] {
        didSet {
            didChangeFilters?(filters.map { $0.filter })
        }
    }

    private let sentFilter: TransactionFilter = { return $0.direction == .sent }
    private let receivedFilter: TransactionFilter = { return $0.direction == .received }

    override func layoutSubviews() {
        guard !hasSetup else { return }
        setup()
        hasSetup = true
    }

    private func setup() {
        addSubviews()
        addFilterButtons()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        addSubview(searchBar)
        addSubview(cancel)
    }

    private func addConstraints() {
        cancel.setTitle(S.Button.cancel, for: .normal)
        let titleSize = NSString(string: cancel.titleLabel!.text!).size(withAttributes: [NSAttributedStringKey.font : cancel.titleLabel!.font])
        cancel.constrain([
            cancel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]),
            cancel.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            cancel.widthAnchor.constraint(equalToConstant: titleSize.width + C.padding[4])])
        searchBar.constrain([
            searchBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[1]),
            searchBar.topAnchor.constraint(equalTo: topAnchor, constant: C.padding[2]),
            searchBar.trailingAnchor.constraint(equalTo: cancel.leadingAnchor, constant: -C.padding[1]) ])
    }

    private func setData() {
        backgroundColor = .whiteTint
        searchBar.backgroundImage = UIImage()
        searchBar.delegate = self
        cancel.tap = { [weak self] in
            self?.didChangeFilters?([])
            self?.searchBar.resignFirstResponder()
            self?.didCancel?()
        }
        sent.isToggleable = true
        received.isToggleable = true
        pending.isToggleable = true
        complete.isToggleable = true

        sent.tap = { [weak self] in
            guard let myself = self else { return }
            if myself.toggleFilterType(.sent) {
                if myself.received.isSelected {
                    myself.received.isSelected = false
                    myself.toggleFilterType(.received)
                }
            }
        }

        received.tap = { [weak self] in
            guard let myself = self else { return }
            if myself.toggleFilterType(.received) {
                if myself.sent.isSelected {
                    myself.sent.isSelected = false
                    myself.toggleFilterType(.sent)
                }
            }
        }

        pending.tap = { [weak self] in
            guard let myself = self else { return }
            if myself.toggleFilterType(.pending) {
                if myself.complete.isSelected {
                    myself.complete.isSelected = false
                    myself.toggleFilterType(.complete)
                }
            }
        }

        complete.tap = { [weak self] in
            guard let myself = self else { return }
            if myself.toggleFilterType(.complete) {
                if myself.pending.isSelected {
                    myself.pending.isSelected = false
                    myself.toggleFilterType(.pending)
                }
            }
        }
    }

    @discardableResult private func toggleFilterType(_ filterType: SearchFilterType) -> Bool {
        if let index = filters.index(of: filterType) {
            filters.remove(at: index)
            return false
        } else {
            filters.append(filterType)
            return true
        }
    }

    private func addFilterButtons() {
        if #available(iOS 9, *) {
            let stackView = UIStackView()
            addSubview(stackView)
            stackView.distribution = .fillProportionally
            stackView.spacing = C.padding[1]
            stackView.constrain([
                stackView.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor),
                stackView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: C.padding[1]),
                stackView.trailingAnchor.constraint(equalTo: cancel.trailingAnchor) ])
            stackView.addArrangedSubview(sent)
            stackView.addArrangedSubview(received)
            stackView.addArrangedSubview(pending)
            stackView.addArrangedSubview(complete)
        } else {
            addSubview(sent)
            addSubview(received)
            addSubview(pending)
            addSubview(complete)
            sent.constrain([
                sent.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor),
                sent.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: C.padding[1]) ])
            received.constrain([
                received.leadingAnchor.constraint(equalTo: sent.trailingAnchor, constant: C.padding[1]),
                received.topAnchor.constraint(equalTo: sent.topAnchor)])
            pending.constrain([
                pending.leadingAnchor.constraint(equalTo: received.trailingAnchor, constant: C.padding[1]),
                pending.topAnchor.constraint(equalTo: received.topAnchor)])
            complete.constrain([
                complete.leadingAnchor.constraint(equalTo: pending.trailingAnchor, constant: C.padding[1]),
                complete.topAnchor.constraint(equalTo: sent.topAnchor) ])
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SearchHeaderView : UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let filter: SearchFilterType = .text(searchText)
        if let index = filters.index(of: filter) {
            filters.remove(at: index)
        }
        if searchText != "" {
            filters.append(filter)
        }
    }
}
