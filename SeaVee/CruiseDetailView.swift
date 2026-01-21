//
//  CruiseDetailView.swift
//  SeaVee
//
//  Created by Jessi Draper on 03.12.25.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import OSLog

struct CruiseDetailView: View {

    @State private var portLocationMapItems: [MKMapItem] = []
    @State private var animatedCoords: [CLLocationCoordinate2D] = []
    
    var uniqueCountries: [String] {
        let stops = cruise.itinerary
        let countries = stops.compactMap { $0.country?.trimmingCharacters(in: .whitespacesAndNewlines) }
                                 .filter { !$0.isEmpty }
        return Array(Set(countries)).sorted()
    }
    
    let cruise: Cruise
    
    var body: some View {
        
        VStack(spacing: 0) {
            // MARK: - Cruise Header Card
            VStack(alignment: .leading) {
                Text(cruise.ship)
                    .textCase(.uppercase)
                    .kerning(0.7)
                    .fontWeight(.medium)
                    .font(.caption)
                Text(cruise.title)
                    .font(.title2)
                    .bold()
                HStack {
                    Text("\(cruise.startDate.formatted(date: .abbreviated, time: .omitted)) - \(cruise.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 14))
                    Spacer()
                    Text("\(cruise.itinerary.count) stops | \(uniqueCountries.count) countries")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
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
                                .bold().textCase(.uppercase).font(.system(size: 14))
                                .frame(minWidth: 60, alignment: .leading)
                            Text(stop.port)
                                .font(.system(size: 16))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.blue.opacity(0.07))
            
            // MARK: - Map Area
            Map {
                ForEach(portLocationMapItems, id: \.self) { item in
                    if let coordinate = item.placemark.location?.coordinate {
                        Marker(item.name ?? "Port", systemImage: "ferry.fill", coordinate: coordinate).tint(.blue)
                    }
                }
                
                MapPolyline(coordinates: animatedCoords)
                    .stroke(Color.blue, lineWidth: 3)
            }
            .background(Color.blue.opacity(0.07))
            .onAppear {
                Task {
                    var items: [MKMapItem] = []
                    
                    for stop in cruise.sortedStops {
                        guard let lat = stop.latitude, let lng = stop.longitude else {
                            continue
                        }
                        
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        let placemark = MKPlacemark(coordinate: coordinate)
                        let item = MKMapItem(placemark: placemark)
                        
                        item.name = stop.city ?? stop.state ?? stop.port
                        
                        items.append(item)
                        
                        //                    do {
                        //                        if let item = try await geocodePort(stop.port) {
                        //                            items.append(item)
                        //                        }
                        //                    } catch {
                        //                        let logger = Logger()
                        //                        logger.error("Geocoding failed: \(error)")
                        //                    }
                    }
                    
                    // Add port marker items
                    portLocationMapItems = items
                    
                    // Animate the polyline after ports are ready
                    for coord in items.compactMap({ $0.placemark.location?.coordinate }) {
                        animatedCoords.append(coord)
                        try await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
            
        }
    }
}

@MainActor
private struct PreviewCruiseDetail: View {
    let container: ModelContainer
    let cruise: Cruise

    init() {
        let schema = Schema([Cruise.self, CruiseStop.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        container = try! ModelContainer(for: schema, configurations: config)

        let context = container.mainContext

        cruise = Cruise(
            ship: "SeaVee Ship",
            title: "Mediterranean Highlights",
            startDate: .now,
            endDate: .now.addingTimeInterval(60 * 60 * 24 * 7)
        )

        cruise.itinerary = [
            CruiseStop(date: .now, port: "Departing from Barcelona, Spain"),
            CruiseStop(date: .now.addingTimeInterval(86400), port: "Marseille, France"),
            CruiseStop(date: .now.addingTimeInterval(86400 * 2), port: "Florence, Italy"),
            CruiseStop(date: .now.addingTimeInterval(86400 * 3), port: "Arriving in Rome, Italy")
        ]

        context.insert(cruise)
    }

    var body: some View {
        NavigationStack {
            CruiseDetailView(cruise: cruise)
        }
        .modelContainer(container)
    }
}
#Preview {
    
    PreviewCruiseDetail()
}
