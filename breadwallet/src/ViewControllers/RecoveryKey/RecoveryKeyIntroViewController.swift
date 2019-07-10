//
//  RecoveryKeyIntroViewController.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-03-18.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

typealias DidExitRecoveryKeyIntroWithAction = ((ExitRecoveryKeyAction) -> Void)

enum RecoveryKeyIntroExitButtonType {
    case none
    case closeButton
    case backButton
}

//
// Defines the content for a page in the recovery key introductory flow.
//
struct RecoveryKeyIntroPage {
    var title: String
    var subTitle: String
    var stepHint: String    // e.g., "How it works - Step 1
    var imageName: String
    var continueButtonText: String
    var isLandingPage: Bool
    
    init(title: String,
         subTitle: String,
         imageName: String,
         stepHint: String = "",
         continueButtonText: String = S.Button.continueAction,
         isLandingPage: Bool = false) {
        
        self.title = title
        self.subTitle = subTitle
        self.stepHint = stepHint
        self.imageName = imageName
        self.continueButtonText = continueButtonText
        self.isLandingPage = isLandingPage
    }
}

//
// Base class for paper key recovery content pages, including the landing page and the
// educational/intro pages.
//
class RecoveryKeyPageCell: UICollectionViewCell {
    
    var page: RecoveryKeyIntroPage?
    var imageView = UIImageView()
    var titleLabel = UILabel.wrapping(font: Theme.h2Title, color: Theme.primaryText)
    var subTitleLabel = UILabel.wrapping(font: Theme.body1, color: Theme.secondaryText)
    
    let headingLeftRightMargin: CGFloat = 32

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpSubviews()
        setUpConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpSubviews() {
        [titleLabel, subTitleLabel, imageView].forEach({ contentView.addSubview($0) })
        titleLabel.textAlignment = .center
        subTitleLabel.textAlignment = .center
        imageView.contentMode = .scaleAspectFit
    }
    
    func setUpConstraints() {
        // subclasses should position their subviews
    }
    
    func configure(with page: RecoveryKeyIntroPage) {
        titleLabel.text = page.title
        subTitleLabel.text = page.subTitle
        imageView.image = UIImage(named: page.imageName)
    }
}

//
// Full-screen collection view cell for recovery key landing page.
//
class RecoveryKeyLandingPageCell: RecoveryKeyPageCell {
    
    static let lockImageName = "RecoveryKeyLockImageDefault"
    private let lockImageDefaultSize: (CGFloat, CGFloat) = (100, 144)
    private var lockImageScale: CGFloat = 1.0
    private var lockIconTopConstraintPercent: CGFloat = 0.29
    private let headingTopMargin: CGFloat = 38
    private let subheadingTopMargin: CGFloat = 18

    override func setUpSubviews() {
        super.setUpSubviews()
        
        // The lock image is a bit too large at scale for small screens such as the iPhone 5 SE.
        // Here we shrink the image and move it up. See setUpConstraints().
        if E.isIPhone6OrSmaller {
            lockImageScale = 0.8
            lockIconTopConstraintPercent = 0.2
        }
    }
    
    override func setUpConstraints() {
        let screenHeight = UIScreen.main.bounds.height
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let lockImageTop = (screenHeight * lockIconTopConstraintPercent) - statusBarHeight
        
        imageView.constrain([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: lockImageTop),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
            ])
        
        if lockImageScale != 1.0 {
            let scaledWidth: CGFloat = (lockImageDefaultSize.0 * lockImageScale)
            let scaledHeight: CGFloat = (lockImageDefaultSize.1 * lockImageScale)
            
            imageView.constrain([
                imageView.widthAnchor.constraint(equalToConstant: scaledWidth),
                imageView.heightAnchor.constraint(equalToConstant: scaledHeight)
                ])
        }
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: headingTopMargin),
            titleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: headingLeftRightMargin),
            titleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -headingLeftRightMargin)
            ])
        
        subTitleLabel.constrain([
            subTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: subheadingTopMargin),
            subTitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: headingLeftRightMargin),
            subTitleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -headingLeftRightMargin)
            ])
    }
}

