/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Foundation

/**
 * The keyboard state at the time of notification.
 */
public struct KeyboardState {
    public let animationDuration: Double
    public let animationCurve: UIViewAnimationCurve
    private let userInfo: [AnyHashable: Any]

    fileprivate init(_ userInfo: [AnyHashable: Any]) {
        self.userInfo = userInfo
        animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! Double
        // HACK: UIViewAnimationCurve doesn't expose the keyboard animation used (curveValue = 7),
        // so UIViewAnimationCurve(rawValue: curveValue) returns nil. As a workaround, get a
        // reference to an EaseIn curve, then change the underlying pointer data with that ref.
        var curve = UIViewAnimationCurve.easeIn
        if let curveValue = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? Int {
            NSNumber(value: curveValue).getValue(&curve)
        }
        self.animationCurve = curve
    }

    /// Return the height of the keyboard that overlaps with the specified view. This is more
    /// accurate than simply using the height of UIKeyboardFrameBeginUserInfoKey since for example
    /// on iPad the overlap may be partial or if an external keyboard is attached, the intersection
    /// height will be zero. (Even if the height of the *invisible* keyboard will look normal!)
    public func intersectionHeightForView(view: UIView) -> CGFloat {
        if let keyboardFrameValue = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardFrame = keyboardFrameValue.cgRectValue
            let convertedKeyboardFrame = view.convert(keyboardFrame, from: nil)
            let intersection = convertedKeyboardFrame.intersection(view.bounds)
            return intersection.size.height
        }
        return 0
    }
}

public protocol KeyboardHelperDelegate: class {
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillShowWithState state: KeyboardState)
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardDidShowWithState state: KeyboardState)
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillHideWithState state: KeyboardState)
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardDidHideWithState state: KeyboardState)
}

/**
 * Convenience class for observing keyboard state.
 */
public class KeyboardHelper: NSObject {
    public var currentState: KeyboardState?

    private var delegates = [WeakKeyboardDelegate]()

    public class var defaultHelper: KeyboardHelper {
        struct Singleton {
            static let instance = KeyboardHelper()
        }
        return Singleton.instance
    }

    /**
     * Starts monitoring the keyboard state.
     */
    public func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /**
     * Adds a delegate to the helper.
     * Delegates are weakly held.
     */
    public func addDelegate(delegate: KeyboardHelperDelegate) {
        for weakDelegate in delegates {
            // Reuse any existing slots that have been deallocated.
            if weakDelegate.delegate == nil {
                weakDelegate.delegate = delegate
                return
            }
        }

        delegates.append(WeakKeyboardDelegate(delegate))
    }

    func keyboardWillShow(notification: NSNotification) {
        if let userInfo: [AnyHashable: Any] = notification.userInfo {
            currentState = KeyboardState(userInfo)
            for weakDelegate in delegates {
                weakDelegate.delegate?.keyboardHelper(self, keyboardWillShowWithState: currentState!)
            }
        }
    }

    func keyboardDidShow(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            currentState = KeyboardState(userInfo)
            for weakDelegate in delegates {
                weakDelegate.delegate?.keyboardHelper(self, keyboardDidShowWithState: currentState!)
            }
        }
    }

    func keyboardWillHide(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            currentState = KeyboardState(userInfo)
            for weakDelegate in delegates {
                weakDelegate.delegate?.keyboardHelper(self, keyboardWillHideWithState: currentState!)
            }
        }
    }

    func keyboardDidHide(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            currentState = KeyboardState(userInfo)
            for weakDelegate in delegates {
                weakDelegate.delegate?.keyboardHelper(self, keyboardDidHideWithState: currentState!)
            }
        }
    }
}

private class WeakKeyboardDelegate {
    weak var delegate: KeyboardHelperDelegate?

    init(_ delegate: KeyboardHelperDelegate) {
        self.delegate = delegate
    }
}
