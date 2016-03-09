//
//  Utils.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

// Returns NSNull if the input is nil. Useful for things like db queries.
// TODO: Figure out why FMDB in Swift won't take nil arguments in var args functions
func n2N(nullableObject: AnyObject?) -> AnyObject {
    return nullableObject == nil ? NSNull() : nullableObject!
}