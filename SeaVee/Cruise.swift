//
//  Cruise.swift
//  SeaVee
//
//  Created by Jessi Draper on 02.12.25.
//

import Foundation
import SwiftData

@Model
final class CruiseStop {
    @Attribute(.unique) var id: UUID
    var date: Date
    var port: String
    
    // Persisted geocode fields
   var latitude: Double?
   var longitude: Double?
   var confidence: Int?
   var city: String?
   var state: String?
   var country: String?
    @Relationship var cruise: Cruise?
    
    init(id: UUID = UUID(), date: Date = Date(), port: String = "") {
        self.id = id
        self.date = date
        self.port = port
    }
}

@Model
final class Cruise {
    @Attribute(.unique) var id: UUID
    var ship: String
    var title: String
    var startDate: Date
    var endDate: Date
    @Relationship(deleteRule: .cascade)
    var itinerary: [CruiseStop]
    
    init(id: UUID = UUID(),
         ship: String = "",
         title: String = "",
         startDate: Date = Date(),
         endDate: Date = Date(),
         itinerary: [CruiseStop] = []) {
            self.id = id
            self.ship = ship
            self.title = title
            self.startDate = startDate
            self.endDate = endDate
            self.itinerary = itinerary
        }
}

extension Cruise {
    var sortedStops: [CruiseStop] {
        itinerary.sorted { $0.date < $1.date }
    }
}
