//
//  Geocoder.swift
//  SeaVee
//
//  Created by Jessi Draper on 03.12.25.
//

import Foundation

// OpenCage Geocoding API

struct GeocodeResponse: Decodable {
    let results: [GeocodeResults]
}

struct GeocodeResults: Decodable {
    let components: Components
    let confidence: Int
    let geometry: Geometry
    
    // Coordinates
    struct Geometry: Decodable {
        let lat: Double
        let lng: Double
    }

    // Place information
    struct Components: Decodable {
        let town: String?
        let city: String?
        let normalizedCity: String?
        let state: String?
        let country: String?
        let countryCode: String?
        let type: String?

        enum CodingKeys: String, CodingKey {
            case town
            case city
            case state
            case country
            case countryCode = "country_code"
            case type = "_type"
            case normalizedCity = "_normalized_city"
        }
    }
}
