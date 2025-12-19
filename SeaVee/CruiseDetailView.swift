//
//  CruiseDetailView.swift
//  SeaVee
//
//  Created by Jessi Draper on 03.12.25.
//

import SwiftUI

struct CruiseDetailView: View {
    let cruise: Cruise
    
    var body: some View {
        
        // MARK: - Cruise Header Card
        VStack(alignment: .leading) {
            Text(cruise.line)
                .textCase(.uppercase)
                .kerning(0.7)
                .fontWeight(.medium)
                .font(.caption)
            Text(cruise.title)
                .font(.title2)
                .bold()
            HStack {
                Text("\(cruise.startDate.formatted(date: .abbreviated, time: .omitted)) - \(cruise.endDate.formatted(date: .abbreviated, time: .omitted))")
                Spacer()
                Text("\(cruise.itinerary.count) ports")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
        .padding()
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
        
        // MARK: - Cruise Itinerary List
        List {
            Section("Cruise Itinerary") {
                ForEach(cruise.sortedStops, id: \.id) { stop in
                    HStack {
                        Text(stop.date, format: .dateTime.month().day())
                        Spacer()
                        Text(stop.port)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.opacity(0.07))
        
        // MARK: - Map Area
        Text("Loading map...")
    }
}

#Preview {
    let sampleCruise = Cruise()
    
    CruiseDetailView(cruise: sampleCruise)
}
