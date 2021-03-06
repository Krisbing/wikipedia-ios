import UIKit
import NotificationCenter
import YapDatabase
import WMFUI
import WMFModel

class WMFTodayTopReadWidgetViewController: UIViewController, NCWidgetProviding {
    
    // Model
    let siteURL = NSURL.wmf_URLWithDefaultSiteAndCurrentLocale()
    var date = NSDate()
    var results: [MWKSearchResult] = []
    let articlePreviewFetcher = WMFArticlePreviewFetcher()
    let mostReadFetcher = WMFMostReadTitleFetcher()
    let dataStore: MWKDataStore = SessionSingleton.sharedInstance().dataStore
    let shortDateFormatter = NSDateFormatter.wmf_englishHyphenatedYearMonthDayFormatter()
    let numberFormatter = NSNumberFormatter()
    



    // Views & View State
    @IBOutlet weak var snapshotContainerView: UIView!
    var snapshotView: UIView?
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var footerLabel: UILabel!
    
    @IBOutlet weak var footerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var footerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var headerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var headerViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet var stackViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var snapshotTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var snapshotHeightConstraint: NSLayoutConstraint!
    
    
    @IBOutlet weak var stackView: UIStackView!
    
    let dateFormatter = NSDateFormatter.wmf_dayNameMonthNameDayOfMonthNumberDateFormatter()
    let cellReuseIdentifier = "articleList"
    
    var maximumSize = CGSizeZero
    var maximumRowCount = 3
    
    var footerVisible = true
    
    var headerVisible = true
    
    var hideStackViewOnNextLayout = false
    var displayMode: NCWidgetDisplayMode = .Expanded
    
