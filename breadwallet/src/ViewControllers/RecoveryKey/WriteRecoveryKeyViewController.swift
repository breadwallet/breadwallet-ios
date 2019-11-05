//
//  WriteRecoveryKeyViewController.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-03-22.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

typealias WriteRecoveryKeyExitHandler = ((ExitRecoveryKeyAction) -> Void)

class WriteRecoveryKeyViewController: BaseRecoveryKeyViewController {
    
    enum ScrollDirection: Int {
        case none
        case forward
        case backward
    }
    
    let pageCount = 12
    
    private let interactionPagingViewTag = 1
    private let wordPagingViewTag = 2
    
    let pagingCellReuseId = "pagingCell"
    let wordCellReuseId = "wordCell"
    let blankCellReuseId = "blankCell"
    
    private let keyMaster: KeyMaster
    private let pin: String
    private var words: [String] {
        guard let phraseString = self.keyMaster.seedPhrase(pin: self.pin) else { return [] }
        return phraseString.components(separatedBy: " ")
    }

    private let stepLabelTopMargin: CGFloat = E.isSmallScreen ? 36 : 24
    private let headingTopMargin: CGFloat = 28
    private let headingLeftRightMargin: CGFloat = 50
    private let subheadingLeftRightMargin: CGFloat = 70
    
    var interactionPagingView: UICollectionView?
    var wordPagingView: WordPagingCollectionView?
    
    private let headingLabel = UILabel()
    private let subheadingLabel = UILabel()
    private let stepLabel = UILabel()
    private let doneButton = BRDButton(title: S.Button.doneAction, type: .primary)
    private let infoView = InfoView()
    
    var pageIndex: Int = 0 {
        didSet {
            updateStepLabel()
            updateInfoView()
            enableDoneButton(pageIndex == (pageCount - 1))
        }
    }
    
    var scrollOffset: CGFloat = 0 {
        didSet {
            pageIndex = Int(scrollOffset / scrollablePageWidth)
            
            let partialPage = scrollOffset - (CGFloat(pageIndex) * scrollablePageWidth)
            pageScrollingPercent = partialPage / scrollablePageWidth
        }
    }
    
    var pageScrollingPercent: CGFloat = 0 {
        didSet {
            updateWordCellAppearances(pageScrollPercent: pageScrollingPercent)
        }
    }
    
    var lastScrollOffset: CGFloat = 0
    var scrollDirection: ScrollDirection = .none
    
    var scrollablePageWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    var wordPageWidth: CGFloat {
        // The word pages are offset at half a page width so that the center of the next
        // label is chopped in half by the right side of the display.
        return (scrollablePageWidth / 2)
    }
    
    var totalScrollableWidth: CGFloat {
        // Subtract one page width from the scrollable width because when the screen
        // is first displayed, we can see the first page of content.
        return scrollablePageWidth * CGFloat(pageCount - 1)
    }
    
    private var pagingViewContainer: UIView = UIView()

    private var mode: EnterRecoveryKeyMode = .generateKey
    private var dismissAction: (() -> Void)?
    private var exitCallback: WriteRecoveryKeyExitHandler?
    
    private var shouldShowDoneButton: Bool {
        return mode != .writeKey
    }
    
    private var wordPagingViewSavedContentOffset: CGPoint?
    
    private var notificationObservers = [String: NSObjectProtocol]()

    // MARK: initialization
    
