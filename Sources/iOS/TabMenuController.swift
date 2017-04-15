/*
 * Copyright (C) 2015 - 2017, Daniel Dahan and CosmicMind, Inc. <http://cosmicmind.com>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *	*	Redistributions of source code must retain the above copyright notice, this
 *		list of conditions and the following disclaimer.
 *
 *	*	Redistributions in binary form must reproduce the above copyright notice,
 *		this list of conditions and the following disclaimer in the documentation
 *		and/or other materials provided with the distribution.
 *
 *	*	Neither the name of CosmicMind nor the names of its
 *		contributors may be used to endorse or promote products derived from
 *		this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit

/// A memory reference to the TabMenuBarItem instance for UIViewController extensions.
fileprivate var TabMenuBarItemKey: UInt8 = 0

open class TabMenuBarItem: FlatButton {
    open override func prepare() {
        super.prepare()
        pulseAnimation = .none
    }
}

@objc(TabMenuAlignment)
public enum TabMenuAlignment: Int {
    case top
    case bottom
    case hidden
}

extension UIViewController {
    /// tabMenuBarItem reference.
    public private(set) var tabMenuBarItem: TabMenuBarItem {
        get {
            return AssociatedObject(base: self, key: &TabMenuBarItemKey) {
                return TabMenuBarItem()
            }
        }
        set(value) {
            AssociateObject(base: self, key: &TabMenuBarItemKey, value: value)
        }
    }
}

extension UIViewController {
    /**
     A convenience property that provides access to the TabMenuController.
     This is the recommended method of accessing the TabMenuController
     through child UIViewControllers.
     */
    public var tabMenuBarController: TabMenuController? {
        var viewController: UIViewController? = self
        while nil != viewController {
            if viewController is TabMenuController {
                return viewController as? TabMenuController
            }
            viewController = viewController?.parent
        }
        return nil
    }
}

open class TabMenuController: UIViewController {
    /// A reference to the currently selected view controller index value.
    @IBInspectable
    open var selectedIndex = 0
    
    /// Enables and disables bouncing when swiping.
    open var isBounceEnabled: Bool {
        get {
            return scrollView.bounces
        }
        set(value) {
            scrollView.bounces = value
        }
    }
    
    /// The TabBar used to switch between view controllers.
    @IBInspectable
    open fileprivate(set) var tabBar: TabBar?
    
    /// The UIScrollView used to pan the application pages.
    @IBInspectable
    open let scrollView = UIScrollView()
    
    /// Previous scroll view content offset.
    fileprivate var previousContentOffset: CGFloat = 0
    
    /// An Array of UIViewControllers.
    open var viewControllers: [UIViewController] {
        didSet {
            oldValue.forEach { [weak self] in
                self?.removeViewController(viewController: $0)
            }
            
            prepareViewControllers()
            layoutSubviews()
        }
    }
    
    open var tabMenuAlignment = TabMenuAlignment.bottom {
        didSet {
            layoutSubviews()
        }
    }
    
    /// The number of views used in the scrollViewPool.
    fileprivate let viewPoolCount = 3
    
    /**
     An initializer that initializes the object with a NSCoder object.
     - Parameter aDecoder: A NSCoder instance.
     */
    public required init?(coder aDecoder: NSCoder) {
        viewControllers = []
        super.init(coder: aDecoder)
    }
    
