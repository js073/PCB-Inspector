//
//  GoogleSearchAPI.swift
//  PCB Inspector
//
//  Created by Jack Smith on 02/02/2024.
//
//  Provides access to the Google Programmable Search Engine https://developers.google.com/custom-search

import Foundation
import Alamofire

class GoogleSearchAPI {
    static var shared: GoogleSearchAPI = GoogleSearchAPI() // Singleton class
    //TODO: Re-add Google Search API key and Search Engine ID sections, with error checking
    let apiKey: String = UserDefaults.standard.string(forKey: "google-api-key") ?? ""
    let searchEngineID: String = UserDefaults.standard.string(forKey: "google-engine-id") ?? ""
    lazy var searchURL = { (query: String) in
        return "https://www.googleapis.com/customsearch/v1?key=\(self.apiKey)&cx=\(self.searchEngineID)&q=\(query)"
    }
    
    /// Function to take a search question and look it up using the Google Search API, returning a list of tuples with the name of the result and the link to the result, returning nil on failure
    func makeRequest(_ searchQuestion: String) async -> [(String, String)]? {
        let searchQuestion = searchQuestion.replacingOccurrences(of: " ", with: "+").replacing("&", with: "") // Format the search query
        
        // Get the search result
        let responseData = await withCheckedContinuation { continuation in
            AF.request(searchURL(searchQuestion), method: .get).response { response in
                switch response.result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(_):
                    continuation.resume(returning: nil)
                }
                
            }
        }
        
        // Parse and format result
        guard let responseData else { return nil }
        print(responseData)
        guard let jsonData = try? JSONSerialization.jsonObject(with: responseData) as? [String : Any] else { return nil }
        print(jsonData)
        guard let searchResults = jsonData["items"] as? [[String: Any]] else { return nil }
        
        var output: [(String, String)] = []
        
        for item in searchResults { // Add the results to the output list 
            let title = item["title"] as? String
            let link = item["link"] as? String
            
            if let title, let link {
                output.append((title, link))
            }
        }
        
        return output
        
    }
}