    // Controllers
    var articlePreviewViewControllers: [WMFArticlePreviewViewController] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        numberFormatter.numberStyle = .DecimalStyle
        headerLabel.text = nil
        footerLabel.text = nil
        headerLabel.textColor = UIColor.wmf_darkGray()
        footerLabel.textColor = UIColor.wmf_darkGray()
        
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGestureRecognizer(_:)))
        
        view.addGestureRecognizer(tapGR)
        
        if let context = self.extensionContext {
            context.widgetLargestAvailableDisplayMode = .Expanded
            displayMode = context.widgetActiveDisplayMode
            maximumSize = context.widgetMaximumSizeForDisplayMode(displayMode)
            updateViewPropertiesForActiveDisplayMode(displayMode)
            layoutForSize(view.bounds.size)
        }
        
        widgetPerformUpdate { (result) in
            
        }
    }
    
    func layoutForSize(size: CGSize) {
        let headerHeight = headerViewHeightConstraint.constant
        let footerHeight = footerViewHeightConstraint.constant
        headerViewTopConstraint.constant = headerVisible ? 0 : 0 - headerHeight
        stackViewTopConstraint.constant = headerVisible ? headerHeight : 0
        stackViewWidthConstraint.constant = size.width
        footerViewBottomConstraint.constant = footerVisible ? 0 : 0 - footerHeight
        var stackViewHeight = size.height
        if headerVisible {
            stackViewHeight -= headerHeight
        }
        if footerVisible {
            stackViewHeight -= footerHeight
        }
        stackViewHeightConstraint.constant = stackViewHeight

        snapshotTopConstraint.constant = headerVisible ? stackViewTopConstraint.constant : headerViewTopConstraint.constant
        
        footerView.alpha = footerVisible ? 1 : 0
        headerView.alpha = headerVisible ? 1 : 0
        
        view.layoutIfNeeded()
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        if hideStackViewOnNextLayout {
            stackView.alpha = 0
            hideStackViewOnNextLayout = false
        }
        coordinator.animateAlongsideTransition({ (context) in
            self.snapshotView?.alpha = 0
            self.stackView.alpha = 1
            self.layoutForSize(size)
            }) { (context) in
                if (!context.isAnimated()) {
                    self.layoutForSize(size)
                    self.stackView.alpha = 1
                }
                
                self.snapshotView?.removeFromSuperview()
                self.snapshotView = nil
        }
    }
    
    func updateViewPropertiesForActiveDisplayMode(activeDisplayMode: NCWidgetDisplayMode){
        displayMode = activeDisplayMode
        headerVisible = activeDisplayMode != .Compact
        footerVisible = headerVisible
        maximumRowCount = activeDisplayMode == .Compact ? 1 : 3
    }
    
    func widgetActiveDisplayModeDidChange(activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        maximumSize = maxSize
        if (activeDisplayMode != displayMode) {
            updateViewPropertiesForActiveDisplayMode(activeDisplayMode)
            updateView()
        }
    }
    
    func updateView() {
        let count = min(results.count, maximumRowCount)
        guard count > 0 else {
            return
        }
        headerLabel.text = dateFormatter.stringFromDate(date).uppercaseString
        footerLabel.text = localizedStringForKeyFallingBackOnEnglish("top-read-see-more-trending").uppercaseString
        var i = 0
        var didRemove = false
        var didAdd = false
        let newSnapshot = view.snapshotViewAfterScreenUpdates(false)
        while i < count {
            var vc: WMFArticlePreviewViewController
            if (i < articlePreviewViewControllers.count) {
                vc = articlePreviewViewControllers[i]
            } else {
                vc = WMFArticlePreviewViewController()
                articlePreviewViewControllers.append(vc)
            }
            if vc.parentViewController == nil {
                addChildViewController(vc)
                stackView.addArrangedSubview(vc.view)
                vc.didMoveToParentViewController(self)
                didAdd = true
            }
            let result = results[i]
            vc.titleLabel.text = result.displayTitle
            vc.subtitleLabel.text = result.wikidataDescription
            vc.imageView.wmf_reset()
            vc.rankLabel.text = numberFormatter.stringFromNumber(i + 1)
            if let imageURL = result.thumbnailURL {
                vc.imageView.wmf_setImageWithURL(imageURL, detectFaces: true, onGPU: true, failure: WMFIgnoreErrorHandler, success: WMFIgnoreSuccessHandler)
            }
            if i == (count - 1) {
                vc.separatorView.hidden = true
            } else {
                vc.separatorView.hidden = false
            }
            i += 1
        }
        while i < articlePreviewViewControllers.count {
            let vc = articlePreviewViewControllers[i]
            if vc.parentViewController != nil {
                vc.willMoveToParentViewController(nil)
                vc.view.removeFromSuperview()
                stackView.removeArrangedSubview(vc.view)
                vc.removeFromParentViewController()
                didRemove = true
            }
            i += 1
        }
        
        if didAdd {
            hideStackViewOnNextLayout = true
        }
        
        stackViewHeightConstraint.active = false
        stackViewWidthConstraint.constant = maximumSize.width
        var sizeToFit = UILayoutFittingCompressedSize
        sizeToFit.width = maximumSize.width
        var size = stackView.systemLayoutSizeFittingSize(sizeToFit, withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityDefaultLow)
        size.width = maximumSize.width
        stackViewHeightConstraint.active = true
        
        let headerHeight = headerViewHeightConstraint.constant
        let footerHeight = footerViewHeightConstraint.constant
        
        if headerVisible {
            size.height += headerHeight
        }
        
        if footerVisible {
            size.height += footerHeight
        }

        stackViewHeightConstraint.constant = size.height
    
        footerView.alpha = footerVisible ? 0 : 1
        footerViewBottomConstraint.constant = footerVisible ? 0 - footerHeight : 0
        
        snapshotTopConstraint.constant = 0
        snapshotHeightConstraint.constant = view.bounds.size.height
        
        preferredContentSize = size
        view.layoutIfNeeded()
        
        if let snapshot = newSnapshot where didRemove || didAdd {
            snapshot.frame = snapshotContainerView.bounds
            snapshotContainerView.addSubview(snapshot)
            snapshotView?.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(.FlexibleHeight)
            snapshotView = snapshot
        }
    }

    func widgetPerformUpdate(completionHandler: ((NCUpdateResult) -> Void)) {
        date = NSDate().wmf_bestMostReadFetchDate()
        fetchForDate(date, siteURL: siteURL, completionHandler: completionHandler)
    }
    
    func fetchForDate(date: NSDate, siteURL: NSURL, completionHandler: ((NCUpdateResult) -> Void)) {
        guard let host = siteURL.host else {
            completionHandler(.NoData)
            return
        }
        let databaseKey = shortDateFormatter.stringFromDate(date)
        let databaseCollection = "wmftopread:\(host)"
        
        dataStore.readWithBlock { (transaction) in
            guard let results = transaction.objectForKey(databaseKey, inCollection: databaseCollection) as? [MWKSearchResult] else {
                dispatch_async(dispatch_get_main_queue(), {
                    self.fetchRemotelyAndStoreInDatabaseCollection(databaseCollection, databaseKey: databaseKey, completionHandler: completionHandler)
                    })
                return
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.results = results
                self.updateView()
                completionHandler(.NewData)
            })
        }
    }
    
    func fetchRemotelyAndStoreInDatabaseCollection(databaseCollection: String, databaseKey: String, completionHandler: ((NCUpdateResult) -> Void)) {
        mostReadFetcher.fetchMostReadTitlesForSiteURL(siteURL, date: date).then { (result) -> AnyPromise in
            
            guard let mostReadTitlesResponse = result as? WMFMostReadTitlesResponseItem else {
                completionHandler(.NoData)
                return AnyPromise(value: nil)
            }
            
            let articleURLs = mostReadTitlesResponse.articles.map({ (article) -> NSURL in
                return self.siteURL.wmf_URLWithTitle(article.titleText)
            })
            
            return self.articlePreviewFetcher.fetchArticlePreviewResultsForArticleURLs(articleURLs, siteURL: self.siteURL, extractLength: 0, thumbnailWidth: UIScreen.mainScreen().wmf_listThumbnailWidthForScale().unsignedIntegerValue)
            }.then { (result) -> AnyPromise in
                guard let articlePreviewResponse = result as? [MWKSearchResult] else {
                    completionHandler(.NoData)
                    return AnyPromise(value: nil)
                }
                
                let results =  articlePreviewResponse.filter({ (result) -> Bool in
                    return result.articleID != 0
                })
                
                self.results = results
                
                self.updateView()
                completionHandler(.NewData)
                
                self.dataStore.readWriteWithBlock({ (conn) in
                    conn.setObject(results, forKey: databaseKey, inCollection: databaseCollection)
                })

                return AnyPromise(value: articlePreviewResponse)
        }
    }
    
    func handleTapGestureRecognizer(gestureRecognizer: UITapGestureRecognizer) {
        guard let index = self.articlePreviewViewControllers.indexOf({ (vc) -> Bool in return CGRectContainsPoint(vc.view.frame, gestureRecognizer.locationInView(self.view)) }) where index < results.count else {
            guard let siteURLString = siteURL.absoluteString, let URL = NSUserActivity.wmf_URLForActivityOfType(.TopRead, parameters: ["timestamp": date.timeIntervalSince1970, "siteURL":siteURLString]) else {
                return
            }
            self.extensionContext?.openURL(URL, completionHandler: { (success) in
                
            })
            return
        }
        
        let result = results[index]
        let URL = siteURL.wmf_URLWithTitle(result.displayTitle)
        self.extensionContext?.openURL(URL, completionHandler: { (success) in
            
        })
    }
    
}
