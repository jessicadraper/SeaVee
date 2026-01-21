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
//    @State private var ships: [String] = []
    @State private var cruises: [DataRetrievalResponse] = []
    @State private var shipsLoading: Bool = false
    @State private var shipSearchText = ""
    @State private var selectedShip: String = "Crystal Serenity"
    @State private var isLoading: Bool = false
    @State private var isLoaded: Bool = false
    @State private var showNoCruisesAlert = false
    
    let networking = Networking()
    
    var filteredShips: [String] {
        if shipSearchText.isEmpty {
            ships
        } else {
            ships.filter {
                $0.localizedCaseInsensitiveContains(shipSearchText)
            }
        }
    }
    
    var onSave: () -> Void // closure to dismiss parent
    
    var body: some View {
        Form {
            // MARK: - Dates
            Section(header: Label("Enter contract dates", systemImage: "calendar")
                .textCase(.none)
                .font(.title2)
                .padding(.bottom,6)
                .foregroundColor(.secondary)) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            
            // MARK: - Ship Picker
            Section(
                header: Label("Find your ship", systemImage: "ferry.fill")
                    .textCase(.none)
                    .font(.title2)
                    .padding(.bottom,6)
                    .foregroundColor(.secondary)
            ) {
                NavigationLink {
                    ShipPickerView(
                        ships: ships,
                        selectedShip: $selectedShip
                    )
                } label: {
                    HStack {
                        Text("Select Ship")
                        Spacer()
                        Text(selectedShip.isEmpty ? "None" : selectedShip)
                            .foregroundColor(.secondary)
                    }
                }
            }
            

            
            // MARK: - Import Button
            Section {
                Button(action: importCruises) {
                    HStack {
                        if !isLoading {
                            Image(systemName: "ferry.fill") // Ship/ferry icon
                                .foregroundColor(.white)
                            Text("Import SeaVee")
                                .foregroundColor(.white)
                                .bold()
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .frame(maxWidth: .infinity) // Make button full-width
                    .padding()                  // Add padding inside button
                    .background(Color.blue)     // Solid blue background
                    .cornerRadius(10)           // Rounded corners
                }
                .listRowBackground(Color.clear)
                .buttonStyle(PlainButtonStyle()) // Remove default button styling
                .alert("No Cruises Found",
                       isPresented: $showNoCruisesAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("No cruises found for this ship and time period. Please try again.")
                }
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
    }

    
    private func importCruises() {
        isLoading = true;
        var n = 0;
        
        let apiStartDate = startDate.apiDateString()
        let apiEndDate = endDate.apiDateString()
        
        networking.requestData(ship_name: self.selectedShip, start_date: apiStartDate, end_date: apiEndDate) { requestResponse, error in
            DispatchQueue.main.async {
                guard let requestResponse else {
                    print("Request failed: \(error?.localizedDescription ?? "unknown")")
                    isLoading = false
                    return
                }
                
                let dataId = requestResponse.data.defaultDatasetId
                print("Success! Data ID: \(dataId)")
                    
                // delay data retrieval
                DispatchQueue.global().asyncAfter(deadline: .now() + 6.0) {
                    
                    networking.retrieveData(datasetId: dataId) { retrievalResponse, error in
                        DispatchQueue.main.async {
                            guard let retrievalResponse else {
                                print("Failed getting cruises: \(error?.localizedDescription ?? "unknown")")
                                isLoading = false
                                return
                            }
                            
                            print("Success retrieving data!")
     
                            for cruise in retrievalResponse {
                                let parsedCruise = parseCruiseData(cruise, start: startDate, end: endDate)
                                if (parsedCruise.itinerary.count > 0) {
                                    print(parsedCruise.title)
                                    print("------")
                                    for stop in parsedCruise.itinerary {
                                        print("\(stop.date) - \(stop.port)")
                                    }
                                    print("------")
                                    n = n + 1
                                    modelContext.insert(parsedCruise)
                                }
                            }

                            do {
                                if n == 0 {
                                    print("No cruises returned")
                                    showNoCruisesAlert = true
                                } else {
                                    try modelContext.save()
                                    print("DATA SAVED: \(n) Cruises")
                                    onSave() // dismiss sheet
                                }
                            } catch {
                                print("Failed to save cruise: \(error)")
                            }
                            
                            isLoading = false
                            
                        }
                    }
                }
            }
        }
    }
    
    private func getPlaceData(cruiseStop: CruiseStop) {
        print("Searching place data for: \(cruiseStop.port)")
        networking.searchPlace(input: cruiseStop.port) { autocompleteResponse, error in
            DispatchQueue.main.async {
                
                guard let response = autocompleteResponse,
                      let suggestion = response.suggestions.first else {
                    print("No place suggestions for: \(cruiseStop.port)")
                    return
                }

                guard let placeId = suggestion.placePrediction.placeId else {
                    print("Missing place ID")
                    return
                }

                print("Place ID fetched: \(placeId)")
                
                self.networking.getPlaceDetails(placeId: placeId) { placeResponse, error in
                    DispatchQueue.main.async {
                        guard let placeResponse else {
                            print("Failed getting place details: \(error?.localizedDescription ?? "unknown")")
                            return
                        }
                        
                        print("Fetched details: \(placeResponse.addressComponents)")
                        cruiseStop.latitude = placeResponse.location.latitude
                        cruiseStop.longitude = placeResponse.location.longitude
                        
                        for component in placeResponse.addressComponents {
                            if let types = component.types {
                                if types.contains("country") {
                                    cruiseStop.country = component.longText
                                }
                                
                                if types.contains("locality") {
                                    cruiseStop.city = component.longText
                                }
                                
                                if types.contains("administrative_area_level_1") {
                                    cruiseStop.state = component.longText
                                }
                            }
                        }
                        
                        print("Successfully geocoded: \(cruiseStop.port)")
                        print("------------------------------------")
                    }
                }
            }
        }
    }
    
    private func parseCruiseData(_ cruiseData: DataRetrievalResponse, start: Date, end: Date) -> Cruise {
        
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
            
            // Confirm the date is within the specified contract date range
            let isBetween = (start...end).contains(finalStopDate)
            if (isBetween) {
                print("Cruise stop on \(finalStopDate) is between \(start) and \(end)")
                let cruiseStop = CruiseStop(date: finalStopDate, port: text)
                itinerary.append(cruiseStop) // add to itinerary
                getPlaceData(cruiseStop: cruiseStop) // Geocode port text
            } else {
                print("Stop not within contract dates -- skipping!")
            }
        }

        // Get last date in itinerary
        let endDate = itinerary.last?.date ?? startDate
        
        // Sort itinerary by date
        let sortedItinerary = itinerary.sorted { $0.date < $1.date }

        // Return Cruise data model item
        return Cruise(
            ship: cruiseData.ship_name,
            title: cruiseData.cruise_title,
            startDate: startDate,
            endDate: endDate,
            itinerary: sortedItinerary
        )
    }
}

struct ShipPickerView: View {
    let ships: [String]
    @Binding var selectedShip: String

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var filteredShips: [String] {
        searchText.isEmpty
            ? ships
            : ships.filter {
                $0.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        List(filteredShips, id: \.self) { ship in
            Button {
                selectedShip = ship
                dismiss()
            } label: {
                HStack {
                    Text(ship)
                    Spacer()
                    if ship == selectedShip {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search ships")
    }
}


#Preview {
    CruiseInputView(onSave: { })
        .modelContainer(for: Cruise.self, inMemory: true)
}
