//
//  AssociatedObject.swift
//  Segment
//
//  Created by Brandon Sneed on 12/7/20.
//

import Foundation
import Sovran

public final class AssociatedObject<T: Any> {
    fileprivate var __association = __AssociatedObject()
    
    public subscript(index: Any) -> T? {
        get {
            let address = String(format: "%p_%@", unsafeBitCast(self, to: Int.self), "\(T.self)")
            let value = __association.__objects[address] as? T
            return value
        }
        set(newValue) {
            let address = String(format: "%p_%@", unsafeBitCast(self, to: Int.self), "\(T.self)")
            __association.__objects[address] = newValue
        }
    }
}

private struct __AssociatedObject {
    internal var __objects = [String: Any]()
}

// Example usage:

class MyObject {
    
}

extension MyObject {
    private static let myStore = AssociatedObject<Store>()
    
    func test() {
        let state: UserInfo? = MyObject.myStore[self]?.currentState()
        if state != nil {
            print("we got it")
        } else {
            print("we didn't get it")
        }
    }
}


/*
extension UIViewController {
    private static var _myComputedProperty = [String:Bool]()
    
    var myComputedProperty:Bool {
        get {
            let tmpAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
            return UIViewController._myComputedProperty[tmpAddress] ?? false
        }
        set(newValue) {
            let tmpAddress = String(format: "%p", unsafeBitCast(self, to: Int.self))
            UIViewController._myComputedProperty[tmpAddress] = newValue
        }
    }
}
*/
