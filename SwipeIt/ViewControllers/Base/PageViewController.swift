//
//  PageViewController.swift
//  Reddit
//
//  Created by Ivan Bruel on 02/05/16.
//  Copyright © 2016 Faber Ventures. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

// MARK: PageViewControllerDelegate
public protocol PageViewControllerDelegate {

  // Called when the view controller changes to another page
  func pageViewController(pageViewController: PageViewController, didTransitionToIndex: Int)

  // Called when the view controller prepares for a segue, to allow parent view controller to inject
  // properties into child view controller
  func pageViewController(pageViewController: PageViewController,
                          prepareForSegue segue: UIStoryboardSegue, sender: AnyObject?)

}

public class PageViewController: UIPageViewController {

  // Dynamic so it can be observable
  private dynamic var _selectedIndex: Int = 0

  public var selectedIndex: Int {
    get {
      return _selectedIndex
    }
    set {
      setSelectedIndex(newValue, animated: true)
    }
  }

  public var pageViewControllers: [UIViewController] = []

  public var pageViewControllerDelegate: PageViewControllerDelegate?

  override init(transitionStyle style: UIPageViewControllerTransitionStyle,
                                navigationOrientation: UIPageViewControllerNavigationOrientation,
                                options: [String : AnyObject]?) {

    super.init(transitionStyle: style, navigationOrientation: navigationOrientation,
               options: options)
    commonSetup()
  }

  required public init?(coder: NSCoder) {
    super.init(coder: coder)
    commonSetup()
  }

  private func commonSetup() {
    self.dataSource = self
    self.delegate = self
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    performPageSegues()
  }

  // A very hacky way to automatically perform segues defined in the storyboard
  // storyboardSegueTemplates has a property named segueClassName which contains the mangled name
  // for the Segue's class e.g. 't3gdxPageSegue'; it also has the identifier property to perform
  // the segue with identifier call.
  private func performPageSegues() {
    guard let segueTemplates = valueForKey("storyboardSegueTemplates") as? [AnyObject] else {
      return
    }

    segueTemplates
      .filter {
        ($0.valueForKey("segueClassName") as? String)?.containsString("PageSegue") ?? false
      }.flatMap { $0.valueForKey("identifier") as? String }
      .forEach { self.performSegueWithIdentifier($0, sender: nil) }
  }

  public func setSelectedIndex(index: Int, animated: Bool) {
    guard index < pageViewControllers.count else {
      return
    }
    let viewController = pageViewControllers[index]
    setViewControllers([viewController],
                       direction: (index > _selectedIndex ? .Forward : .Reverse),
                       animated: animated, completion: nil)
  }

}

// MARK: UIPageViewControllerDelegate,
extension PageViewController: UIPageViewControllerDelegate {

  public func pageViewController(pageViewController: UIPageViewController,
                                 didFinishAnimating finished: Bool,
                                                    previousViewControllers: [UIViewController],
                                                    transitionCompleted completed: Bool) {
    guard let viewController = pageViewController.viewControllers?.last,
      index = pageViewControllers.indexOf(viewController)
      where finished && completed else {
        return
    }
    _selectedIndex = index
    pageViewControllerDelegate?.pageViewController(self, didTransitionToIndex: index)
  }
}

// MARK: UIPageViewControllerDataSource
extension PageViewController: UIPageViewControllerDataSource {

  public func pageViewController(
    pageViewController: UIPageViewController,
    viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
    guard let index = pageViewControllers.indexOf(viewController) where index - 1 >= 0 else {
      return nil
    }
    return pageViewControllers[index - 1]
  }

  public func pageViewController(pageViewController: UIPageViewController,
                                 viewControllerAfterViewController viewController: UIViewController)
    -> UIViewController? {
      guard let index = pageViewControllers.indexOf(viewController)
        where index + 1 < pageViewControllers.count else {
          return nil
      }
      return pageViewControllers[index + 1]
  }

}

// MARK: Segue
extension PageViewController {

  override public func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    pageViewControllerDelegate?.pageViewController(self, prepareForSegue: segue, sender: sender)
  }

}

// MARK: Rx Bindings
// swiftlint:disable variable_name
extension PageViewController {

  public var rx_selectedIndex: ControlProperty<Int> {
    let source: Observable<Int> = Observable.deferred { [weak self] () -> Observable<Int> in
      return (self?.rx_observe(Int.self, "_selectedIndex") ?? Observable.empty())
        .map { index in
          index ?? 0
      }
    }

    let bindingObserver = UIBindingObserver(UIElement: self) {
      (pageViewController, selectedIndex: Int) in
      pageViewController.selectedIndex = selectedIndex
    }

    return ControlProperty(values: source, valueSink: bindingObserver)
  }
}

// MARK: PageSegue
public class PageSegue: UIStoryboardSegue {

  override init(identifier: String?, source: UIViewController, destination: UIViewController) {
    super.init(identifier: identifier, source: source, destination: destination)

    if let pageViewController = source as? PageViewController {
      var viewControllers = pageViewController.pageViewControllers ?? []
      viewControllers.append(destination)
      pageViewController.pageViewControllers = viewControllers
    }
  }

  override public func perform() { }
}
