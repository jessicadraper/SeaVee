//
//  Networking.swift
//  SeaVee
//
//  Created by Jessi Draper on 03.12.25.
//

import Foundation

enum NetworkingError: Error, LocalizedError {
    case serializationFailed
    case networkOffline
    case unexpectedResponseFormat
    case permissionDenied
    case apiError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .serializationFailed:
            return "Failed to create request."
        case .networkOffline:
            return "You appear to be offline. Please check your network settings."
        case .unexpectedResponseFormat:
            return "Unexpected response format from server."
        case .permissionDenied:
            return "Missing or insufficient permissions. Contact system administrator."
        case .apiError:
            return "API error occurred. Contact system administrator."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}

// API Errors
struct ResponseError: Codable, Error {
    let error: ResponseErrorDetail
    
    enum CodingKeys: String, CodingKey {
        case error = "error"
    }
}

struct ResponseErrorDetail: Codable {
    let code: Int
    let message: String
    let errors: [ApiResponseError]?
    
    enum CodingKeys: String, CodingKey {
        case code = "code"
        case message = "message"
        case errors = "errors"
    }
}

struct ApiResponseError: Codable {
    let message: String
    let domain: String
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case message = "message"
        case domain = "domain"
        case reason = "reason"
    }
}

class Networking: ObservableObject {
    let session = URLSession(configuration: .default)

    let token: String = {
        guard let value = ProcessInfo.processInfo.environment["TOKEN"] else { // added environment varibale to scheme
            fatalError("TOKEN missing")
        }
        return value
    }()
    
