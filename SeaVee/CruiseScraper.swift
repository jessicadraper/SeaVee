//
//  CruiseScraper.swift
//  SeaVee
//
//  Created by Jessi Draper on 03.12.25.
//

import Foundation

// CruiseMapper API Responses

struct DataRequestResponse: Decodable {
    let data: DataResponse
    
    struct DataResponse: Codable {
        let defaultDatasetId: String
    }
}

struct DataRetrievalResponse: Decodable {
    let id: String
    let ship_name: String
    let cruise_date: String
    let cruise_title: String
    let cruise_price: String
    let cruise_line: String
    
    let cruise_stops: [Int: (date: String, text: String)]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

            // Decode fixed values
            id           = try container.decode(String.self, forKey: DynamicCodingKeys("id"))
            ship_name    = try container.decode(String.self, forKey: DynamicCodingKeys("ship_name"))
            cruise_date  = try container.decode(String.self, forKey: DynamicCodingKeys("cruise_date"))
            cruise_title = try container.decode(String.self, forKey: DynamicCodingKeys("cruise_title"))
            cruise_price = try container.decode(String.self, forKey: DynamicCodingKeys("cruise_price"))
            cruise_line  = try container.decode(String.self, forKey: DynamicCodingKeys("cruise_line"))

            // Parse stops dynamically
            var stops: [Int: (String, String)] = [:]

            for key in container.allKeys {
                if key.stringValue.starts(with: "stop_") {
                    let parts = key.stringValue.split(separator: "_")   // ["stop", "1", "date"]
                    guard parts.count == 3 else { continue }

                    let index = Int(parts[1]) ?? 0
                    let field = parts[2]   // "date" or "text"

                    var value = try container.decode(String.self, forKey: key)
                    
                    if field == "text" {
                        let prefixes = ["departing from ", "arriving in "]

                        for prefix in prefixes {
                            if value.lowercased().hasPrefix(prefix) {
                                value = String(value.dropFirst(prefix.count))
                                break // only remove the first matching prefix
                            }
                        }
                        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    var entry = stops[index] ?? ("", "")
                    if field == "date" { entry.0 = value }
                    else if field == "text" { entry.1 = value }

                    stops[index] = entry
                }
            }
            
            cruise_stops = stops
        }
}


/// Needed to parse unknown keys
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { return nil }
}

extension DateFormatter {
  static let iso8601Full: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}

extension Date {
    func apiDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
