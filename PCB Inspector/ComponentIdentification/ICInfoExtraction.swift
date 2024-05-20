//
//  IdentifyComponent.swift
//  PCB Inspector
//
//  Created by Jack Smith on 11/01/2024.
//
//  Class created to take the raw text identified from an IC and return information about it
//  Manufacturer list taken from https://en.wikipedia.org/wiki/List_of_integrated_circuit_manufacturers
//  Manufacturer code list taken from https://en.wikibooks.org/wiki/Practical_Electronics/Manufacturers_Prefix

import Foundation
import OrderedCollections

class ICInfoExtraction {
    static var shared = ICInfoExtraction() // Singleton shared class
    lazy var manufacturerList: [String] = getManufacturerList() // Manufacturer list
    private lazy var manufacturerCodes: [String: [String]] = getManufacturerCodes() // Dictionary of Mnaufacturer : Code
    private lazy var codeManufacturers: [String: [String]] = manufacturerCodesToCodeManufactuers() // Dictionary of Code: Manufacturers
    private var allowedCharacters: CharacterSet { // Set of allowed characters for string
        let lower = CharacterSet(charactersIn: UnicodeScalar(unicodeScalarLiteral: "a")...UnicodeScalar(unicodeScalarLiteral: "z"))
        let upper = CharacterSet(charactersIn: UnicodeScalar(unicodeScalarLiteral: "A")...UnicodeScalar(unicodeScalarLiteral: "Z"))
        let nums = CharacterSet(charactersIn: UnicodeScalar(unicodeScalarLiteral: "0")...UnicodeScalar(unicodeScalarLiteral: "9"))
        let _ = CharacterSet(charactersIn: "- ")
        return lower.union(upper).union(nums)
    }
    var testingMode: (Bool, APIErrorState, ICInfoState) = (false, .none, .unloaded) // Variable used in testing to prevent the API from being called in order to prevent unecessary usage charges
    private lazy var usingAPI = UserDefaults.standard.bool(forKey: "searchModeToggle") // Used to check if the API is being used 
    
    /// Opens the file containing the manufacturer list and returns it as an array of Strings, if the file cannot be found or is empty, then an empty list is returned
    fileprivate func getManufacturerList() -> [String] {
        guard let textFile = Bundle.main.url(forResource: "manufacturer_list", withExtension: "txt") else { return [] } // URLs for all text files in app
        guard let fileContents = try? String(contentsOf: textFile) else { return [] }
        return fileContents.components(separatedBy: "\n")
    }
    
    fileprivate func getManufacturerCodes() -> [String: [String]] { // Uses the file manufactuer_codes and parses it into a dictionary of manufacturers and their codes
        guard let textFile = Bundle.main.url(forResource: "manufacturer_codes", withExtension: "txt") else { return [:] }
        guard let fileContents = try? String(contentsOf: textFile) else { return [:] }
        var returnDict: [String: [String]] = [:]
        for item in fileContents.components(separatedBy: "\n") {
            var split = item.components(separatedBy: ",")
            let key = split.removeFirst()
            returnDict[key] = split
        }
        return returnDict
    }
    
    /// Takes the raw text identified from the PCB and returns a dictionary of key-value pairs for information about the IC, the state of the IC info, as well as the error state for the API
    func findComponentDetailsSingle(_ rawText: [String]) async -> InfoExtractionReturn {
        let details = await determineComponentDetails(rawText)
        return await lookupDetailInformation(details)
    }
    
    /// Takes the raw text from two different PCBs and returns an Either type depending on which is determined to be better
    func findComponentDetailsCompare(_ rawText1: [String], _ rawText2: [String]) async -> Either<InfoExtractionReturn, InfoExtractionReturn> {
        switch await comapreTwoTexts(rawText1, rawText2) {
        case .Left(let details1):
            return .Left(await lookupDetailInformation(details1))
        case .Right(let details2):
            return .Right(await lookupDetailInformation(details2))
        }
    }
    