    let key: String = {
        guard let value = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] else { // added environment varibale to scheme
            fatalError("KEY missing")
        }
        return value
    }()
    
    // MARK: - Request data
    
    func requestData(
        ship_name: String? = nil,
        start_date: String,
        end_date: String,
        completionHandler: @escaping (_ requestResponse: DataRequestResponse?, _ error: NetworkingError?) -> Void) {
            
            var body: [String:Any] = [
                "start_date": start_date,
                "end_date": end_date
            ]
            
            if let ship = ship_name, !ship.isEmpty {
                body["ship_name"] = ship
            }
            print("Body payload: \(body)")
            
            let url = URL(string: "https://api.apify.com/v2/acts/tKQ7VsygX5qEPgk1g/runs?token=\(token)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let task = session.dataTask(with: request) { data, response, error in
                let decoder = JSONDecoder()
                
                // Check for errors
                if let error = error as? URLError {
                    switch error.code {
                    case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                        completionHandler(nil, .networkOffline)
                    default:
                        completionHandler(nil, NetworkingError.unknownError)
                    }
                    return
                }
                
                // Check if data exists
                guard let data = data else {
                    completionHandler(nil, .unexpectedResponseFormat)
                    return
                }
                
                // Return successful response
                if let requestResponse = try? decoder.decode(DataRequestResponse.self, from: data) {
                    completionHandler(requestResponse, nil)
                    return
                }
                
                if let string = String(data: data, encoding: .utf8) {
                    print("Response: ", string)
                }
                
            }
            task.resume()
            
            // hard code dataset id temporarily
//            let inner = DataRequestResponse.DataResponse(defaultDatasetId: "Jr8uKuI0iI4Q1SzEU")
//            let response = DataRequestResponse(data: inner)

//            completionHandler(response, nil)
        }
    
    // MARK: - Retrieve data
    
    func retrieveData(
        datasetId: String,
        completionHandler: @escaping (_ retrievalResponse: [DataRetrievalResponse]?, _ error: NetworkingError?) -> Void) {
            
            let url = URL(string: "https://api.apify.com/v2/datasets/\(datasetId)/items")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = session.dataTask(with: request) { data, response, error in
                let decoder = JSONDecoder()
                
                // Check for errors
                if let error = error as? URLError {
                    switch error.code {
                    case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                        completionHandler(nil, .networkOffline)
                    default:
                        completionHandler(nil, NetworkingError.unknownError)
                    }
                    return
                }
                
                // Check if data exists
                guard let data = data else {
                    completionHandler(nil, .unexpectedResponseFormat)
                    return
                }
                
                print("──────── RAW RESPONSE START ────────")
                print(String(decoding: data, as: UTF8.self))
                print("──────── RAW RESPONSE END ────────")
                
                // Return successful response
                if let retrievalResponse = try? decoder.decode([DataRetrievalResponse].self, from: data) {
                    print("\(retrievalResponse.count) Results Returned")
                    completionHandler(retrievalResponse, nil)
                    return
                }
                
                // Handle api errors
                if let apiError = try? decoder.decode(ResponseError.self, from: data) {
                    let code = apiError.error.code
                    print("Error: \(apiError.error)")
                    
                    switch code {
                    case 403:
                        completionHandler(nil, .permissionDenied)
                    default:
                        completionHandler(nil, .apiError)
                    }
                    return
                }
                
                if let string = String(data: data, encoding: .utf8) {
                    print("Unknown Error Response: ", string)
                }
                
                completionHandler(nil, .unknownError)
                
            }
            
            task.resume()
        }
    
    // MARK: - Geocode data
    func searchPlace(
        input: String,
        completionHandler: @escaping (_ autocompleteResponse: AutocompleteResponse?, _ error: NetworkingError?) -> Void) {
            
            let body: [String:Any] = [
                "input": input,
            ]
            
            let url = URL(string: "https://places.googleapis.com/v1/places:autocomplete?key=\(key)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//            request.setValue("addressComponents,location", forHTTPHeaderField: "X-Goog-FieldMask")
            
            let task = session.dataTask(with: request) { data, response, error in
                let decoder = JSONDecoder()
                
                // Check for errors
                if let error = error as? URLError {
                    switch error.code {
                    case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                        completionHandler(nil, .networkOffline)
                    default:
                        completionHandler(nil, NetworkingError.unknownError)
                    }
                    return
                }
                
                // Check if data exists
                guard let data = data else {
                    completionHandler(nil, .unexpectedResponseFormat)
                    return
                }
                
                // Return successful response
                if let autocompleteResponse = try? decoder.decode(AutocompleteResponse.self, from: data) {
                    completionHandler(autocompleteResponse, nil)
                    return
                }
                
                if let string = String(data: data, encoding: .utf8) {
                    print("Unknown Error Response: ", string)
                }
                
                completionHandler(nil, .unknownError)
                
            }
            
            task.resume()
        }
    
    func getPlaceDetails(
        placeId: String,
        completionHandler: @escaping (_ placeResponse: PlaceResponse?, _ error: NetworkingError?) -> Void) {
            
            let url = URL(string: "https://places.googleapis.com/v1/places/\(placeId)?key=\(key)")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("addressComponents,location", forHTTPHeaderField: "X-Goog-FieldMask")
            
            let task = session.dataTask(with: request) { data, response, error in
                let decoder = JSONDecoder()
                
                // Check for errors
                if let error = error as? URLError {
                    switch error.code {
                    case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                        completionHandler(nil, .networkOffline)
                    default:
                        completionHandler(nil, NetworkingError.unknownError)
                    }
                    return
                }
                
                // Check if data exists
                guard let data = data else {
                    completionHandler(nil, .unexpectedResponseFormat)
                    return
                }
                
                // Return successful response
                if let placeResponse = try? decoder.decode(PlaceResponse.self, from: data) {
                    completionHandler(placeResponse, nil)
                    return
                }
                
                if let string = String(data: data, encoding: .utf8) {
                    print("Unknown Error Response: ", string)
                }
                
                completionHandler(nil, .unknownError)
                
            }
            
            task.resume()
        }
    
    func geocodeData(
        query: String,
        completionHandler: @escaping (_ geocodeResponse: GeocodeResponse?, _ error: NetworkingError?) -> Void) {
            
            let url = URL(string: "https://api.opencagedata.com/geocode/v1/json?q=\(query)&key=")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = session.dataTask(with: request) { data, response, error in
                let decoder = JSONDecoder()
                
                // Check for errors
                if let error = error as? URLError {
                    switch error.code {
                    case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                        completionHandler(nil, .networkOffline)
                    default:
                        completionHandler(nil, NetworkingError.unknownError)
                    }
                    return
                }
                
                // Check if data exists
                guard let data = data else {
                    completionHandler(nil, .unexpectedResponseFormat)
                    return
                }
                
                // Return successful response
                if let geocodeResponse = try? decoder.decode(GeocodeResponse.self, from: data) {
                    completionHandler(geocodeResponse, nil)
                    return
                }
                
                // Handle api errors
                if let apiError = try? decoder.decode(ResponseError.self, from: data) {
                    let code = apiError.error.code
                    print("Error: \(apiError.error)")
                    
                    switch code {
                    case 403:
                        completionHandler(nil, .permissionDenied)
                    default:
                        completionHandler(nil, .apiError)
                    }
                    return
                }
                
                if let string = String(data: data, encoding: .utf8) {
                    print("Unknown Error Response: ", string)
                }
                
                completionHandler(nil, .unknownError)
                
            }
            
            task.resume()
        }
}
