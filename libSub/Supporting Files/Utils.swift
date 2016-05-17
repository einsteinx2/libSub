//
//  Utils.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

public func printError(error: Any, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = NSURL(fileURLWithPath: file).URLByDeletingPathExtension?.lastPathComponent
    let functionName = function.componentsSeparatedByString("(").first
    
    if let fileName = fileName, functionName = functionName {
        print("[\(fileName):\(line) \(functionName)] \(error)")
    } else {
        print("[\(file):\(line) \(function)] \(error)")
    }
}

// Returns NSNull if the input is nil. Useful for things like db queries.
// TODO: Figure out why FMDB in Swift won't take nil arguments in var args functions
public func n2N(nullableObject: AnyObject?) -> AnyObject {
    return nullableObject == nil ? NSNull() : nullableObject!
}