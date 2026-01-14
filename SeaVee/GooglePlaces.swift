//
//  GooglePlaces.swift
//  SeaVee
//
//  Created by Jessi Draper on 14.01.26.
//

import Foundation

// Google Places API

// Autocomplete Endpoint
struct AutocompleteResponse: Decodable {
    let suggestions: [Suggestions]
}

struct Suggestions: Decodable {
    let placePrediction: PlacePrediction
    
    struct PlacePrediction: Decodable {
        let placeId: String?
    }
}

// Place Detail Endpoint
struct PlaceResponse: Decodable {
    let addressComponents: [AddressComponents]
    let location: Location
}

struct AddressComponents: Decodable {
    let longText: String?
    let shortText: String?
    let types: [String]?
}

struct Location: Decodable {
    let latitude: Double
    let longitude: Double
}