//
// Full-screen collection view cell for the recovery key educational/intro pages.
//
class RecoveryKeyIntroCell: RecoveryKeyPageCell {

    private var introStepLabel = UILabel()
    private var contentTopConstraintPercent: CGFloat = 0.3
    private let imageWidth: CGFloat = 52
    private let imageHeight: CGFloat = 44
    private let imageTopMarginToTitle: CGFloat = 42
    private let subtitleTopMarginToImage: CGFloat = 20
    
    override func setUpSubviews() {
        super.setUpSubviews()
        
        introStepLabel.font = Theme.body2
        introStepLabel.textColor = Theme.accent
        introStepLabel.textAlignment = .center
        introStepLabel.numberOfLines = 0
        
        contentView.addSubview(introStepLabel)
        
        if E.isSmallScreen {
            contentTopConstraintPercent = 0.22
        }
    }
    
    override func setUpConstraints() {
        super.setUpConstraints()
        
        let screenHeight = UIScreen.main.bounds.height
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let contentTop = (screenHeight * contentTopConstraintPercent) - statusBarHeight
        
        introStepLabel.constrain([
            introStepLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: contentTop),
            introStepLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: C.padding[2]),
            introStepLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -C.padding[2])
            ])
        
        titleLabel.constrain([
            titleLabel.topAnchor.constraint(equalTo: introStepLabel.bottomAnchor, constant: C.padding[1]),
            titleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: headingLeftRightMargin),
            titleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -headingLeftRightMargin)
            ])
        
        imageView.constrain([
            imageView.widthAnchor.constraint(equalToConstant: imageWidth),
            imageView.heightAnchor.constraint(equalToConstant: imageHeight),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: imageTopMarginToTitle)
            ])
        
        subTitleLabel.constrain([
            subTitleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: subtitleTopMarginToImage),
            subTitleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: headingLeftRightMargin),
            subTitleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -headingLeftRightMargin)
            ])
    }
    
    override func configure(with page: RecoveryKeyIntroPage) {
        super.configure(with: page)
        introStepLabel.text = page.stepHint
    }
}

//
// Screen displayed when the user wants to generate a recovery key or view the words and
// write it down again.
//
class RecoveryKeyIntroViewController: BaseRecoveryKeyViewController {

    private var mode: EnterRecoveryKeyMode = .generateKey

    private var landingPage: RecoveryKeyIntroPage {
        switch mode {
        case .generateKey:
            return RecoveryKeyIntroPage(title: S.RecoverKeyFlow.generateKey,
                                        subTitle: S.RecoverKeyFlow.generateKeyExplanation,
                                        imageName: RecoveryKeyLandingPageCell.lockImageName,
                                        continueButtonText: S.Button.continueAction, isLandingPage: true)
        case .writeKey:
            return RecoveryKeyIntroPage(title: S.RecoverKeyFlow.writeKeyAgain,
                                        subTitle: UserDefaults.writePaperPhraseDateString,
                                        imageName: RecoveryKeyLandingPageCell.lockImageName,
                                        continueButtonText: S.Button.continueAction, isLandingPage: true)
        case .unlinkWallet:
            return RecoveryKeyIntroPage(title: S.RecoverKeyFlow.unlinkWallet,
                                        subTitle: S.RecoverKeyFlow.unlinkWalletSubtitle,
                                        imageName: RecoveryKeyLandingPageCell.lockImageName,
                                        continueButtonText: S.Button.continueAction, isLandingPage: true)
        }
    }
    
    // View that appears above the 'Generate Recovery Key' button on the final intro
    // page, explaining to the user that the recovery key is not required for everyday
    // wallet access.
    private let keyUseInfoView = InfoView()
    
    private let continueButton = BRDButton(title: S.Button.continueAction, type: .primary)
    private var pagingView: UICollectionView?
    private var pagingViewContainer: UIView = UIView()
    
    private var pages: [RecoveryKeyIntroPage] = [RecoveryKeyIntroPage]()
    