    init(keyMaster: KeyMaster,
         pin: String,
         mode: EnterRecoveryKeyMode,
         eventContext: EventContext,
         dismissAction: (() -> Void)?,
         exitCallback: WriteRecoveryKeyExitHandler?) {
        
        self.keyMaster = keyMaster
        self.pin = pin
        self.mode = mode
        self.dismissAction = dismissAction
        self.exitCallback = exitCallback
        
        super.init(eventContext, .writePaperKey)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        notificationObservers.values.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: exit handling
    
    private func exit() {
        // If the user exits from write-key-again mode, there's no need to prompt, so guard that we're in
        // generate-key mode.
        guard mode == .generateKey else {
            exitCallback?(.abort)
            return
        }
        
        RecoveryKeyFlowController.promptToSetUpRecoveryKeyLater(from: self) { [unowned self] (userWantsToSetUpLater) in
            if userWantsToSetUpLater {
                
                // Track the dismissed event before invoking the dismiss action or we could be
                // deinit'd before the event is logged.
                
                let metaData = [ "step": String(self.pageIndex + 1) ]
                self.trackEvent(event: .dismissed, metaData: metaData, tracked: {
                    self.exitWithoutPrompting()
                })
            }
        }
    }
    
    private func exitWithoutPrompting() {
        if let dismissAction = self.dismissAction {
            dismissAction()
        } else if let exitCallback = self.exitCallback {
            exitCallback(.abort)
        } else if let navController = self.navigationController {
            navController.popViewController(animated: true)
        }
    }
    
    override var closeButtonStyle: BaseRecoveryKeyViewController.CloseButtonStyle {
        return eventContext == .onboarding ? .skip : .close
    }
    
    // MARK: lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Theme.primaryBackground
        view.clipsToBounds = true
        
        showBackButton()        
        setUpPagingViews()
        setUpLabels()
        addSubviews()
        setUpConstraints()
        
        showCloseButton()
        
        updateStepLabel()
        updateInfoView()

        enableDoneButton(false)
        doneButton.isHidden = !shouldShowDoneButton
        
        doneButton.tap = { [unowned self] in
            if let exit = self.exitCallback {
                switch self.mode {
                // If the user is generating the key for the first time, exit and move to the confirm key flow.
                case .generateKey:
                    exit(.confirmKey)
                // If the user is just writing the key down again, we're just aborting the process.
                case .writeKey:
                    exit(.abort)
                case .unlinkWallet:
                    exit(.unlinkWallet)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateWordCellAppearances(pageScrollPercent: 0)
        wordPagingView?.willAppear()
        listenForBackgroundNotification()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        wordPagingView?.willDisappear()
        unsubscribeNotifications()
    }
    
    override func onCloseButton() {
        exit()
    }
    
    private func enableDoneButton(_ enable: Bool) {
        // If the user is in write-key-again mode, always enable the Done button because the
        // the flow can be exited at any time.
        if mode == .writeKey {
            doneButton.isEnabled = true
        } else {
            doneButton.isEnabled = enable
        }
    }
    
    private func listenForBackgroundNotification() {
        notificationObservers[UIApplication.willResignActiveNotification.rawValue] =
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
                self?.exitWithoutPrompting()
        }
    }
    
    private func unsubscribeNotifications() {
        notificationObservers.values.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    private func setUpLabels() {
        headingLabel.textColor = Theme.primaryText
        headingLabel.font = Theme.h2Title
        headingLabel.text = S.RecoverKeyFlow.writeKeyScreenTitle
        headingLabel.textAlignment = .center
        headingLabel.numberOfLines = 0
        
        subheadingLabel.textColor = Theme.secondaryText
        subheadingLabel.font = Theme.body1
        subheadingLabel.text = S.RecoverKeyFlow.writeKeyScreenSubtitle
        subheadingLabel.textAlignment = .center
        subheadingLabel.numberOfLines = 0
        
        stepLabel.textColor = Theme.tertiaryText
        stepLabel.font = Theme.caption
        stepLabel.textAlignment = .center
    }
    
    private func setUpPagingViews() {
        
        //
        // create and add the word paging view first; the interaction paging view
        // will be above the word paging view so that the user can swipe the paging
        // view and we can scroll the word view proportionally
        //
        let wordPagingLayout = UICollectionViewFlowLayout()
        
        wordPagingLayout.sectionInset = .zero
        wordPagingLayout.minimumInteritemSpacing = 0
        wordPagingLayout.minimumLineSpacing = 0
        wordPagingLayout.scrollDirection = .horizontal

        let wordPaging = WordPagingCollectionView(frame: .zero, collectionViewLayout: wordPagingLayout)
        
        wordPaging.backgroundColor = Theme.primaryBackground
        wordPaging.delegate = self
        wordPaging.dataSource = self
        wordPaging.isScrollEnabled = true
        
        wordPaging.register(RecoveryWordCell.self, forCellWithReuseIdentifier: wordCellReuseId)
        wordPaging.register(UICollectionViewCell.self, forCellWithReuseIdentifier: blankCellReuseId)
        
        pagingViewContainer.addSubview(wordPaging)
        
        wordPaging.constrain([
            wordPaging.leftAnchor.constraint(equalTo: pagingViewContainer.leftAnchor, constant: -(wordPageWidth / 2)),
            wordPaging.rightAnchor.constraint(equalTo: pagingViewContainer.rightAnchor, constant: wordPageWidth / 2),
            wordPaging.topAnchor.constraint(equalTo: pagingViewContainer.topAnchor),
            wordPaging.bottomAnchor.constraint(equalTo: pagingViewContainer.bottomAnchor)
            ])
        
        //
        // create and add the interaction paging view above the word paging view
        //
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = .zero
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.scrollDirection = .horizontal
        
        let paging = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        paging.collectionViewLayout = layout
        paging.isPagingEnabled = true
        paging.isUserInteractionEnabled = true
        
        paging.delegate = self
        paging.dataSource = self
        
        let scrollView = paging as UIScrollView
        scrollView.delegate = self
        
        paging.register(UICollectionViewCell.self, forCellWithReuseIdentifier: pagingCellReuseId)
        
        pagingViewContainer.addSubview(paging)
        paging.constrain(toSuperviewEdges: .zero)
        
        interactionPagingView = paging
        wordPagingView = wordPaging
        
        paging.backgroundColor = .clear
        pagingViewContainer.backgroundColor = .clear
        
        paging.tag = interactionPagingViewTag
        wordPaging.tag = wordPagingViewTag
   }
    
    private func addSubviews() {
        view.addSubview(pagingViewContainer)
        view.addSubview(headingLabel)
        view.addSubview(subheadingLabel)
        view.addSubview(stepLabel)
        view.addSubview(infoView)
        view.addSubview(doneButton)
    }
    
    private func setUpConstraints() {
        pagingViewContainer.constrain([
            pagingViewContainer.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
            pagingViewContainer.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor),
            pagingViewContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pagingViewContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
        
        headingLabel.constrain([
            headingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            headingLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: headingLeftRightMargin),
            headingLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -headingLeftRightMargin),
            headingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: headingTopMargin)
            ])
        
        subheadingLabel.constrain([
            subheadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subheadingLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: headingLeftRightMargin),
            subheadingLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -headingLeftRightMargin),
            subheadingLabel.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: C.padding[2])
            ])
        
        stepLabel.constrain([
            stepLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stepLabel.topAnchor.constraint(equalTo: view.centerYAnchor, constant: stepLabelTopMargin)
            ])
        
        constrainContinueButton(doneButton)
        
        // The info view sits just above the Done button.
        infoView.constrain([
            infoView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: C.padding[2]),
            infoView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -C.padding[2]),
            infoView.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -C.padding[2])
            ])
    }
    
    private func updateStepLabel() {
        // this will generate a string such as "2 of 12"
        stepLabel.text = String(format: S.RecoverKeyFlow.writeKeyStepTitle, String(pageIndex + 1), String(pageCount))
    }
    
    private func updateInfoView() {
        infoView.text = (pageIndex == 0) ? S.RecoverKeyFlow.noScreenshotsOrEmailReminder : S.RecoverKeyFlow.rememberToWriteDownReminder
        infoView.imageName = (pageIndex == 0) ? "ExclamationMarkCircle" : "Document"
    }
    
    private func updateWordCellAppearances(pageScrollPercent: CGFloat) {
        if let cells = wordPagingView?.visibleCells {
            for cell in cells {
                if let wordCell = cell as? RecoveryWordCell {
                    wordCell.update(pagingPercent: pageScrollingPercent, currentPageIndex: pageIndex, scrollDirection: scrollDirection)
                }
            }
        }
    }
}

