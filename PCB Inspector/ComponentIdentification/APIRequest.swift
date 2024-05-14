//
//  APIRequest.swift
//  PCB Inspector
//
//  Created by Jack Smith on 15/01/2024.
//
//  File and class for interfacing with the Octopart API

import Foundation
import Alamofire // HTTP request library for easier simple HTTP requests, used for the API token retrieval, more info here: https://github.com/Alamofire/Alamofire
import OrderedCollections

class APIRequest {
    static var shared = APIRequest() // Singleton shared class
    private let storedTokenKey = "octopart_api_token" // Key for stored token
    private let storedTokenTimeKey = "octopart_api_token_creation_date" // Key for time of creation of stored token
    //TODO: Fix the API strings
    private let octopartClientID = UserDefaults.standard.string(forKey: "octopart-user-id") ?? "" // ID for token retrieval
    private let octopartClientSecret = UserDefaults.standard.string(forKey: "octopart-user-secret") ?? "" // Secret for token retrieval
    private let octopartTokenURL = "https://identity.nexar.com/connect/token" // URL for retrieving a valid token for the API request
    private let octopartSearchURL = "https://api.nexar.com/graphql/" // URL for searching for parts
    private var octopartAPIToken: String? // Current API token
    private var octopartAPITokenTime: Double? // Time when API token was created (only valid for 24 hours)
    private var wildcardCharacterSet: [Character] = ["8", "B", "0", "M", "X", "1", "I", "S", "5"] // Characters that the API will swap with wildcards
    
    // Follows the parameters laid out here https://support.nexar.com/support/solutions/articles/101000471994-authorization
    // Adapted from code found at https://stackoverflow.com/questions/26364914/http-request-in-swift-with-post-method
    func generateToken() async -> Bool { // Gets the token from the Octopart API
        // Get the stored token from storage
        let time = UserDefaults.standard.double(forKey: storedTokenTimeKey)
        if let token = UserDefaults.standard.string(forKey: storedTokenKey), time != 0.0 {
            octopartAPIToken = token
            octopartAPITokenTime = time
        }
        
        // Check if the tokens are valid
        guard !isTokenValid() else { return true } // If the current token is valid then don't execute
        
        
        let requestBody = [
            "grant_type": "client_credentials",
            "client_id": octopartClientID,
            "client_secret": octopartClientSecret,
            "scope": "supply.domain"
        ]
        
        // Perform POST request with ID and secret to get a session key
        let result = await withCheckedContinuation { continuation in
            AF.request(octopartTokenURL, method: .post, parameters: requestBody, encoding: URLEncoding.httpBody).response { response1 in
                switch response1.result {
                case .success(let data): // Successful call
                    if let jsonResponse = try? JSONSerialization.jsonObject(with: data!) as? [String: Any] {
                        let token = jsonResponse["access_token"]
                        self.octopartAPIToken = token as? String
                        UserDefaults.standard.set(token, forKey: self.storedTokenKey) // Store the token to prevent unecessary token requests
                        let currentTime = Date.timeIntervalSinceReferenceDate
                        self.octopartAPITokenTime = currentTime
                        UserDefaults.standard.set(currentTime, forKey: self.storedTokenTimeKey) // Store the creation time for the token
                    } else {
                        continuation.resume(returning: false)
                    }
                    print("Successfully got API key")
                    continuation.resume(returning: true)
                case .failure(_): // Failed call
                    print("Error occured getting API key")
                    continuation.resume(returning: false)
                }
            }
        }
        
        return result
        
    }
    