    /**
     An initializer that accepts an Array of UIViewControllers.
     - Parameter viewControllers: An Array of UIViewControllers.
     */
    public init(viewControllers: [UIViewController], selectedIndex: Int = 0) {
        self.viewControllers = viewControllers
        self.selectedIndex = selectedIndex
        super.init(nibName: nil, bundle: nil)
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
    }
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layoutSubviews()
    }
    
    /**
     To execute in the order of the layout chain, override this
     method. `layoutSubviews` should be called immediately, unless you
     have a certain need.
     */
    open func layoutSubviews() {
        layoutScrollView()
        layoutViewControllers()
    
        let p = (tabBar?.intrinsicContentSize.height ?? 0) + (tabBar?.layoutEdgeInsets.top ?? 0) + (tabBar?.layoutEdgeInsets.bottom ?? 0)
        let y = view.height - p
        
        tabBar?.height = p
        tabBar?.width = view.width + (tabBar?.layoutEdgeInsets.left ?? 0) + (tabBar?.layoutEdgeInsets.right ?? 0)
        
        switch tabMenuAlignment {
        case .top:
            tabBar?.isHidden = false
            tabBar?.y = 0
            scrollView.y = p
            scrollView.height = y
        case .bottom:
            tabBar?.isHidden = false
            tabBar?.y = y
            scrollView.y = 0
            scrollView.height = y
        case .hidden:
            tabBar?.isHidden = true
            scrollView.y = 0
            scrollView.height = view.height
        }
    }
    
    /**
     Prepares the view instance when intialized. When subclassing,
     it is recommended to override the prepare method
     to initialize property values and other setup operations.
     The super.prepare method should always be called immediately
     when subclassing.
     */
    open func prepare() {
        prepareScrollView()
        prepareViewControllers()
    }
}

extension TabMenuController {
    /// Prepares the scrollView used to pan through view controllers.
    fileprivate func prepareScrollView() {
        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
    }
    
    /// Prepares the view controllers.
    fileprivate func prepareViewControllers() {
        let n = viewControllers.count
        
        guard 1 < n else {
            if 1 == n {
                prepareViewController(at: 0)
            }
            return
        }
        
        let m = viewPoolCount < n ? viewPoolCount : n
        
        if 0 == selectedIndex {
            for i in 0..<m {
                prepareViewController(at: i)
            }
        } else if n - 1 == selectedIndex {
            for i in 0..<m {
                prepareViewController(at: selectedIndex - i)
            }
        } else {
            prepareViewController(at: selectedIndex)
            prepareViewController(at: selectedIndex - 1)
            prepareViewController(at: selectedIndex + 1)
        }
        
        prepareTabBar()
    }
    
