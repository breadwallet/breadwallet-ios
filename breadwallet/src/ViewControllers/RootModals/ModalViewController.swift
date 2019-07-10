//
//  File.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class ModalViewController: UIViewController, Subscriber {

    // MARK: - Public
    var childViewController: UIViewController

    init<T: UIViewController>(childViewController: T) where T: ModalDisplayable {
        self.childViewController = childViewController
        self.modalInfo = childViewController
        if let articleId = childViewController.faqArticleId {
            self.header = ModalHeaderView(title: modalInfo.modalTitle, style: .dark, faqInfo: articleId, currency: childViewController.faqCurrency)
        } else {
            self.header = ModalHeaderView(title: modalInfo.modalTitle, style: .dark)
        }

        super.init(nibName: nil, bundle: nil)
    }

    // MARK: - Private
    private let modalInfo: ModalDisplayable
    private let headerHeight: CGFloat = 49.0
    fileprivate let header: ModalHeaderView
    private let tapGestureRecognizer = UITapGestureRecognizer()
    private let scrollView = UIScrollView()
    private let scrollViewContent = UIView()

    deinit {
        Store.unsubscribe(self)
    }

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setInitialData()
    }

    private func addSubviews() {
        view.addSubview(header)
        view.addSubview(scrollView)
        scrollView.addSubview(scrollViewContent)

        addChild(childViewController)
        scrollViewContent.addSubview(childViewController.view)
        childViewController.didMove(toParent: self)
    }

    private func addConstraints() {
        header.constrain([
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.bottomAnchor.constraint(equalTo: scrollView.topAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: headerHeight)])
        scrollView.constrain([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor) ])
        scrollViewContent.constrain([
            scrollViewContent.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollViewContent.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            scrollViewContent.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollViewContent.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollViewContent.widthAnchor.constraint(equalTo: scrollView.widthAnchor) ])

        childViewController.view.constrain(toSuperviewEdges: nil)

        //Two stage layout is required here because we need the height constant
        //of the content at initial layout
        view.layoutIfNeeded()

        let height = scrollViewContent.bounds.size.height
        let minHeight = scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: height)
        let midHeight = scrollView.heightAnchor.constraint(equalTo: scrollViewContent.heightAnchor)
        let maxHeight = scrollView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -headerHeight)
        midHeight.priority = UILayoutPriority.defaultLow
        scrollView.constrain([
            minHeight,
            midHeight,
            maxHeight ])

    }

    private func setInitialData() {
        view.backgroundColor = .clear
        scrollView.backgroundColor = .white
        scrollView.delaysContentTouches = false
        if var modalPresentable = childViewController as? ModalPresentable {
            modalPresentable.parentView = view
        }

        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.addTarget(self, action: #selector(didTap))
        view.addGestureRecognizer(tapGestureRecognizer)
        Store.subscribe(self, name: .blockModalDismissal, callback: { _ in
            self.tapGestureRecognizer.isEnabled = false
        })

        Store.subscribe(self, name: .unblockModalDismissal, callback: { _ in
            self.tapGestureRecognizer.isEnabled = true
        })
        addTopCorners()
        header.closeCallback = { [weak self] in
            if let delegate = self?.transitioningDelegate as? ModalTransitionDelegate {
                delegate.reset()
            }
            self?.dismiss(animated: true, completion: {})
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowRadius = 4.0
        view.layer.shadowOffset = .zero
    }

    //Even though the status bar is hidden for this view,
    //it still needs to be set to light as it will temporarily
    //transition to black when this view gets presented
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    @objc private func didTap() {
        guard let modalTransitionDelegate = transitioningDelegate as? ModalTransitionDelegate else { return }
        modalTransitionDelegate.reset()
        dismiss(animated: true, completion: nil)
    }

    private func addTopCorners() {
        let path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 6.0, height: 6.0)).cgPath
        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        header.layer.mask = maskLayer
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ModalViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: view)
        if location.y < header.frame.minY {
            return true
        } else {
            return false
        }
    }
}