extension WriteRecoveryKeyViewController {
    
    func updateScrollDirection(_ offset: CGFloat) {
        if offset > lastScrollOffset {
            scrollDirection = .forward
        } else if offset < lastScrollOffset {
            scrollDirection = .backward
        } else {
            scrollDirection = .none
        }
        
        lastScrollOffset = offset
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Ignore scrolling by the word paging scrollview, because below we programmtically
        // scroll it.
        guard scrollView == interactionPagingView else {
            return
        }
        
        let xOffset = scrollView.contentOffset.x

        updateScrollDirection(xOffset)
        
        // Calculate the percent scrolled in the interaction paging collection view that
        // sits above the word paging collection view, and update the latter's content offset
        // by the same percent.
        let scrollPercent = (xOffset / totalScrollableWidth)
        let pagingScrollableWidth = (totalScrollableWidth / 2)
        let wordPagingOffset = (scrollPercent * pagingScrollableWidth)
        
        wordPagingView?.setContentOffset(CGPoint(x: wordPagingOffset, y: 0), animated: false)
        
        self.scrollOffset = xOffset
    }
    
    func trackEvent(event: Event, tracked: @escaping () -> Void) {
        if event == .dismissed {
            if mode == .generateKey {
                let metaData = [ "step": String(pageIndex + 1) ]
                saveEvent(context: eventContext, screen: .writePaperKey, event: event, attributes: metaData, callback: { _ in
                    tracked()
                })
            }
        } else {
            saveEvent(context: eventContext, screen: .writePaperKey, event: event, callback: { _ in
                tracked()
            })
        }
    }
    
}