    // Inbformation on API calls can be found here https://support.nexar.com/support/solutions/articles/101000472564-query-templates
    // Performs an API request with the specified search string, optional results parameter to specify the desired number of results from the API
    // The completionHandler function passed needs to take an optional dictionary of the results of the API call, and an ENUM of the error states and return a void type
    func octopartAPISearch(_ searchString: String, results: Int = 1, wildcardReplacement: Bool = false) async -> APIReturn {
        // Query format for GraphQL query to Nexar API
        guard !UserDefaults.standard.bool(forKey: "developerModeToggle") else { return APIReturn(apiState: .noInformation) } // Used to prevent unecessary calls during development
        
        let searchString = wildcardReplacement ? insertWildcards(searchString).newStr : searchString // If the function is called with inserting with wildcards, perform the necessary operation
        
        let searchData = """
        query partSearch {
              supSearch (
                q:"\(searchString)",
                limit: \(results)
                ){
                hits
                results {
                  part {
                    name
                    mpn
                    category {
                      id
                      name
                    }
                    manufacturer {
                      name
                      homepageUrl
                    }
                    shortDescription
                    bestDatasheet {
                        url
                    }
                    octopartUrl
                  }
                }
              }
            }
        
        """
        
        // Check token
        if !isTokenValid() { // Invalid token
            let tokenSuccess = await generateToken() // Get new token
            guard tokenSuccess else { return APIReturn(apiState: .noToken) }
        }
        guard let token = octopartAPIToken else { return APIReturn(apiState: .noToken) }
        
        // Perform request
        let headers = HTTPHeaders([HTTPHeader(name: "token", value: token)]) // Add token to request
        let parameters: [String: String] = [
            "query": searchData
        ]
        let responseData = await withCheckedContinuation { continuation in
            AF.request(self.octopartSearchURL, method: .get, parameters: parameters, headers: headers).response { response in
                switch response.result {
                case .success(let data): // Sucessful API call
                    continuation.resume(returning: data)
                case .failure(_): // Failure during API call
                    continuation.resume(returning: nil)
                }
            }
        }
        
        guard let responseData else { return APIReturn(apiState: .callFailed) }
        
        // Parse JSON data
        var resultDictionary: OrderedDictionary<String, String> = [:]
        if let jsonData = try? JSONSerialization.jsonObject(with: responseData) as? [String : Any],
           let data = jsonData["data"] as? [String : Any],
           let search = data["supSearch"] as? [String : Any] {
            if let results = search["results"] as? [[String: Any]] { // Return result state
                if let topResult = results.first {
                    if let part = topResult["part"] as? [String: Any] {
                        print(topResult)
                        if let manufacturer = part["manufacturer"] as? [String : String], manufacturer["name"] != nil {
                            resultDictionary["Manufacturer"] = manufacturer["name"]
                        }
                        if let name = part["name"] as? String, !name.isEmpty {
                            resultDictionary["Component Name"] = name
                        }
                        if let partNumber = part["mpn"] as? String, !partNumber.isEmpty {
                            resultDictionary["Part Number"] = partNumber
                        }
                        if let category = part["category"] as? [String: String], !category.isEmpty {
                            resultDictionary["Category"] = category["name"]
                        }
                        if let description = part["shortDescription"] as? String, !description.isEmpty {
                            resultDictionary["Description"] = description
                        }
                        if let datasheet = part["bestDatasheet"] as? [String: String], !datasheet.isEmpty {
                            resultDictionary["Datasheet URL"] = datasheet["url"]
                        }
                        if let pageURL = part["octopartUrl"] as? String, !pageURL.isEmpty {
                            resultDictionary["Octopart Page"] = pageURL
                        }
                        print(resultDictionary)
                        pubLogger.debug("search term \(searchString)")
                        // Success : return the result dictionary
                        return APIReturn(returnDictionary: resultDictionary, apiState: .none)
                    }
                }
            } else { // No result
                return APIReturn(apiState: .noInformation)
            }
        }
        return APIReturn(apiState: .callFailed)
    }
    
    /// Function to take a potential lookup string and alter it to include wildcards
    /// * used for sequence of characters (could be 0)
    /// ? used for a single unknown character
    func insertWildcards(_ originalString: String) -> (newStr: String, replacementCount: Int) {
        // Replace characters in wildcardCharacterSet with ?
        var count = 0
        var replacedString: String = ""
        for c in originalString {
            if wildcardCharacterSet.contains(c.uppercased()) {
                replacedString.append("?")
                count += 1
            } else {
                replacedString.append(c)
            }
        }
        return ("*\(replacedString)*", count) // Add * wildcards to begining and end to match names that contain the value
    }
    
    func isTokenValid() -> Bool { // Checks if the current API token is valid
        if octopartAPIToken != nil, let octopartAPITokenTime {
            if Date.timeIntervalSinceReferenceDate - octopartAPITokenTime <= (24*60*60) { // Checks if the token is less than 24hrs old
                return true
            }
        }
        return false
    }
}

/// Struct to send request to API for authentication
/// Follows the parameters laid out here https://support.nexar.com/support/solutions/articles/101000471994-authorization
fileprivate struct TokenRequestStruct: Codable {
    var grantType: String = "client_credentials"
    var clientId: String
    var clientSecret: String
    var scope: String = "supply.domain"
}

/// ENUM used to encode the state of the error when attempting to use API
enum APIErrorState {
    case none // No error
    case noToken // Token invalid
    case noInformation // Successful API call, no information retrieved
    case callFailed // Error when calling API
}

/// Structure used to wrap a return from the API
struct APIReturn {
    var returnDictionary: OrderedDictionary<String, String>? // Output dictionary of return values, if applicable
    var apiState: APIErrorState // State of the API call
}
