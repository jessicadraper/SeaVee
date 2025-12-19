//
//  CruiseInputView.swift
//  SeaVee
//
//  Created by Jessi Draper on 03.12.25.
//

import SwiftUI

struct CruiseInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // user input states
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var ships: [String] = []
    @State private var cruises: [DataRetrievalResponse] = []
    @State private var shipsLoading: Bool = false
    @State private var selectedShip: String = ""
    @State private var isLoading: Bool = false
    @State private var isLoaded: Bool = false
    
    let networking = Networking()
    
    var onSave: () -> Void // closure to dismiss parent
    
    var body: some View {
        Form {
            // MARK: - Dates
            Section(header: Text("Enter your contract dates")
                .textCase(.none)
                .font(.title2)
                .padding(.bottom,6)
                .foregroundColor(.secondary)) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            
            // MARK: - Ship Picker
            Section(
                header: Text("Find your ship")
                    .textCase(.none)
                    .font(.title2)
                    .padding(.bottom,6)
                    .foregroundColor(.secondary)
            ) {
                Picker("Select Ship", selection: $selectedShip) {
                    ForEach(sortedLines, id: \.self) { line in
                        Section(header: Text(line).fontWeight(.bold)) {
                            ForEach(shipsByLine[line]!, id: \.self) { ship in
                                Text(ship)
                                    .tag(ship)
                                    .padding(.leading)
                            }
                        }
                    }
                }
                .pickerStyle(.navigationLink)
                .scrollContentBackground(.hidden)
            }

            
            // MARK: - Import Button
            Section {
                Button(action:importCruisesDev) {
                    if (!isLoading) {
                        Text("Import SeaVee")
                    }
                    else if (isLoading) {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center) // centers button
            }
        }
        .padding(.vertical)
        .navigationTitle("Import SeaVee")
        .scrollContentBackground(.hidden)
        .background(Color.blue.opacity(0.07))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
//        .onChange(of: startDate) {
//            ships = []
//            fetchShips()
//        }
        .onChange(of: endDate) {
            ships = []
            fetchShips()
        }
    }
    
    private func fetchShips() {
        shipsLoading = true
        print("FETCHING SHIPS")
        let apiStartDate = startDate.apiDateString()
        let apiEndDate = endDate.apiDateString()
        
        networking.requestData(start_date: apiStartDate, end_date: apiEndDate) { requestResponse, error in
            DispatchQueue.main.async {
                if let requestResponse = requestResponse {
                    
                    let dataId = requestResponse.data.defaultDatasetId
                    print("Ship fetch data ID: \(dataId)")
                    
                    networking.retrieveData(datasetId: dataId) { retrievalResponse, error in
                        if let retrievalResponse = retrievalResponse {
                            print("Appending ships...")
                            for cruise in retrievalResponse {                                print(cruise.ship_name)
                                cruises.append(cruise)
                            }
                        } else if let error = error {
                            print("Failed getting ships: \(error.localizedDescription)")
                        }
                    }
                }
                print(ships)
            }
        }
        shipsLoading = false
    }
    
    private var shipsByLine: [String: [String]] {
        let grouped = Dictionary(grouping: cruises, by: { $0.cruise_line })
        return grouped.mapValues { cruises in
            let ships = cruises.map { $0.ship_name }
            return Array(Set(ships)).sorted()   // dedupe and sort
        }
    }

    private var sortedLines: [String] {
        shipsByLine.keys.sorted()
    }

    
    private func tryFetchShipsIfNeeded() {
        if startDate != endDate {
            fetchShips()
        }
    }
    
    private func importCruises() {
        isLoading = true;
        let apiStartDate = startDate.apiDateString()
        let apiEndDate = endDate.apiDateString()
        
        networking.requestData(cruise_line: self.selectedShip, start_date: apiStartDate, end_date: apiEndDate) { requestResponse, error in
            DispatchQueue.main.async {
                if let requestResponse = requestResponse {
                    
                    let dataId = requestResponse.data.defaultDatasetId
                    print("Success! Data ID: \(dataId)")
                    
                    networking.retrieveData(datasetId: dataId) { retrievalResponse, error in
                        if let retrievalResponse = retrievalResponse {
                            print("Success!")
                            
                            for cruise in retrievalResponse {
                                let parsedCruise = parseCruiseData(cruise)
                                print("------")
                                print(parsedCruise.title)
                                print(parsedCruise.itinerary)
                                print("------")
                                modelContext.insert(parsedCruise)
                            }
                        } else if let error = error {
                            print("Failed getting cruises: \(error.localizedDescription)")
                        }
                        do {
                            try modelContext.save()
                            print("DATA SAVED")
                            onSave() // dismiss sheet
                        } catch {
                            print("Failed to save cruise: \(error)")
                        }
                    }
                }
            }
        }
        isLoading = false
    }
    
    private func parseCruiseData(_ cruiseData: DataRetrievalResponse) -> Cruise {
        
        // Parse start date; example: "2025 Dec 02"
        let startFormatter = DateFormatter()
        startFormatter.dateFormat = "yyyy MMM dd"
        startFormatter.locale = .init(identifier: "en_US_POSIX")
        
        let startDate = startFormatter.date(from: cruiseData.cruise_date)!
        
        // Get month/year components for determining correct stop years
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: startDate)
        let startMonth = calendar.component(.month, from: startDate)

        
        // Stop date formatter
        let stopDateFormatter = DateFormatter()
        stopDateFormatter.dateFormat = "dd MMM"  // e.g. "02 Dec"
        stopDateFormatter.locale = .init(identifier: "en_US_POSIX")
        stopDateFormatter.timeZone = .gmt

        // Convert to itinerary stops
        var itinerary: [CruiseStop] = []

        for (_, stop) in cruiseData.cruise_stops.sorted(by: { $0.key < $1.key }) {
            let dateString = stop.date
            let text = stop.text

            // Only keep "dd MMM" part, remove times if needed
            let cleanedDate = dateString.components(separatedBy: " ").prefix(2).joined(separator: " ")

            // month day only
            guard let monthDayOnly = stopDateFormatter.date(from: cleanedDate) else { continue }
            
            let stopMonth = calendar.component(.month, from: monthDayOnly)
            let stopDay   = calendar.component(.day,   from: monthDayOnly)
            
            // Determine correct year, if stop month < start month → we're in next year
            let stopYear = (stopMonth < startMonth) ? (startYear + 1) : startYear

            // Build date with correct year
            var comps = DateComponents()
            comps.year = stopYear
            comps.month = stopMonth
            comps.day = stopDay
            comps.timeZone = .gmt
            
            guard let finalStopDate = calendar.date(from: comps) else { continue }
            
            itinerary.append(CruiseStop(date: finalStopDate, port: text))
        }

        // Get last date in itinerary
        let endDate = itinerary.last?.date ?? startDate
        
        // Sort itinerary by date
        let sortedItinerary = itinerary.sorted { $0.date < $1.date }

        // Return Cruise data model item
        return Cruise(
            line: cruiseData.cruise_line,
            title: cruiseData.cruise_title,
            startDate: startDate,
            endDate: endDate,
            itinerary: sortedItinerary
        )
    }
    
    private func importCruisesDev() {
        isLoading = true;
        var n = 0;
        
        networking.retrieveData(datasetId: "2jbsrw50kdWbbCh8Z") { retrievalResponse, error in
            DispatchQueue.main.async {
                if let retrievalResponse = retrievalResponse {
                    print("Success!")
                    
                    for cruise in retrievalResponse {
                        let parsedCruise = parseCruiseData(cruise)
                        print(parsedCruise.title)
                        print("------")
                        for stop in parsedCruise.itinerary {
                            print("\(stop.date) - \(stop.port)")
                        }
                        print("------")
                        n = n + 1
                        modelContext.insert(parsedCruise)
                    }
                } else if let error = error {
                    print("Failed getting cruises: \(error.localizedDescription)")
                }
                
                do {
                    try modelContext.save()
                    print("DATA SAVED: \(n) Cruises")
                    onSave() // dismiss sheet
                } catch {
                    print("Failed to save cruise: \(error)")
                }
            }
        }
        isLoading = false
    }
}

#Preview {
    CruiseInputView(onSave: { })
        .modelContainer(for: Cruise.self, inMemory: true)
}
