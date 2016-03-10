//
//  SectionIndex.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

public class SectionIndex {
    public var firstIndex: Int
    public var sectionCount: Int
    public var letter: Character
    
    init (firstIndex: Int, sectionCount: Int, letter: Character) {
        self.firstIndex = firstIndex
        self.sectionCount = sectionCount
        self.letter = letter
    }
}

public func sectionIndexesForItems(items: [ISMSItem]?) -> [SectionIndex] {
    guard let items = items else {
        return []
    }
    
    func isDigit(c: Character) -> Bool {
        let cset = NSCharacterSet.decimalDigitCharacterSet()
        let s = String(c)
        let ix = s.startIndex
        let ix2 = s.endIndex
        let result = s.rangeOfCharacterFromSet(cset, options: [], range: ix..<ix2)
        return result != nil
    }
    
    func ignoredArticles() -> [String] {
        var ignoredArticles = [String]()
        
        DatabaseSingleton.sharedInstance().songModelReadDbPool.inDatabase { db in
            do {
                let query = "SELECT name FROM ignoredArticles"
                let result = try db.executeQuery(query)
                while result.next() {
                    ignoredArticles.append(result.stringForColumnIndex(0))
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        return ignoredArticles
    }
    
    func nameIgnoringArticles(name name: String, articles: [String]) -> String {
        if articles.count > 0 {
            for article in articles {
                let articlePlusSpace = article + " "
                if name.hasPrefix(articlePlusSpace) {
                    let index = name.startIndex.advancedBy(articlePlusSpace.characters.count)
                    return name.substringFromIndex(index)
                }
            }
        }
        
        return (name as NSString).stringWithoutIndefiniteArticle()
    }
    
    var sectionIndexes: [SectionIndex] = []
    var lastFirstLetter: Character? = nil
    let articles = ignoredArticles()
    
    var index: Int = 0
    var count: Int = 0
    for item in items {
        if (item.itemName != nil) {
            let name = nameIgnoringArticles(name: item.itemName!, articles: articles)
            var firstLetter = Array(name.uppercaseString.characters)[0]
            
            // Sort digits to the end in a single "#" section
            if isDigit(firstLetter) {
                firstLetter = "#"
            }
            
            if lastFirstLetter == nil {
                lastFirstLetter = firstLetter
                sectionIndexes.append(SectionIndex(firstIndex: 0, sectionCount: 0, letter: firstLetter))
            }
            
            if lastFirstLetter != firstLetter {
                lastFirstLetter = firstLetter
                
                if let last = sectionIndexes.last {
                    last.sectionCount = count
                    sectionIndexes.removeLast()
                    sectionIndexes.append(last)
                }
                count = 0
                
                sectionIndexes.append(SectionIndex(firstIndex: index, sectionCount: 0, letter: firstLetter))
            }
            
            index++
            count++
        }
    }
    
    if let last = sectionIndexes.last {
        last.sectionCount = count
        sectionIndexes.removeLast()
        sectionIndexes.append(last)
    }
    
    return sectionIndexes
}