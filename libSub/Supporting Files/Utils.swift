//
//  Utils.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

public func printError(error: Any) {
    print("[\(__FILE__):\(__LINE__) \(__FUNCTION__)] \(error)")
}

// Returns NSNull if the input is nil. Useful for things like db queries.
// TODO: Figure out why FMDB in Swift won't take nil arguments in var args functions
public func n2N(nullableObject: AnyObject?) -> AnyObject {
    return nullableObject == nil ? NSNull() : nullableObject!
}