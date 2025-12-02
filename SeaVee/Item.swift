//
//  Item.swift
//  SeaVee
//
//  Created by Jessi Draper on 02.12.25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