extension WriteRecoveryKeyViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func wordCellAtIndex(_ index: Int) -> RecoveryWordCell? {
        if index >= 0 && index < pageCount {
            if let cell = wordPagingView?.cellForItem(at: IndexPath(item: index, section: 0)) as? RecoveryWordCell {
                return cell
            }
        }
        return nil
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (collectionView == wordPagingView) ? 13 : 12
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        switch collectionView.tag {
        case interactionPagingViewTag:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: pagingCellReuseId, for: indexPath)
            return cell
        case wordPagingViewTag:
            // starts with a blank cell so that the first word cell can scroll off to the left, leaving
            // it 50% visible
            if indexPath.item == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: blankCellReuseId, for: indexPath)
                return cell
            } else {
                let index = indexPath.item - 1  // account for blank cell above
                let word = words[index]
                let reuseId = wordCellReuseId
                
                if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseId, for: indexPath) as? RecoveryWordCell {
                    cell.configure(with: word, index: index)
                    cell.update(pagingPercent: pageScrollingPercent, currentPageIndex: pageIndex, scrollDirection: scrollDirection)
                    return cell
                }
            }
        default: break
        }

        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var width = scrollablePageWidth
        let height = collectionView.frame.height
        
        if collectionView == wordPagingView {
            width *= 0.5
        }
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }

}

//
// A cell in the word paging collection view. It displays a
//
class RecoveryWordCell: UICollectionViewCell {
    
    private let wordLabel = UILabel()
    private let wordTopConstraintPercent: CGFloat = 0.4
    
    let normalScale: CGFloat = 1.0
    let offScreenScale: CGFloat = 0.6
    let scaleRange: CGFloat = 0.4
    let smallScreenWordFont = UIFont(name: "CircularPro-Book", size: 32.0)
    var index: Int = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setUp() {
        wordLabel.textColor = Theme.primaryText
        wordLabel.font = E.isIPhone6OrSmaller ? smallScreenWordFont : Theme.h0Title
        wordLabel.textAlignment = .center
        wordLabel.adjustsFontSizeToFitWidth = true
        
        contentView.addSubview(wordLabel)
        
        let wordTopConstraintConstant = (contentView.frame.height * wordTopConstraintPercent)
        
        wordLabel.constrain([
            wordLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: wordTopConstraintConstant),
            wordLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: C.padding[1]),
            wordLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -C.padding[1])
            ])
        
        wordLabel.alpha = offScreenScale
    }

    func configure(with word: String, index: Int) {
        wordLabel.text = word
        self.index = index
    }
    
    // Adjusts the opacity and scale of the word label up or down to achieve fade-in/fade-out effects
    // as the user pages through the words.
    func update(pagingPercent: CGFloat,
                currentPageIndex: Int,
                scrollDirection: WriteRecoveryKeyViewController.ScrollDirection) {
        
        var scale = offScreenScale
        let delta = (scrollDirection == .forward) ? (pagingPercent * scaleRange) : ((1.0 - pagingPercent) * scaleRange)
        
        if pagingPercent > 0 {
            
            if scrollDirection == .forward {
                
                // next page, fading in from the right
                if index == (currentPageIndex + 1) {
                    scale = offScreenScale + delta
                // current page fading out to the left
                } else if index == currentPageIndex {
                    scale = normalScale - delta
                }
                
            } else if scrollDirection == .backward {
                
                // previous page, fading in from the left
                if index == currentPageIndex {
                    scale = offScreenScale + delta
                // current page fading out to the right
                } else if index == (currentPageIndex + 1) {
                    scale = normalScale - delta
                }
            }
            
        } else {
            scale = (index == currentPageIndex) ? normalScale : offScreenScale
        }
        
        wordLabel.alpha = scale
        wordLabel.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
    
}

// Subclass of UICollectionView to get around a bug where the content offset is
// bumped back half a page when a new view controller is pushed onto the stack.
//
// The problem is solved by intercepting attempts to modify the content offset
// once the new view controller has been pushed, using the 'obscured' property.
class WordPagingCollectionView: UICollectionView {
    
    var obscured: Bool = false {
        didSet {
            guard obscured else {
                savedContentOffset = nil
                return
            }
            savedContentOffset = contentOffset
        }
    }
    
    var savedContentOffset: CGPoint?
    
    override var contentOffset: CGPoint {
        set {
            guard obscured else {
                super.contentOffset = newValue
                return
            }
            super.contentOffset = savedContentOffset ?? newValue
        }
        
        get {
            guard obscured else {
                return super.contentOffset
            }
            return savedContentOffset ?? super.contentOffset
        }
    }
    
    func willDisappear() {
        obscured = true
    }
    
    func willAppear() {
        obscured = false
    }
    
}