    /// Function to take the raw text from an image of an IC and determine details about it, returns a TextDetails object
    func determineComponentDetails(_ rawText: [String]) async -> TextDetails {
        var rawText = rawText.filter { $0.count >= 4 }.map { $0.filterCharacters(allowedCharacters).trimmingCharacters(in: .whitespacesAndNewlines) } // Only include lines greater than 4 to remove noise
        var foundDetails = TextDetails()
        
        if rawText.isEmpty { return foundDetails } // No text has been identified
        
        // Identify manufacturer if possible
        var manufacturers: [String]? = nil
        for (l, line) in rawText.enumerated() { // Iterate through the lines of rawText and find the manufacturer, if it exists
            if let m = isManufacturer(line) {
                manufacturers = m
                rawText.remove(at: l)
                break
            }
        }
        
        var orderedLookupItems: [String] = [] // Will store the possible lines to be looked up, in descending order of possibility of returning results
        
        // First see if manufacturer codes exist for the current manufacturer
        if let manufacturers {
            if manufacturers.count > 1 { // Multiple manufacturers
                foundDetails.manufacturer = .Right(manufacturers)
            } else { // Single manufacturer
                foundDetails.manufacturer = .Left(manufacturers[0])
            }
            // Get the codes for the identified manufacturer(s)
            var codes = manufacturers.compactMap { lookupManufacturerCode($0) }.flatMap { $0 }
            if codes.isEmpty { // No codes have been found
                // We take the first letter of the potential manufacturer name(s) as the potential code
                codes = manufacturers.compactMap { ($0.first) }.map { String($0) }
            }

            let filtered = rawText.splitArray { item in // Get lines that have the code as a prefix
                for code in codes {
                    if item.hasPrefix(code) { // Include the line in filtered if there is
                        return true
                    }
                }
                return false
            }
            orderedLookupItems.append(contentsOf: filtered.included)
            rawText = filtered.excluded
        } else { // If no manufacturer is found, loop through lines of text to try and find manufacturer from the product code
            var potentialManufacturers: [String] = []
            if let (res, lines) = lookupWithCode(rawText) {
                potentialManufacturers.append(contentsOf: res)
                rawText = lines
            }
            if !potentialManufacturers.isEmpty {
                potentialManufacturers = potentialManufacturers.map { isManufacturer($0)?.joined() ?? $0 } // Get proper names of manufacturers
                foundDetails.manufacturer = .Right(potentialManufacturers)
            }
        }
        
        // If not, first try lines starting with letters
        let letterLines = rawText.filter { ($0.first ?? "1").isLetter }
        
        // Give lines that also contain a number priority
        let numLetters = letterLines.filter { $0.filter { $0.isNumber }.count > 0 }
        let nonNumLetters = letterLines.filter { $0.filter { $0.isNumber }.count == 0 }
        
        print("letterz num", numLetters)
        print("letterz nonnum", nonNumLetters)
        
        orderedLookupItems.append(contentsOf: numLetters)
        orderedLookupItems.append(contentsOf: nonNumLetters)
        
        let otherLines = rawText.filter { !(($0.first ?? "1").isLetter) }.sorted(by: { $0.count >= $1.count })
        // Iterate through other markings, from first to last, and attempt to find information
        orderedLookupItems.append(contentsOf: otherLines)
        
        print("letterz", otherLines)
        
        // First line is the most likely code
        let mostLikelyCode = orderedLookupItems.first
        let nonCodeLines = [String](orderedLookupItems.dropFirst())
        
        // Determine dates from the other lines
        let potentialDates = deriveManufacturerDate(nonCodeLines)
        
        foundDetails.mostLikelyCode = mostLikelyCode
        foundDetails.otherLines = nonCodeLines
        foundDetails.dateInformation = potentialDates
        
        // Return the found details
        return foundDetails
    }
    
