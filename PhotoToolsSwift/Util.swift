//
//  Util.swift
//  PhotoToolsSwift
//
//  Created by Todd Vernon on 2/26/24.
//
//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------

import Foundation

//---------------------------------------------------------------------------------------------------------------------
// Util Class
//
//---------------------------------------------------------------------------------------------------------------------

class Util {
    
    /// Check if a string consists of only digits
    static func isStringOfDigits(_ s: String) -> Bool {
        
        return( CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: s)) )
        /*

        
        let scanner = Scanner(string: s)
        let skips = CharacterSet(charactersIn: "1234567890")
        var filteredString: NSString? = ""
        
        scanner.scanCharacters(from: skips, into: &filteredString)
        
        return s.count == filteredString?.length
         
         */
    }
    
    /// Create a GUID
    static func createGUID() -> String {
        return UUID().uuidString
    }
}
