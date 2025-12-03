//
//  Cruise.swift
//  SeaVee
//
//  Created by Jessi Draper on 02.12.25.
//

import Foundation
import SwiftData

@Model
final class Cruise {
    @Attribute(.unique) var id: UUID
    var line: String
    var title: String
    var startDate: Date
    var endDate: Date
    var itinerary: [Date: String]
    
    init(id: UUID = UUID(), line: String = "", title: String = "", startDate: Date = Date(), endDate: Date = Date(), itinerary: [Date: String] = [:]) {
            self.id = id
            self.line = line
            self.title = title
            self.startDate = startDate
            self.endDate = endDate
            self.itinerary = itinerary
        }
}