    /// Takes identified details and performs an API lookup
    fileprivate func lookupDetailInformation(_ details: TextDetails) async -> InfoExtractionReturn {
        guard !details.isEmpty() else { return InfoExtractionReturn(icState: .noText) }
        var lookupLines: [String] = []
        if let mostLikelyCode = details.mostLikelyCode { // Add most likely code first
            lookupLines.append(mostLikelyCode)
        }
        if let otherLines = details.otherLines { // Add other lines next
            lookupLines.append(contentsOf: otherLines)
        }
        
        var lookupError = false
        
        for (_, line) in lookupLines.enumerated() { // Iterate through potential lines
            guard !lookupError else { continue } // If there has been a lookup error, continue to the next loop iteration
            
            let lookupResult = await apiLookup(line)
            
            lookupError = lookupResult.isError // Set the error flag to true if an error occured
            
            if lookupResult.icState != .notAvaliable { // Return the information in every case except the no information case
                var newDict = lookupResult.dictionary // Create new tmp dictionary to mutate
                
                pubLogger.debug("Recieved result for \(line)")
                
                // Check if the found information is close to the new information, otherwise continue
                guard isResultCorrect(newDict ?? [:], line) else { continue }
                
                pubLogger.debug("Result for \(line) is correct")
                
                if let dateInformation = details.dateInformation, let (dateKey, dateValue) = datesFormatter(dateInformation) {
                    newDict?[dateKey] = dateValue
                }
                
                return InfoExtractionReturn(dictionary: newDict, icState: lookupResult.icState)
            }
            
            pubLogger.debug("No request recieved for \(line)")
        }
        
        // If no information is found, perform a wildcard lookup
        if let first = lookupLines.first, let wildcardLookup = await performWildcardLookup(first, details.manufacturer?.left()) {
            return wildcardLookup
        }
        
        // If no details are further found, return the formatted output
        let formattedOutput = detailsToDictionary(details)
        
        // Return information 
        return InfoExtractionReturn(dictionary: formattedOutput, icState: lookupError ? .unloaded : .notAvaliable, isError: lookupError)
    }
    
    /// Performs the lookup using wildcards on all of the lookup items
    fileprivate func performWildcardLookup(_ lookupItem: String, _ manufacturer: String?) async -> InfoExtractionReturn? {
        let item = lookupItem
        // Stricter requirements for a line to be looked-up in this mode, as higher chance of giving false results
        
        // In this case, ensure the string is more than 5 characters
        guard item.count > 5 else { return nil }
        // Make sure the item that is being looked-up starts with a letter
        guard (item.first?.isLetter ?? false) else { return nil }
        
        // Get wildcard string
        let (lookupString, replacementCount) = APIRequest.shared.insertWildcards(item)
        
        // Ensure that less than 50% of the string has been replaced
        guard replacementCount * 2 <= item.count else { return nil }
        
        // Perform lookup
        let lookupResult = await apiLookup(lookupString)
        
        guard lookupResult.icState != .notAvaliable else { return nil }
        
        let newDict = lookupResult.dictionary
        
        guard isResultCorrect(newDict ?? [:], lookupString.replacingOccurrences(of: "*", with: "")) else { return nil }
        
        // Check the manufacturer found during prior processing is the same as the one found during the API lookup
        if let foundManufacturer = manufacturer?.components(separatedBy: " ").first, let apiManufacturer = newDict?["Manufacturer"]?.components(separatedBy: " ").first {
            guard StringOperations.stringDistance(foundManufacturer, apiManufacturer) < 3 else { return nil }
        }
        
        return InfoExtractionReturn(dictionary: newDict, icState: lookupResult.icState)
    }
    
