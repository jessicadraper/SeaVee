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
                ForEach(sortedItinerary, id: \.0) { date, port in
                    HStack {
                        Text(date, format: .dateTime.month().day())
                        Spacer()
                        Text(port)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.blue.opacity(0.07))
        
        // MARK: - Map Area
        Text("Loading map...")
    }
    
    var sortedItinerary: [(Date, String)] {
        cruise.itinerary.sorted { $0.key < $1.key }
    }
}

#Preview {
    let sampleCruise = Cruise(
        line: "Disney Cruise Line",
        title: "Bahamas 3-Night Getaway",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
        itinerary: [
            Date(): "Port Canaveral",
            Calendar.current.date(byAdding: .day, value: 1, to: Date())!: "Nassau",
            Calendar.current.date(byAdding: .day, value: 2, to: Date())!: "Castaway Cay"
        ]
    )
    
    CruiseDetailView(cruise: sampleCruise)
}