    private var pageIndex: Int = 0 {
        willSet {
            if newValue == 0 {
                self.hideBackButton()
            }
        }
        
        didSet {
            if let paging = pagingView {
                paging.scrollToItem(at: IndexPath(item: self.pageIndex, section: 0),
                                    at: UICollectionView.ScrollPosition.left,
                                    animated: true)
                // Let the scrolling animation run for a slight delay, then update the continue
                // button text if needed, and show the key-use info view. Doing a custom UIView animation
                // for the paging causes the page content to disappear before the next page cell animates in.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    let page = self.pages[self.pageIndex]
                    self.continueButton.title = page.continueButtonText
                    self.keyUseInfoView.isHidden = self.shouldHideInfoView
                    
                    if self.onLastPage {
                        self.showCloseButton()
                    }
                    
                    if self.pageIndex == 0 {
                        self.hideBackButton()
                    } else {
                        self.showBackButton()
                    }
                }
            }
        }
    }
    
    private var onLastPage: Bool { return self.pageIndex == self.pages.count - 1 }
    
    private var exitCallback: DidExitRecoveryKeyIntroWithAction?
    private var exitButtonType: RecoveryKeyIntroExitButtonType = .closeButton
    
    private var shouldHideInfoView: Bool {
        guard mode == .generateKey else { return true }
        return !self.onLastPage
    }
    
    private var infoViewText: String {
        if mode == .unlinkWallet {
            return S.RecoverKeyFlow.unlinkWalletWarning
        } else {
            return S.RecoverKeyFlow.keyUseInfoHint
        }
    }
    
    init(mode: EnterRecoveryKeyMode = .generateKey,
         eventContext: EventContext,
         exitButtonType: RecoveryKeyIntroExitButtonType,
         exitCallback: DidExitRecoveryKeyIntroWithAction?) {
        
        self.mode = mode
        self.exitButtonType = exitButtonType
        self.exitCallback = exitCallback
        
        super.init(eventContext, .paperKeyIntro)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var closeButtonStyle: BaseRecoveryKeyViewController.CloseButtonStyle {
        return eventContext == .onboarding ? .skip : .close
    }
    
    override func onCloseButton() {
        guard let exit = self.exitCallback else { return }
        
        switch mode {
        // If writing down the key again, just bail.
        case .writeKey:
            exit(.abort)
            
        // If generating the key for the first time, confirm that the user really wants to exit.
        case .generateKey:
            RecoveryKeyFlowController.promptToSetUpRecoveryKeyLater(from: self) { [unowned self] (userWantsToSetUpLater) in
                if userWantsToSetUpLater {
                    self.trackEvent(event: .dismissed, metaData: nil, tracked: {
                        exit(.abort)
                    })
                }
            }
        
        case .unlinkWallet:
            exit(.abort)
        }
    }
    
    override func onBackButton() {
        if pageIndex == 0 {
            onCloseButton()
        } else {
            pageIndex = max(0, pageIndex - 1)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Theme.primaryBackground
        navigationItem.setHidesBackButton(true, animated: false)
        
        showExitButton()
        setUpPages()
        setUpKeyUseInfoView()
        setUpPagingView()
        setUpContinueButton()
        addSubviews()
        setUpConstraints()
    }
    
    private func addSubviews() {
        view.addSubview(pagingViewContainer)
        view.addSubview(continueButton)
        view.addSubview(keyUseInfoView)
    }
    
    private func showExitButton() {
        
        switch exitButtonType {
        case .none:
            hideLeftNavigationButton()
        case .backButton:
            showBackButton()
        case .closeButton:
            showCloseButton()
        }
    }
    
    private func hideLeftNavigationButton() {
        self.navigationItem.leftBarButtonItem = nil
        self.navigationItem.backBarButtonItem = nil
    }
        
    private func setUpKeyUseInfoView() {
        keyUseInfoView.text = infoViewText
        keyUseInfoView.imageName = "ExclamationMarkCircle"
        keyUseInfoView.isHidden = shouldHideInfoView
    }
    
    private func setUpPages() {
        
        pages.append(landingPage)
        
        // If the key is being generated for the first time, add the intro pages and allow paging.
        if mode == .generateKey {
            pages.append(RecoveryKeyIntroPage(title: S.RecoverKeyFlow.writeItDown,
                                              subTitle: S.RecoverKeyFlow.noScreenshotsRecommendation,
                                              imageName: "RecoveryKeyPaper",
                                              stepHint: String(format: S.RecoverKeyFlow.howItWorksStepLabel, "1")))

            pages.append(RecoveryKeyIntroPage(title: S.RecoverKeyFlow.keepSecure,
                                              subTitle: S.RecoverKeyFlow.storeSecurelyRecommendation,
                                              imageName: "RecoveryKeyPrivateEye",
                                              stepHint: String(format: S.RecoverKeyFlow.howItWorksStepLabel, "2")))

            pages.append(RecoveryKeyIntroPage(title: S.RecoverKeyFlow.relaxBuyTrade,
                                              subTitle: S.RecoverKeyFlow.securityAssurance,
                                              imageName: "RecoveryKeyShield",
                                              stepHint: String(format: S.RecoverKeyFlow.howItWorksStepLabel, "3"),
                                              continueButtonText: S.RecoverKeyFlow.generateKeyButton,
                                              isLandingPage: false))
        }
    }
    
    private func setUpPagingView() {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = .zero
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.scrollDirection = .horizontal
        
        let paging = UICollectionView(frame: .zero, collectionViewLayout: layout)
        paging.backgroundColor = .clear
        
        paging.collectionViewLayout = layout
        paging.isScrollEnabled = (mode == .generateKey)
        paging.isPagingEnabled = true
        
        paging.delegate = self
        paging.dataSource = self
        
        paging.register(RecoveryKeyLandingPageCell.self, forCellWithReuseIdentifier: "RecoveryKeyLandingPageCell")
        paging.register(RecoveryKeyIntroCell.self, forCellWithReuseIdentifier: "RecoveryKeyIntroCell")
        
        paging.isUserInteractionEnabled = false // only use the Continue button to move forward in the flow
        
        pagingViewContainer.addSubview(paging)
        pagingView = paging
    }
    
    private func exit(action: ExitRecoveryKeyAction) {
        if let exit = exitCallback {
            
            if action == .generateKey {
                trackEvent(event: .generatePaperKeyButton, metaData: nil, tracked: {
                    exit(action)
                })
            } else {
                exit(action)
            }
        }
    }
    
    private func setUpContinueButton() {
        continueButton.layer.cornerRadius = 2.0
        continueButton.tap = { [unowned self] in
            
            if self.mode == .unlinkWallet {
                self.exit(action: .unlinkWallet)
            } else {
                if self.onLastPage {
                    self.exit(action: .generateKey)
                } else {
                    self.pageIndex = min(self.pageIndex + 1, self.pages.count - 1)
                }
            }
        }
    }
    
    private func setUpConstraints() {
        
        pagingViewContainer.constrain(toSuperviewEdges: .zero)
        
        if let paging = pagingView {
            paging.constrain(toSuperviewEdges: .zero)
        }
        
        constrainContinueButton(continueButton)
        
        // The key use info view sits just above the Continue button.
        keyUseInfoView.constrain([
            keyUseInfoView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: C.padding[2]),
            keyUseInfoView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -C.padding[2]),
            keyUseInfoView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -C.padding[2])
            ])
    }
}

extension RecoveryKeyIntroViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let page = pages[indexPath.item]
        
        if page.isLandingPage {
            if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecoveryKeyLandingPageCell",
                                                             for: indexPath) as? RecoveryKeyLandingPageCell {
                cell.configure(with: page)
                return cell
            }
        } else {
            if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecoveryKeyIntroCell",
                                                             for: indexPath) as? RecoveryKeyIntroCell {
                cell.configure(with: page)
                return cell
            }
        }
        
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
    
}