    /// Function to take the raw text from two images and compare them to determine which one is more likely to be accurate
    func comapreTwoTexts(_ rawText1: [String], _ rawText2: [String]) async -> Either<TextDetails, TextDetails> {
        let details1 = await determineComponentDetails(rawText1)
        let details2 = await determineComponentDetails(rawText2)
        
        let manufacturer1 = details1.manufacturer?.left()
        let manufacturer2 = details2.manufacturer?.left()
        
        switch (manufacturer1, manufacturer2) { // Check which item has a single manufacturer
        case (.none, .none): // If neither have single manufacturer, return item with highest number of lines
            if (details1.otherLines?.count) ?? 0 >= (details2.otherLines?.count) ?? 0 {
                return .Left(details1)
            } else {
                return .Right(details2)
            }
        case (.some, .none): // If first has a single manufacturer
            return .Left(details1)
        case (.none, .some): // If second has a single manufacturer
            return .Right(details2)
        case (.some(let m1), .some(let m2)): // If both have single manufacturers
            // Get codes for both manufacturers
            let codes1 = lookupManufacturerCode(m1) ?? []
            let codes2 = lookupManufacturerCode(m2) ?? []
            let mostLikelyCode1 = details1.mostLikelyCode ?? ""
            let mostLikelyCode2 = details2.mostLikelyCode ?? ""
            switch (lineDoesContainCode(mostLikelyCode1, codes1), lineDoesContainCode(mostLikelyCode2, codes2)) { // Check if either code contains manufacturer code
            case (true, false): // First contains code
                return .Left(details1)
            case (false, true): // Second contains code
                return .Right(details2)
            default: // Otherwise return the one with the most number of other lines
                if (details1.otherLines?.count) ?? 0 >= (details2.otherLines?.count) ?? 0 {
                    return .Left(details1)
                } else {
                    return .Right(details2)
                }
            }
        }
    }
    
    
    /// Give an array of code strings and return a manufacturer
    fileprivate func lookupWithCode(_ codes: [String]) -> (manufacturers: [String], orderedLines: [String])? {
        var foundManufacturers: [String] = []
        // Get the first letters of the strings
        var beginingCodes = codes.compactMap { $0.filter({ !CharacterSet.whitespacesAndNewlines.containsCharacter($0) }).components(separatedBy: .decimalDigits).first }
        
        var likelyLines: [String] = []
        
        pubLogger.debug("passed codes \(codes)")
        while !beginingCodes.isEmpty {
            let maxLenCodes = getMaxLength(beginingCodes) // Filter the codes so the longest are searched first
            print(maxLenCodes)
            var hasFound = false
            for (_, code) in maxLenCodes.enumerated() {
                if let found = codeManufacturers[code] { // If a code can be found
                    pubLogger.debug("current code \(code), \(found)")
                    foundManufacturers.append(contentsOf: found) // Add to output
                    
                    // Make elements containing the identified code first
                    let thisLine = codes.splitArray(with: { $0.hasPrefix(code) })
                    likelyLines.append(contentsOf: thisLine.included)
                    
//                    beginingCodes.remove(at: c) // Remove this code from the list of candidate codes
                    hasFound = true
                    //FIXME: MAKE IT SO THAT THE LINE THAT HAS GIVEN THE CODE RETURNS THE TRUE
                }
            }
            
            if hasFound { // If we have found a code this run, stop searching
                break
            }
            // Remove the last character from the codes and remove codes with 1 or less characters
            
            /*  We remove the last character from the code as we don't know when the manufacturer identification ends
                and where the product code starts.
                This way we can try and find as many manufacturers at once.
             */
            beginingCodes = beginingCodes.map { if $0.count >= ((maxLenCodes.first?.count) ?? 0) { $0.removingLast() } else { $0 } }.filter { $0.count > 1 }
        }
        if foundManufacturers.isEmpty {
            return nil
        }
        
        var orderedLines = Array(OrderedSet(likelyLines))
        orderedLines.append(contentsOf: Array(OrderedSet(codes).subtracting(OrderedSet(likelyLines))))
        
        return (Array(Set(foundManufacturers)), orderedLines) // Unique set of manufacturers
    }
    
    /// Returns the strings in the array that have the max lengths
    fileprivate func getMaxLength(_ array: [String]) -> [String] {
        if let maxLen = array.max(by: { $0.count < $1.count }) {
            return array.filter{ $0.count == maxLen.count }
        }
        return []
    }
    
    /// Converts a dictionary of Manufacturer : Codes to Code : Manufacturer for faster lookup
    fileprivate func manufacturerCodesToCodeManufactuers() -> [String: [String]] {
        var outputDict: [String: [String]] = [:]
        for (key, value) in manufacturerCodes {
            for v in value {
                if let current = outputDict[v] {
                    outputDict[v] = current + [key]
                } else {
                    outputDict[v] = [key]
                }
            }
        }
        return outputDict
    }
    
    /// Iterate through the manufacturer codes and find the codes for the inputted manufacturer, if they exist/
    fileprivate func lookupManufacturerCode(_ lookup: String) -> [String]? {
        let lookupLowered = lookup.lowercased()
        for manufacturer in manufacturerCodes {
            if lookupLowered.contains(manufacturer.key.lowercased()) {
                return manufacturer.value
            }
        }
        return nil
    }
    
    /// Check if a line starts with one of the given codes
    fileprivate func lineDoesContainCode(_ line: String, _ codes: [String]) -> Bool {
        for code in codes { // Iterate through codes
            if line.hasPrefix(code) { // Starts with code
                return true
            }
        }
        return false
    }
    