    /**
     Prepares the tabBar buttons.
     - Parameter _ buttons: An Array of UIButtons.
     */
    fileprivate func prepareTabBarButtons(_ buttons: [UIButton]) {
        guard let tb = tabBar else {
            return
        }
        
        tb.buttons = buttons
        
        for v in tb.buttons {
            v.removeTarget(self, action: #selector(tb.handleButton(button:)), for: .touchUpInside)
            v.removeTarget(self, action: #selector(handleTabBarButton(button:)), for: .touchUpInside)
            v.addTarget(self, action: #selector(handleTabBarButton(button:)), for: .touchUpInside)
        }
    }
    
    fileprivate func prepareTabBar() {
        guard 0 < viewControllers.count else {
            tabBar = nil
            return
        }
        
        var buttons = [UIButton]()
        
        for v in viewControllers {
            let button = v.tabMenuBarItem as UIButton
            buttons.append(button)
        }
        
        guard 0 < buttons.count else {
            tabBar = nil
            return
        }
        
        guard nil == tabBar else {
            prepareTabBarButtons(buttons)
            return
        }
        
        tabBar = TabBar()
        tabBar?.isLineAnimated = false
        tabBar?.lineAlignment = .top
        view.addSubview(tabBar!)
        prepareTabBarButtons(buttons)
    }
    
    /**
     Loads a view controller based on its index in the viewControllers Array
     and adds it as a child view controller.
     - Parameter at index: An Int for the viewControllers index.
     */
    fileprivate func prepareViewController(at index: Int) {
        let vc = viewControllers[index]
        
        guard !childViewControllers.contains(vc) else {
            return
        }
        
        addChildViewController(vc)
        vc.didMove(toParentViewController: self)
        vc.view.clipsToBounds = true
        vc.view.contentScaleFactor = Screen.scale
        scrollView.addSubview(vc.view)
    }
}

extension TabMenuController {
    fileprivate func layoutScrollView() {
        scrollView.frame = view.bounds
        scrollView.contentSize = CGSize(width: scrollView.width * CGFloat(viewControllers.count), height: scrollView.height)
        scrollView.contentOffset = CGPoint(x: scrollView.width * CGFloat(selectedIndex), y: 0)
    }
    
    fileprivate func layoutViewControllers() {
        let n = viewControllers.count
        scrollView.contentSize = CGSize(width: scrollView.width * CGFloat(n), height: scrollView.height)
        
        guard 1 < n else {
            layoutViewController(at: 0, position: 0)
            return
        }
        
        let m = viewPoolCount < n ? viewPoolCount : n
        
        if 0 == selectedIndex {
            for i in 0..<m {
                layoutViewController(at: i, position: i)
            }
        } else if n - 1 == selectedIndex {
            var q = 0
            for i in 0..<m {
                q = selectedIndex - i
                layoutViewController(at: q, position: q)
            }
        } else {
            layoutViewController(at: selectedIndex, position: selectedIndex)
            layoutViewController(at: selectedIndex - 1, position: selectedIndex - 1)
            layoutViewController(at: selectedIndex + 1, position: selectedIndex + 1)
        }
    }
    
    /**
     Positions a view controller within the scrollView.
     - Parameter position: An Int for the position of the view controller.
     */
    fileprivate func layoutViewController(at index: Int, position: Int) {
        guard 0 <= index && index < viewControllers.count else {
            return
        }
        
        viewControllers[index].view.frame = CGRect(x: CGFloat(position) * scrollView.width, y: 0, width: scrollView.width, height: scrollView.height)
    }
}

extension TabMenuController {
    /// Removes the view controllers not within the scrollView.
    fileprivate func removeViewControllers() {
        let n = viewControllers.count
        
        guard 1 < n else {
            return
        }
        
        if 0 == selectedIndex {
            for i in 1..<n {
                removeViewController(at: i)
            }
        } else if n - 1 == selectedIndex {
            for i in 0..<n - 2 {
                removeViewController(at: i)
            }
        } else {
            for i in 0..<selectedIndex {
                removeViewController(at: i)
            }
            
            let x = selectedIndex + 1
            
            if x < n {
                for i in x..<n {
                    removeViewController(at: i)
                }
            }
        }
    }
    
    /**
     Removes the view controller as a child view controller with
     the given index.
     - Parameter at index: An Int for the view controller position.
     */
    fileprivate func removeViewController(at index: Int) {
        let vc = viewControllers[index]
        
        guard childViewControllers.contains(vc) else {
            return
        }
        
        removeViewController(viewController: vc)
    }
    
    /**
     Removes a given view controller from the childViewControllers array.
     - Parameter at index: An Int for the view controller position.
     */
    fileprivate func removeViewController(viewController: UIViewController) {
        viewController.willMove(toParentViewController: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParentViewController()
    }
}

extension TabMenuController {
    /**
     Handles the pageTabBarButton.
     - Parameter button: A UIButton.
     */
    @objc
    fileprivate func handleTabBarButton(button: UIButton) {
        guard let tb = tabBar else {
            return
        }
        
        guard let i = tb.buttons.index(of: button) else {
            return
        }
        
        guard i != selectedIndex else {
            return
        }
        
        selectedIndex = i
        
        removeViewControllers()
        prepareViewControllers()
        layoutViewControllers()
    }
}

extension TabMenuController: UIScrollViewDelegate {
    @objc
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let tb = tabBar else {
            return
        }
        
        guard tb.isAnimating else {
            return
        }
        
//        guard let selected = tb.selected else {
//            return
//        }
        
//        let x = (scrollView.contentOffset.x - scrollView.width) / scrollView.contentSize.width * scrollView.width
//        tb.line.center.x = selected.center.x + x
    }
    
    @objc
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        previousContentOffset = scrollView.contentOffset.x
    }
    
    @objc
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let n = viewControllers.count
        let x = scrollView.contentOffset.x
        let p = previousContentOffset == x ? 0 : previousContentOffset < x ? 1 : -1
        
        guard 0 != p else {
            return
        }
        
        let i = selectedIndex + p
        
        guard selectedIndex != i else {
            return
        }
        
        guard 0 <= i && i < n else {
            return
        }
        
        selectedIndex = i
        
        removeViewControllers()
        prepareViewControllers()
        layoutViewControllers()
    }
}