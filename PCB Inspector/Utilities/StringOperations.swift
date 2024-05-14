//
//  StringOperations.swift
//  PCB Inspector
//
//  Created by Jack Smith on 14/02/2024.
//
//  File to perform comparison functions on strings

import Foundation

class StringOperations {
    /// Determine the edit distance between two strings, if "checkingForSimilarCharacters" is set to true then an additional check will occur to determine if the altered elements are similar enough
    static func stringDistance(_ str1: String, _ str2: String, checkingForSimilarCharacters: Bool = false) -> Int {
        let differences = determineStringDifferences(str1.uppercased(), str2.uppercased())
        if checkingForSimilarCharacters { // Check similar characters
            return calcDifferenceWithSimilarCheck(differences)
        } else { // Simple difference check
            var differenceCounter = 0
            for (c1, c2) in differences {
                differenceCounter += max(c1.count, c2.count)
            }
            return differenceCounter
        }
    }
    
    /// Helper function to determine the distance of string whilst checking if the two characters are visually similar, if they're not, return the max int value
    fileprivate static func calcDifferenceWithSimilarCheck(_ differences: [([Character], [Character])]) -> Int {
        var differenceCounter = 0
        for change in differences { // Iterate through the difference pairs
            if change.0.count == change.1.count { // Direct substitution operation
                for (c1, c2) in zip(change.0, change.1) {
                    // Check each chatacter in the substitution, if not similar, return max int value
                    guard charactersSimilar(c1, c2) else { return Int.max }
                    differenceCounter += 1
                }
            } else { // Indirect subsitution e.g. AAB -> B
                let lenghtDiff = abs(change.0.count - change.1.count)
                
                var maxChange = change.0.count > change.1.count ? change.0 : change.1
                let minChange = change.0.count < change.1.count ? change.0 : change.1
                
                // Iterate through the smaller changed list, and identify an element in the larger list that is similar to it, else return max int
                for (i, m) in minChange.enumerated() {
                    var hasPair = false
                    for j in 0...lenghtDiff { // Iterate through possible pairings between the smaller and larger list
                        if let item = maxChange.conditionalGet(i + j) {
                            if charactersSimilar(item, m) { // There is a similar pair
                                hasPair = true
                                maxChange[i + j] = "`" // Set the found item as some other character to prevent future matchings
                                break
                            }
                        }
                    }
                    if !hasPair {
                        return Int.max
                    }
                }
                // Add the lagrer value to the difference counter 
                differenceCounter += max(change.0.count, change.1.count)
            }
        }
        return differenceCounter
    }
    
    /// Takes two strings and returns an array of the pairs of differences between the strings
    fileprivate static func determineStringDifferences(_ str1: String, _ str2: String) -> [([Character], [Character])] {
        
        // Character array of the two strings
        let str1Chars: [Character] = Array(str1)
        let str2Chars: [Character] = Array(str2)
        
        // Get an array of the differences
        let (str1Altered, str2Altered) = createDifferenceMap(str1, str2)
        
        
        // Get the elements of the two string that have not been altered
        let str1Stationary = str1Altered.split(separator: true)
        let str2Stationary = str2Altered.split(separator: true)
        
        var previousEnd1 = 0
        var previousEnd2 = 0
        
        // Store the pairs of characters that have changed between two strings
        var changedPairs: [([Character], [Character])] = []
        
        // Iterate over the "stationary" elements
        for (s1, s2) in zip(str1Stationary, str2Stationary) {
            // Add the changed-elements
            changedPairs.append((Array(str1Chars[previousEnd1..<s1.startIndex]) , Array(str2Chars[previousEnd2..<s2.startIndex])))
            previousEnd1 = s1.endIndex
            previousEnd2 = s2.endIndex
        }
        // Add the last element
        changedPairs.append((Array(str1Chars[previousEnd1..<str1.count]) , Array(str2Chars[previousEnd2..<str2.count])))
        
        return changedPairs
    }
    
    /// Takes two strings and returns the differences between them as a "mask" array with true being where the letters are altered
    //FIXME: make fileprivate again
    static func createDifferenceMap(_ str1: String, _ str2: String) -> (str1Map: [Bool], str2Map: [Bool]) {
        let diffs = str2.difference(from: str1) // Calc differences between the collections
        // Addition operations performed on str1
        var additionOperations: [(Int, Character)] = []
        // Deletion operations performed on str2
        var removalOperations: [(Int, Character)] = []
        
        // Array containing flags for each of the strings containing locations of characters that have been altered
        var str1Altered: [Bool] = Array(repeating: false, count: str1.count)
        var str2Altered: [Bool] = Array(repeating: false, count: str2.count)
        
        
        // Add all indicies to the list
        for diff in diffs {
            switch diff {
            case .insert(offset: let o, element: let e, associatedWith: _):
                additionOperations.append((o, e))
                // If a addition operation occurs, then mark the character in str2 as altered
                str2Altered[o] = true
            case .remove(offset: let o, element: let e, associatedWith: _):
                removalOperations.append((o, e))
                // If a removal operation occurs, then mark the character in str1 as altered
                str1Altered[o] = true
            }
        }
        
        return (str1Altered, str2Altered)
    }
    
    /// Takes a string str1 which is longer than that of str2, and as such some variation of str2 should be contained within str1
    /// Returns the distance between the two sub-strings, and returns the max int value otherwise
    /// Example: ab12c, 12 should return 0 ; ab13c 12 should return 1 and ab182c 12 should return Int.max
    static func stringDistanceContained(_ largerString: String, _ smallerString: String) -> Int {
        let largerString = largerString.uppercased()
        let smallerString = smallerString.uppercased()
        
        let (str1DiffMap, str2DiffMap) = createDifferenceMap(largerString, smallerString)
        // E.g. str1DiffMap = [t, t, f, f, t] and str2DiffMap = [f, f] if str1 = "abc12c" and str2 = "12"
        
        // Get the ranges of the str1 within str2
        guard let str1Ranges = str1DiffMap.firstRange(of: str2DiffMap) else { return Int.max }
        let subStr1 = String(([Character](Array(largerString)))[str1Ranges.lowerBound..<str1Ranges.upperBound])
        
        var counter = 0
        for (c1, c2) in zip(subStr1, smallerString) { // Iterate through the two strings
            if c1 != c2 && c2 != "?" { // If the two characters are the different, and the lookup character wasn't ? 
                counter += 1
            }
        }
        return counter
    }
    
    /// Takes two characters and checks if they are visually similar as specified by the visuallySimilarCharacters constant
    static fileprivate func charactersSimilar(_ char1: Character, _ char2: Character) -> Bool {
        for charSet in visuallySimilarCharacters { // Iterate through sets of visually similar characters
            if charSet.contains(char1) && charSet.contains(char2) { // Check if they contain both characters
                return true
            }
        }
        return false
    }
}