    /// Function to take a potential identification number and access information
    fileprivate func apiLookup(_ id: String) async -> InfoExtractionReturn {
        if testingMode.0 { // Used for testing to get the desired result from the API and prevent API calls
            return InfoExtractionReturn(dictionary: [:], icState: testingMode.2)
        }
        
        // If the API mode toggle has been turned off, then return no information
        if !usingAPI {
            return InfoExtractionReturn(dictionary: [:], icState: .notAvaliable)
        }
        
        let returnState = await APIRequest.shared.octopartAPISearch(id)
        switch returnState.apiState {
        case .none: // Information successfully extracted state
            return InfoExtractionReturn(dictionary: returnState.returnDictionary , icState: .loaded)
        case .noInformation: // No information could be found
            return InfoExtractionReturn(icState: .notAvaliable)
        default: // There was an API error
            // TODO: Add erorr handling 
            return InfoExtractionReturn(icState: .unloaded, isError: true)
        }
    }
    
    /// Checks if the passed string is a manufacturer, and if it is, returns the manufacturer name, else returns nil
    //FIXME: add fileprivate again
    func isManufacturer(_ inputString: String) -> [String]? {
        // Lowercase the input and get the first word if there are multiple words
        let inputLower = (inputString.uppercased().components(separatedBy: " ").first ?? inputString.uppercased()).trimmingCharacters(in: .whitespaces)
        
        // Get the first words of the manufacturer and lowercase them
        let filterManufacturer = manufacturerList.map { ($0.components(separatedBy: " ").first ?? $0).trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        
        // Calculate differences between the manufacturer name and the identified line
        let diffs = filterManufacturer.enumerated().map { (StringOperations.stringDistance($0.element, inputLower, checkingForSimilarCharacters: true), $0.offset) }
        
        // Get the min difference, only return non-nil if the min-diff 2 or less
        guard let minDiff = diffs.min(by: { $0.0 < $1.0 }), minDiff.0 <= 2 else { return nil }
        // Get all elements with the smallest difference
        let mins = diffs.filter { $0.0 == minDiff.0 }
        let manufacturers = mins.map { manufacturerList[$0.1] }
        return manufacturers
    }
    
    /// Function to check if the result from the API contains a similar version of the passed ID
    fileprivate func isResultCorrect(_ apiResult: OrderedDictionary<String, String>, _ lookupString: String) -> Bool {
        guard let resultCode = apiResult["Part Number"]?.replacingOccurrences(of: " ", with: "") else { return false }
        let lookupString = lookupString.replacingOccurrences(of: " ", with: "")
        let differenceScore = resultCode.count > lookupString.count ? StringOperations.stringDistanceContained(resultCode, lookupString) : StringOperations.stringDistanceContained(lookupString, resultCode)
        print("info", resultCode, lookupString, differenceScore)
        return differenceScore < 3
    }
    
    
    /// Try and derive the possible manufacturer date from the list of codes, returns the year and week
    func deriveManufacturerDate(_ lines: [String]) -> [(Int, Int)]? {
        var possibleStrings: [String] = []
        guard let formatRegex = try? Regex(String(repeating: "[0-9]", count: 4)) else { return nil } // Regex of 4 numbers
        for line in lines { // Each possible line
            let ranges = line.ranges(of: formatRegex)
            for range in ranges {
                let startDist = line.distance(from: line.startIndex, to: range.lowerBound)
                let endDist = line.distance(from: range.upperBound, to: line.endIndex)
                if (startDist > 0 && !(line[line.index(line.startIndex, offsetBy: startDist - 1)].isNumber)) || startDist == 0 { // Check if the start is either the begining of the line, or the letter before the section is not a number
                    if (endDist > 0 && !(line[line.index(line.endIndex, offsetBy: -endDist)].isNumber)) || endDist == 0 { // Check if the ending is either the end of the line, or the next character is not a number
                        possibleStrings.append(String(line[range]))
                    }
                }
            }
        }
        var weekDates: [(Int, Int)] = []
        
        let currentYear = String(Calendar.current.component(.year, from: Date())) // Current year in string form
        let yearPrefix = String(currentYear.prefix(2)) // 20xx section
        let yearSuffix = String(currentYear.suffix(2)) // xx24 section
        guard let yearSuffixInt = Int(yearSuffix) else { return nil }
        
        for possibleString in possibleStrings {
            guard let year = Int(possibleString.prefix(2)) else { continue } // Get year as int or continue
            guard let week = Int(possibleString.suffix(2)), week <= 52, week > 0 else { continue } // Get week as int and make sure it is less than or equal to 52
            switch year {
            case 0...yearSuffixInt: // If year is between 0-24, then append with 20
                guard let y = Int(yearPrefix.appending(String(format: "%02d", year))) else { continue }
                weekDates.append((y, week))
            case max(yearSuffixInt, 70)...99: // If year is between 60-99 append with 19
                guard let y = Int("19".appending(String(format: "%02d", year))) else { continue }
                weekDates.append((y, week))
            default: // Otherwise is not valid week and year
                continue
            }
        }
        return weekDates.isEmpty ? nil : weekDates // Return nil if none are identified, else retrun the formatted list
    }
    
    /// Takes a list of year, week integers and formats it into "xth week of yyyy", returns nil on failure
    func datesFormatter(_ dates: [(Int, Int)]) -> (String, String)? {
        var formattedDates: [String] = []
        
        let ordinalFormatter = NumberFormatter()
        ordinalFormatter.numberStyle = .ordinal // Formats the dates to 1st, 2nd, 3rd, ... format
        
        for date in dates {
            guard let formattedWeek = ordinalFormatter.string(from: date.1 as NSNumber) else { continue } // Try formatting else continue through loop
            formattedDates.append("\(formattedWeek) week of \(date.0)")
        }
        
        if formattedDates.isEmpty { return nil }
        
        return (formattedDates.count == 1 ? "Potential Manufacture Date" : "Potential Manufacture Dates" , formattedDates.joined(separator: ", "))
    }
    
    /// Function to convert a TextDetails object to a presentable OutputDictionary
    fileprivate func detailsToDictionary(_ details: TextDetails) -> OrderedDictionary<String, String> {
        var output: OrderedDictionary<String, String> = [:]
        
        if let manufacturer = details.manufacturer {
            switch manufacturer {
            case .Left(let m): // Single manufacturer
                output["Manufacturer"] = m
            case .Right(let ms): // Multiple manufacturers
                output["Potential Manufacturers"] = ms.joined(separator: ", ")
            }
        }
        if let mostLikelyCode = details.mostLikelyCode { // Most likely code
            output["Most Likely Code"] = mostLikelyCode
        }
        
        if let otherLines = details.otherLines { // Other lines in output
            for (i, line) in otherLines.enumerated() {
                output["Line \(i+1)"] = line
            }
        }
        
        if let dateInformation = details.dateInformation, let formattedDates = datesFormatter(dateInformation) { // Potential dates
            output[formattedDates.0] = formattedDates.1
        }
        
        return output
    }
}

/// Used as a wrapper for the return of the IC info state call
struct InfoExtractionReturn {
    var dictionary: OrderedDictionary<String, String>? // Output of the API call, if applicable
    var icState: ICInfoState // State of the IC
    var isError: Bool = false // If an error has occured
}
 
/// Struct used to store the results of information identification before API lookup
struct TextDetails {
    var manufacturer: Either<String, [String]>? // Manufacturer, either a single manufacturer, or multiple manufacturers
    var mostLikelyCode: String? // Mosrt likely identification code
    var otherLines: [String]? // Other lines on IC
    var dateInformation: [(Int, Int)]? // Potential raw dates
    
    /// Returns true if all values in struct are nil
    func isEmpty() -> Bool {
        return manufacturer == nil && mostLikelyCode == nil && otherLines == nil && dateInformation == nil
    }
}

fileprivate extension CharacterSet {
    /// Extension to CharacterSet to check if it contains the passed character
    func containsCharacter(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            if self.contains(scalar) {
                return true
            }
        }
        return false
    }
}

fileprivate extension String {
    /// Extension to string to only allow characters in a CharacterSet
    func filterCharacters(_ characterSet: CharacterSet) -> String {
        return self.filter { characterSet.containsCharacter($0) }
    }
    
    // Non in-place last letter removal
    func removingLast() -> String {
        if self.isEmpty {
            return self
        }
        var string = self
        string.removeLast()
        return string
    }
}

fileprivate extension Dictionary where Value: Equatable {
    /// Adapted from https://stackoverflow.com/questions/41383937/reverse-swift-dictionary-lookup
    /// Give a value and return a key, a reverse dictionary lookup
    func getKeyFromValue(_ value: Value) -> Key? {
        return first { $0.1 == value }?.0
    }
}

fileprivate extension Array {
    /// Extensions to perform non in-place element removal
    func removing(_ at: Int) -> Array {
        guard at >= 0 && at < self.count else { return self }
        var tmp = self
        tmp.remove(at: at)
        return tmp
    }
}
