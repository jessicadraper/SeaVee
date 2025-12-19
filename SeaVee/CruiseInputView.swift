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
    @State private var selectedShip: String = "Seabourn Ovation"
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
                    ForEach(ships, id: \.self) { ship in
                        Text(ship)
                            .tag(ship)
                            .padding(.leading)
                    }
                }
                .pickerStyle(.navigationLink)
                .scrollContentBackground(.hidden)
            }

            
            // MARK: - Import Button
            Section {
                Button(action:importCruises) {
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
//        .onChange(of: endDate) {
//            ships = []
//            fetchShips()
//        }
    }
    
    private func fetchShips() {
        shipsLoading = true
        print("FETCHING SHIPS")
//        let apiStartDate = startDate.apiDateString()
//        let apiEndDate = endDate.apiDateString()
        
        // DYNAMIC LOADING - now restricted due to API changes
//        networking.requestData(start_date: apiStartDate, end_date: apiEndDate) { requestResponse, error in
//            DispatchQueue.main.async {
//                if let requestResponse = requestResponse {
//                    
//                    let dataId = requestResponse.data.defaultDatasetId
//                    print("Ship fetch data ID: \(dataId)")
//                    
//                    networking.retrieveData(datasetId: dataId) { retrievalResponse, error in
//                        if let retrievalResponse = retrievalResponse {
//                            print("Appending ships...")
//                            for cruise in retrievalResponse {
//                                print(cruise.ship_name)
//                                cruises.append(cruise)
//                            }
//                        } else if let error = error {
//                            print("Failed getting ships: \(error.localizedDescription)")
//                        }
//                    }
//                }
//                print(ships)
//            }
//        }
        
        // CALL EXISTING API DATA (LARGE LIST)
        let dataId = "Jr8uKuI0iI4Q1SzEU"
        print("Ship fetch data ID: \(dataId)")
        networking.retrieveData(datasetId: dataId) { retrievalResponse, error in
            DispatchQueue.main.async {
                if let retrievalResponse = retrievalResponse {
                    print("Appending ships...")
                    for cruise in retrievalResponse {
                        print(cruise.ship_name)
                        cruises.append(cruise)
                    }
                } else if let error = error {
                    print("Failed getting ships: \(error.localizedDescription)")
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

                            do {
                                try modelContext.save()
                                print("DATA SAVED: \(n) Cruises")
                                onSave() // dismiss sheet
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
                            if component.types.contains("country") {
                                cruiseStop.country = component.longText
                            }
                            
                            if component.types.contains("locality") {
                                cruiseStop.city = component.longText
                            }
                            
                            if component.types.contains("administrative_area_level_1") {
                                cruiseStop.state = component.longText
                            }
                        }
                        
                        print("Successfully geocoded: \(cruiseStop.port)")
                        print("------------------------------------")
                    }
                }
            }
        }
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
            
            let cruiseStop = CruiseStop(date: finalStopDate, port: text)
            itinerary.append(cruiseStop)
                             
            // Geocode port text
            getPlaceData(cruiseStop: cruiseStop)
            
//            networking.geocodeData(query: text) { geocodeResponse, error in
//                DispatchQueue.main.async {
//                    if let geocodeResponse = geocodeResponse {
//                        if let result = geocodeResponse.results.first {
//                            cruiseStop.latitude = result.geometry.lat
//                            cruiseStop.longitude = result.geometry.lng
//                            cruiseStop.confidence = result.confidence
//                            cruiseStop.city = result.components.city ?? result.components.town ?? result.components.normalizedCity
//                            cruiseStop.state = result.components.state
//                            cruiseStop.country = result.components.country
//                            
//                            print("Geocoded: \(String(describing: cruiseStop.city)), \(String(describing: cruiseStop.country)) (conf: \(String(describing: cruiseStop.confidence))")
//                        }
////                        for result in results {
////                            if (result.components.town != nil || result.components.city != nil || result.components.normalizedCity != nil || result.components.state != nil) {
////                                cruiseStop.latitude = result.geometry.lat
////                                cruiseStop.longitude = result.geometry.lng
////                                cruiseStop.confidence = result.confidence
////                                cruiseStop.city = result.components.city ?? result.components.town ?? result.components.normalizedCity
////                                cruiseStop.state = result.components.state
////                                cruiseStop.country = result.components.country
////                                
////                                print("Geocoded: \(String(describing: cruiseStop.city)), \(String(describing: cruiseStop.country)) (conf: \(String(describing: cruiseStop.confidence))")
////                            } else {
////                                print("NOT A CITY, SKIPPING: \(String(describing: result.components))")
////                            }
////                        }
//                    } else if let error = error {
//                        print("Failed geocoding: \(error.localizedDescription)")
//                    }
//                }
//            }
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
    
    private func importCruisesDev() {
        isLoading = true;
        var n = 0;
        
//        2jbsrw50kdWbbCh8Z
//        OnG3NqUeEV6SU7Hyp
        networking.retrieveData(datasetId: "OnG3NqUeEV6SU7Hyp") { retrievalResponse, error in
            DispatchQueue.main.async {
                guard let retrievalResponse else {
                    print("Failed getting cruises: \(error?.localizedDescription ?? "unknown")")
                    isLoading = false
                    return
                }
                
                print("Success retrieving data!")

                for cruise in retrievalResponse {
                    print(cruise)
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

                do {
                    try modelContext.save()
                    print("DATA SAVED: \(n) Cruises")
                    onSave() // dismiss sheet
                } catch {
                    print("Failed to save cruise: \(error)")
                }
                
                isLoading = false
            }
        }
    }
    
    let ships = ["50 Let Pobedy icebreaker", "Abel Matutes ferry", "ACL American Anthem", "ACL American Constellation", "ACL American Constitution", "ACL American Eagle", "ACL American Encore", "ACL American Glory", "ACL American Harmony", "ACL American Jazz", "ACL American Legend", "ACL American Liberty", "ACL American Maverick", "ACL American Melody", "ACL American Patriot", "ACL American Pioneer", "ACL American Ranger", "ACL American Serenade", "ACL American Song", "ACL American Symphony", "Admiral Makarov icebreaker", "Admiralty Dream", "Adora Flora City", "Adora Magic City", "Adora Mediterranea", "Adriatic Princess 2 yacht", "Adriatic Princess yacht", "Adventure Of The Seas", "Aegean Majesty", "Aegean Paradise", "African Dream", "AIDAbella", "AIDAblu", "AIDAcosma", "AIDAdiva", "AIDAluna", "AIDAmar", "AIDAnova", "AIDAperla", "AIDAprima", "AIDAsol", "AIDAstella", "Akademik Fyodorov icebreaker", "Akademik Ioffe icebreaker", "Akademik Sergey Vavilov icebreaker", "Akademik Shokalskiy", "Akademik Tryoshnikov icebreaker", "Akka ferry", "Alaskan Dream", "Alasuinu ferry", "Albatros", "Albayzin ferry", "Aleksandr Sannikov icebreaker", "Aleksey Chirikov icebreaker", "Allure Of The Seas", "Almariya ferry", "AmaBella", "AmaCello", "AmaCerto", "AmaDagio", "AmaDahlia", "AmaDante", "AmaDara", "Amadea", "Amadeus Amara", "Amadeus Aurea", "Amadeus Brilliant", "Amadeus Cara", "Amadeus Diamond", "Amadeus Elegant", "Amadeus Imperial", "Amadeus Nova", "Amadeus Provence", "Amadeus Queen", "Amadeus Riva", "Amadeus Royal", "Amadeus Silver", "Amadeus Silver II", "Amadeus Silver III", "Amadeus Star", "Amadeus Symphony", "AmaDolce", "AmaDouro", "AmaKristina", "AmaLea", "AmaLilia", "AmaLotus", "AmaLucia", "AmaLyra", "AmaMagdalena", "AmaMagna", "AmaMelodia", "AmaMora", "AmaPrima", "AmaPura", "AmaReina", "AmaSerena", "AmaSiena", "AmaSintra", "AmaSonata", "AmaStella", "Amatista Amazon", "AmaVenita", "AmaVerde", "AmaVida", "AmaViola", "Amazon Clipper Premium", "Amazon Dream", "Ambience", "Ambition", "Amera", "American Countess", "American Duchess", "American Empress", "American Glory", "American Heritage", "American Independence", "American Pride", "American Queen ", "American Spirit", "American Splendor", "American Star", "American West", "Americana", "Amusement World", "Andaman Explorer", "Andrey Vilkitsky icebreaker", "Anemos ferry", "Anjodi barge", "Anne Marie barge", "Anthem of the Seas", "APT Ostara", "APT Solara", "Aqua Blu", "Aqua Mare Galapagos", "Aqua Mekong", "Aqua Nera", "Aranui 3", "Aranui 5", "Aranui AraMana", "Araon icebreaker", "Arcadia", "Aria Amazon", "Armorique ferry", "Arosa Alea", "Arosa Alva", "Arosa Aqua", "Arosa Bella", "Arosa Brava", "Arosa Clea", "Arosa Donna", "Arosa Flora", "Arosa Luna", "Arosa Mia", "Arosa Riva", "Arosa Sena", "Arosa Silva", "Arosa Stella", "Arosa Viva", "Aroya Manara", "Artania", "Arvia", "Astoria Grande", "Asuka 2", "Asuka 3", "Athena Seaways ferry", "Athos barge", "Atlantic Vision ferry", "Aura Seaways ferry", "Aurora", "Aurora Australis icebreaker", "Aurora Borealis icebreaker", "Aurora Botnia ferry", "Avalon Alegria", "Avalon Artistry II", "Avalon Envision", "Avalon Expression", "Avalon Illumination", "Avalon Imagery II", "Avalon Impression", "Avalon Myanmar", "Avalon Panorama", "Avalon Passion", "Avalon Poetry II", "Avalon Saigon", "Avalon Siem Reap", "Avalon Tapestry II", "Avalon Tranquility II", "Avalon View", "Avalon Visionary", "Avalon Vista", "Azamara Journey", "Azamara Onward", "Azamara Pursuit", "Azamara Quest", "Azura", "Bahama Mama ferry", "Baie de Seine ferry", "Baltic Princess ferry", "Baltic Queen ferry", "Baltika icebreaker", "Baranof Dream", "Barfleur ferry", "Bella Fortuna", "Belmond Alouette barge", "Belmond Amaryllis barge", "Belmond Fleur de Lys barge", "Belmond Hirondelle barge", "Belmond Lilas barge", "Belmond Napoleon barge", "Belmond Orcaella", "Belmond Pivoine barge", "Belmond Road to Mandalay", "Black Watch", "Blue Dream Melody", "Blue Dream Star", "Blue Galaxy ferry", "Blue Horizon ferry", "Blue Puttees ferry", "Blue Sapphire", "Blue Star 1 ferry", "Blue Star 2 ferry", "Blue Star Chios ferry", "Blue Star Delos ferry", "Blue Star Mykonos ferry", "Blue Star Naxos ferry", "Blue Star Paros ferry", "Blue Star Patmos ferry", "Boudicca", "Bretagne ferry", "Brilliance Of The Seas", "Brilliant Lady", "Britannia", "Calais Seaways ferry", "Caledonian Sky", "Canadian Empress", "Cap Finistere ferry", "Caribbean Princess", "Carnival Adventure", "Carnival Breeze", "Carnival Celebration", "Carnival Conquest", "Carnival Dream", "Carnival Ecstasy", "Carnival Elation", "Carnival Encounter", "Carnival Fantasy", "Carnival Fascination", "Carnival Firenze", "Carnival Freedom", "Carnival Glory", "Carnival Horizon", "Carnival Imagination", "Carnival Inspiration", "Carnival Jubilee", "Carnival Legend", "Carnival Liberty", "Carnival Luminosa", "Carnival Magic", "Carnival Mardi Gras", "Carnival Miracle", "Carnival Panorama", "Carnival Paradise", "Carnival Pride", "Carnival Radiance", "Carnival Sensation", "Carnival Spirit", "Carnival Splendor", "Carnival Sunrise", "Carnival Sunshine", "Carnival Tropicale", "Carnival Valor", "Carnival Venezia", "Carnival Vista", "Catania ferry", "CCGS John G Diefenbaker icebreaker", "CCGS Terry Fox icebreaker", "Celebrity Apex", "Celebrity Ascent", "Celebrity Beyond", "Celebrity Constellation", "Celebrity Eclipse", "Celebrity Edge", "Celebrity Equinox", "Celebrity Flora", "Celebrity Infinity", "Celebrity Millennium", "Celebrity Reflection", "Celebrity Silhouette", "Celebrity Solstice", "Celebrity Summit", "Celebrity Xcel", "Celestyal Crystal", "Celestyal Discovery", "Celestyal Journey", "Century Legend", "Century Paragon", "CFC Renaissance", "Chichagof Dream", "Chinese Taishan", "Ciudad de Palma ferry", "Ciudad de Valencia ferry", "Clair de Lune barge", "Club Med 2", "Clydebuilt MS Dark Island", "CMV Astor", "CMV Astoria", "CMV Columbus", "CMV Magellan", "CMV Marco Polo", "Coastal Celebration ferry", "Coastal Inspiration ferry", "Coastal Renaissance ferry", "Color Fantasy ferry", "Color Hybrid ferry", "Color Magic ferry", "Color Viking ferry", "Commodore Clipper ferry", "Connemara ferry", "Coral Adventurer", "Coral Discoverer", "Coral Geographer", "Coral Princess", "Cordelia Empress", "Costa Concordia", "Costa Deliziosa", "Costa Diadema", "Costa Fascinosa", "Costa Favolosa", "Costa Fortuna", "Costa neoRomantica", "Costa Pacifica", "Costa Serena", "Costa Smeralda", "Costa Toscana", "Costa Victoria", "Cote D'Albatre ferry", "Cote d'Opale ferry", "Cote des Dunes ferry", "Cote des Flandres ferry", "Cotentin ferry", "Cracovia ferry", "Crown Iris", "Crown Princess", "Crown Seaways ferry", "Cruise Ausonia ferry", "Cruise Barcelona ferry", "Cruise Bonaria ferry", "Cruise Europa ferry", "Cruise Olbia ferry", "Cruise Olympia ferry", "Cruise Roma ferry", "Cruise Smeralda ferry", "Crystal Serenity", "Crystal Symphony", "CTN Tanit ferry", "Daniele barge", "Danielle Casanova ferry", "DCS Alemannia", "DCS Amethyst", "DCS Amethyst Classic", "Deborah barge", "Delfin 2 Amazon", "Delfin 3 Amazon", "Delft Seaways ferry", "Delta Queen", "Denia Ciutat Creativa ferry", "Diamond Princess", "Dikson icebreaker", "Discovery Princess", "Disney Adventure", "Disney Destiny", "Disney Dream", "Disney Fantasy", "Disney Magic", "Disney Treasure", "Disney Wish", "Disney Wonder", "Douglas Mawson", "Dover Seaways ferry", "Dream Goddess", "Drotten ferry", "Dudinka icebreaker", "Dunkerque Seaways ferry", "Eastern Venus", "Ecoship", "Ecoventura MV EVOLVE Galapagos", "Ecoventura MV ORIGIN Galapagos", "Ecoventura MV THEORY Galapagos", "Elixir Elysium yacht", "Elyros ferry", "Emerald Astra", "Emerald Azzurra", "Emerald Dawn", "Emerald Destiny", "Emerald Harmony", "Emerald Kaia", "Emerald Liberte", "Emerald Luna", "Emerald Princess", "Emerald Radiance", "Emerald Sakara", "Emerald Sky", "Emerald Star", "Emerald Sun", "Enchante barge", "Enchanted Princess", "Enchantment Of The Seas", "Epsilon ferry", "Estrella del Mar Galapagos", "Euroferry Corfu", "Euroferry Egnazia", "Euroferry Olympia", "Europalink ferry", "Explorer Of The Seas", "Exploris One", "Fedor Ushakov icebreaker", "Festos Palace ferry", "Finesse barge", "Finlandia ferry", "Finncanopus ferry", "Finnclipper ferry", "Finnfellow ferry", "Finnlady ferry", "Finnmaid ferry", "Finnpartner ferry", "Finnsirius ferry", "Finnstar ferry", "Finnswan ferry", "Finntrader ferry", "Florencia ferry", "Fortuny ferry", "Forza ferry", "Four Seasons 1", "Four Seasons Explorer", "Fred Olsen Balmoral", "Fred Olsen Bolette", "Fred Olsen Borealis", "Freedom Of The Seas", "Funchal", "Galapagos Legend", "Galicia ferry", "Ganges Voyager 2", "Gennadiy Nevelskoy icebreaker", "Genting Dream", "GNV Allegra ferry", "GNV Antares ferry", "GNV Aries ferry", "GNV Atlas ferry", "GNV Azzurra ferry", "GNV Bridge ferry", "GNV Cristal ferry", "GNV Excellent ferry", "GNV Excelsior ferry", "GNV Fantastic ferry", "GNV La Superba ferry", "GNV La Suprema ferry", "GNV Majestic ferry", "GNV Rhapsody ferry", "GNV Sealand ferry", "GNV Splendid ferry", "Goddess of the Night", "Golden Horizon", "Golden Iris", "Gotland ferry", "Grand Celebration", "Grand Princess", "Grande Caribe", "Grande Mariner", "Grandeur Of The Seas", "Green Ship Nils Holgersson ferry", "Green Ship Peter Pan ferry", "Greg Mortimer", "Guillaume de Normandie ferry", "Hamnavoe ferry", "Hanseatic Inspiration", "Hanseatic Nature", "Hanseatic Spirit", "Harmony Of The Seas", "Havila Capella ferry", "Havila Castor ferry", "Havila Polaris ferry", "Havila Pollux ferry", "Hebridean Princess", "Hebridean Sky", "Hedy Lamarr ferry", "Hellenic Spirit ferry", "Heritage Adventurer", "Highlanders ferry", "Hjaltland ferry", "HMS Prince of Wales aircraft carrier", "HMS Queen Elizabeth aircraft carrier", "Hrossey ferry", "Huckleberry Finn ferry", "Hypatia de Alejandria ferry", "Icon Of The Seas", "Independence Of The Seas", "Iona", "Isabelle X", "Island Escape yacht", "Island Princess", "Island Sky", "Isle of Inishmore ferry", "Jean Nicoli ferry", "Jeanine barge", "Jewel Of The Seas", "JSC Admiral Nevelskoy ferry", "JSC Pavel Leonov ferry", "Juan J Sister ferry", "Kapitan Dranitsyn icebreaker", "Kapitan Khlebnikov icebreaker", "Kapitan Nikolaev icebreaker", "Kapitan Sorokin icebreaker", "King Seaways ferry", "Knossos Palace ferry", "Knyaz Vladimir", "Kontio icebreaker", "Krasin icebreaker", "Kronprins Haakon icebreaker", "Kruzof Explorer", "L'Art de Vivre barge", "L'Astrolabe icebreaker", "L'Austral", "L'Impressionniste barge", "La Bella Vita barge", "La Belle Epoque barge", "La Nouvelle Etoile barge", "La Pinta Galapagos", "La Renaissance barge", "Le Bellot", "Le Boreal", "Le Bougainville", "Le Champlain", "Le Commandant Charcot", "Le Dumont dUrville", "Le Jacques Cartier", "Le Laperouse", "Le Lyrial", "Le Ponant", "Le Soleal", "Legend Of The Seas", "Leif Ericson ferry", "Leisure World", "Liberty Of The Seas", "Lisboa", "Lord of the Glens", "Louis Aura", "Luna Seaways ferry", "Madeleine barge", "Magadan icebreaker", "Magna Carta barge", "Majestic Princess", "Majesty Of The Seas", "Manxman ferry", "Marella Celebration", "Marella Discovery", "Marella Discovery 2", "Marella Dream", "Marella Explorer", "Marella Explorer 2", "Marella Voyager", "Margaritaville Islander", "Margaritaville Paradise", "Marie Curie ferry", "Mariner Of The Seas", "Martin i Soler ferry", "Mazovia ferry", "Mecklenburg-Vorpommern ferry", "Mega Express 1 ferry", "Mega Express 2 ferry", "Mega Express 3 ferry", "Mega Regina ferry", "Mega Victoria ferry", "Mein Schiff 1", "Mein Schiff 2", "Mein Schiff 3", "Mein Schiff 4", "Mein Schiff 5", "Mein Schiff 6", "Mein Schiff 7", "Mein Schiff Flow", "Mein Schiff Relax", "Mitsui Ocean Fuji", "Moby Aki ferry", "Moby Corse ferry", "Moby Dada ferry", "Moby Drea ferry", "Moby Fantasy ferry", "Moby Kiss ferry", "Moby Legacy ferry", "Moby Niki ferry", "Moby Otta ferry", "Moby Tommy ferry", "Moby Vincent ferry", "Moby Wonder ferry", "Moby Zaza ferry", "Monserrat Galapagos", "Mont St Michel ferry", "Moskva icebreaker", "Movenpick MS Darakum", "Movenpick MS Hamees", "Movenpick MS Prince Abbas", "Movenpick SS Misr", "MPS Rotterdam", "MPS Salvinia", "MPS Statendam", "MS Adora", "MS Afanasy Nikitin", "MS Aleksandr Benua", "MS Alena", "MS Alessia", "MS Alexander Pushkin", "MS Alexander Radishchev", "MS Alina", "MS Alisa", "ms Amalia Rodrigues", "MS Amelia", "MS Amina", "MS Amwaj Livingstone", "MS Andorinha", "MS Andrea", "MS Anesha", "MS Anna Katharina", "MS Annabelle", "MS Annika", "MS Anton Bruckner", "MS Anton Chekhov", "MS Antonia", "MS Antonio Bellucci", "MS Ariana", "MS Asara", "MS Aurelia", "ms Beethoven", "MS Bellejour", "MS Bellissima", "MS Bellriva", "MS Belvedere", "MS Bergensfjord ferry", "MS Bijou du Rhone", "MS Birka Gotland", "MS Bizet", "MS Bolero", "ms Botticelli", "MS Brabant", "MS Bruckmadl", "MS Calypso", "ms Camargue", "MS Carissima", "MS Carmen", "MS Casanova", "MS Charles Dickens", "MS Crucelake-Lebedinoe Ozero", "MS Crucestar", "MS Crucevita", "ms Cyrano de Bergerac", "MS Danubia", "MS De Amsterdam", "MS Delphin", "MS Der Kleine Prinz", "MS Deutschland-World Odyssey", "MS Dmitry Furmanov", "MS Dnieper Princess", "MS Dnipro", "MS Donau Kristallschiff", "ms Douce France", "MS Douro Cruiser", "MS Douro Elegance", "MS Douro Prince", "MS Douro Princess", "MS Douro Queen", "MS Douro Spirit", "MS Douro Splendour", "MS Dream Charming", "MS Dutch Grace", "MS Dutch Largo", "MS Dutch Melody", "MS Dutch Opera", "MS Edelweiss", "ms Elbe Princesse", "ms Elbe Princesse II", "MS Elegant Lady", "MS Emily Bronte", "MS Esplanade", "MS Esprit", "ms Eurodam", "ms Europa", "ms Europa 2", "MS Excellence Baroness", "MS Excellence Coral", "MS Excellence Countess", "MS Excellence Empress", "MS Excellence Pearl", "MS Excellence Princess", "MS Excellence Queen", "MS Excellence Rhone", "MS Excellence Royal", "MS Expedition", "MS Farah", "ms Fernao de Magalhaes", "MS Filia Rheni II", "MS Florentina", "MS Fram", "ms France", "MS Frederic Chopin", "MS Fridtjof Nansen", "MS Galileo", "MS General Lavrinenkov", "MS Geoffrey Chaucer", "MS George Eliot", "MS Georgy Chicherin", "ms Gerard Schmitter", "ms Gil Eanes", "MS Gisela", "MS Grace", "MS Hamburg", "MS Heidelberg", "MS Igor Stravinsky", "ms Infante Don Henrique", "MS Ivan Bunin", "MS Ivan Kulibin", "MS Jacques Cartier", "MS Jane Austen", "MS Jaz Royale", "MS Johanna", "MS Johannes Brahms", "MS Joy", "MS Jubilee", "MS Junker Jorg", "MS Kapitan Pushkarev", "MS Kasr Ibrim", "MS Katharina von Bora", "MS Knyazhna Viktoria", "MS Kong Harald", "ms Koningsdam", "MS Konstantin Fedin", "MS Konstantin Korotkov", "MS Konstantin Simonov", "MS Kristallkonigin", "MS Kristallprinzessin", "MS Kronstadt", "ms L'Europe", "ms La Belle de Cadix", "ms La Belle de l'Adriatique", "ms La Belle des Oceans", "ms La Boheme", "MS Lady Cristina", "MS Lady Diletta", "ms Lafayette", "MS Lenin", "ms Leonard de Vinci", "MS Leonid Sobolev", "MS Leonora", "MS Lev Tolstoy", "MS Linzerin", "MS Lofoten", "ms Loire Princesse", "MS Lord Byron", "MS Lord Tennyson", "MS Lunnaya Sonata", "MS Maxim Gorky", "MS Maxima", "MS Mayfair", "MS Mayflower", "ms Michelangelo", "MS Midnatsol", "MS Miguel Torga", "MS Mikhail Sholokhov", "ms Mistral", "ms Modigliani", "MS Moldavia", "ms Mona Lisa", "MS Monarch Countess", "ms Monet", "MS Mstislav Rostropovich", "MS Mustai Karim", "MS My Story", "MS Nestroy", "MS nickoSPIRIT", "MS nickoVISION", "ms Nieuw Amsterdam", "ms Nieuw Statendam", "MS Nikolay Chernyshevsky", "MS Nikolay Nekrasov", "MS Nile Dolphin", "MS Nizhny Novgorod", "ms Noordam", "MS Nordkapp", "MS Nordlys", "MS Nordnorge", "MS Nordstjernen", "MS Oberoi Zahra", "ms Oosterdam", "MS Oscar Wilde", "MS Otto Sverdrup", "MS Panorama 1 yacht", "MS Panorama 2 yacht", "MS Passau", "MS Peter Tchaikovsky", "MS Polarlys", "MS Porto Mirante", "MS Primadonna", "ms Princesse d'Aquitaine", "MS Princesse de Provence", "MS Prinzessin Isabella", "MS Prinzessin Katharina", "MS Prinzessin Sisi", "MS Pyotr Velikiy", "MS Regina Danubia", "ms Renoir", "MS Rex Rheni", "MS Rhein Melodie", "MS Rhein Prinzessin", "MS Rhein Symphonie", "MS RheinGalaxie Eventschiff", "MS Richard With", "MS Rigoletto", "MS River Adagio", "MS River Allegro", "MS River Aria", "MS River Art", "MS River Chanson", "MS River Discovery II", "MS River Harmony", "MS River Navigator", "MS River Rhapsody", "MS River Splendor", "MS River Venture", "MS River Voyager", "MS Roald Amundsen", "MS Rodnaya Rus", "MS Rossia", "MS Rossini", "ms Rotterdam", "MS Rousse Prestige", "MS Royal Crown", "MS Russ", "MS Sankt Peterburg", "MS Sans Souci", "MS Savor", "MS Saxonia", "MS Seaventure", "MS Seine Comtesse", "ms Seine Princess", "MS Serenade 1", "MS Serenade 2", "MS Serenissima", "MS Serenity", "MS Sergei Rachmaninov", "MS Sissi", "MS Sofia", "MS Sonesta Moon Goddess", "MS Sonesta Nile Goddess", "MS Sonesta St George", "MS Sonesta Star Goddess", "MS Sonesta Sun Goddess", "MS Spitsbergen", "MS Stadt Linz", "MS Stavangerfjord ferry", "MS Steigenberger Omar El Khayam", "MS SUNliner Cabrioschiff", "MS Swiss Crown", "MS Swiss Crystal", "MS Swiss Diamond", "MS Swiss Emerald", "MS Swiss Jewel", "MS Swiss Pearl", "MS Swiss Ruby", "MS Swiss Sapphire", "MS Switzerland", "MS Switzerland II", "ms Symphonie", "ms The World", "MS Thomas Hardy", "MS Thurgau Gold", "MS Thurgau Silence", "MS Thurgau Ultra", "MS Tikhi Don", "MS Titanic 2", "MS Trollfjord", "MS Ukraina", "MS Utopia Residences", "ms Van Gogh", "ms Vasco de Gama", "MS Vasily Surikov", "MS Verdi", "MS Vesteralen", "ms Victor Hugo", "MS Viking Princess", "MS Viktoria", "MS Viola", "MS Vissarion Belinsky", "MS VistaBelle", "MS VistaExplorer", "MS VistaFidelio", "MS VistaFlamenco", "MS VistaNeo", "MS VistaStar", "MS VIVA Enjoy", "MS VIVA Gloria", "MS VIVA Inspire", "MS VIVA Moments", "MS VIVA One", "MS VIVA Tiara", "MS VIVA Treasures", "MS VIVA Two", "MS VIVA Voyage", "ms Vivaldi", "MS Vivienne", "ms Volendam", "MS Volga", "MS Volga Dream", "ms Westerdam", "MS William Shakespeare", "MS William Wordsworth", "MS Yuri Andropov", "ms Zaandam", "MS Zosima Shashkov", "ms Zuiderdam", "MSC Armonia", "MSC Bellissima", "MSC Divina", "MSC Euribia", "MSC Explora 1", "MSC Explora 2", "MSC Explora 3", "MSC Explora 4", "MSC Explora 5", "MSC Explora 6", "MSC Fantasia", "MSC Grandiosa", "MSC Lirica", "MSC Magnifica", "MSC Melody", "MSC Meraviglia", "MSC Musica", "MSC Opera", "MSC Orchestra", "MSC Poesia", "MSC Preziosa", "MSC Seascape", "MSC Seashore", "MSC Seaside", "MSC Seaview", "MSC Sinfonia", "MSC Splendida", "MSC Virtuosa", "MSC World America", "MSC World Asia", "MSC World Europa", "MSV Botnica icebreaker", "MSV Fennica icebreaker", "MSV Nordica icebreaker", "Mudyug icebreaker", "Murmansk icebreaker", "mv Aegean Odyssey", "MV Arethusa", "MV Artemis", "MV Clio", "MV Coral Expeditions I", "MV Coral Expeditions II", "MV Corinthian", "mv Discovery", "MV Esmeralda", "MV Evolution", "MV Gemini", "MV Glen Etive", "MV Glen Massan", "MV Glen Tarsan", "MV Hans Hansson", "MV Hondius", "MV Isabela II Galapagos", "MV Janssonius", "MV Liseron", "MV Louisiane", "MV Magellan Discoverer", "MV Magellan Explorer", "MV Mahabaahu", "mv Minerva", "MV Mist Cove", "MV Misty Fjord", "MV Ortelius", "MV Plancius", "MV Polar Pioneer", "MV Prinses Christina", "MV Reef Endeavour", "MV Santa Cruz II Galapagos", "MV Sea Spirit", "MV Stella Australis", "MV True North", "MV Ushuaia", "MV Ventus Australis", "MV Virginia", "MY Callisto", "MY Harmony G", "MY Harmony V", "MY Pegasus", "Mykonos Palace ferry", "Napoles ferry", "National Geographic Delfina", "National Geographic Endeavour", "National Geographic Endeavour 2", "National Geographic Endurance", "National Geographic Explorer", "National Geographic Gemini", "National Geographic Islander ", "National Geographic Islander 2", "National Geographic Orion", "National Geographic Quest", "National Geographic Resolution", "National Geographic Sea Bird", "National Geographic Sea Lion", "National Geographic Venture", "Navigator Of The Seas", "Nils Dacke ferry", "Nippon Maru", "Noosfera icebreaker", "Normandie ferry", "Norrona ferry", "Northern Adventure ferry", "Northern Expedition ferry", "Norwegian Aqua", "Norwegian Bliss", "Norwegian Breakaway", "Norwegian Dawn", "Norwegian Encore", "Norwegian Epic", "Norwegian Escape", "Norwegian Gem", "Norwegian Getaway", "Norwegian Jade", "Norwegian Jewel", "Norwegian Joy", "Norwegian Luna", "Norwegian Pearl", "Norwegian Prima", "Norwegian Sky", "Norwegian Spirit", "Norwegian Star", "Norwegian Sun", "Norwegian Viva", "Nova Star ferry", "Novorossiysk icebreaker", "NS Arktika icebreaker", "NS Chukotka icebreaker", "NS Leningrad icebreaker", "NS Rossiya icebreaker", "NS Sibir icebreaker", "NS Stalingrad icebreaker", "NS Ural icebreaker", "NS Yakutia icebreaker", "Nymphea barge", "NYV Caroline", "Oasis Of The Seas", "Ocean Adventurer", "Ocean Albatros", "Ocean Atlantic", "Ocean Diamond", "Ocean Endeavour", "Ocean Explorer", "Ocean Gala", "Ocean Majesty", "Ocean Nova", "Ocean Odyssey", "Ocean Residences MY Njord", "Ocean Victory", "Oceania Allura", "Oceania Insignia", "Oceania Marina", "Oceania Nautica", "Oceania Regatta", "Oceania Riviera", "Oceania Sirena", "Oceania Vista", "Oden icebreaker", "Odyssey Of The Seas", "Olympic Champion ferry", "Optima Seaways ferry", "Orient Express Corinthian", "Orient Express Olympian", "Orient Queen", "Oscar Wilde ferry", "Otso icebreaker", "Ovation Of The Seas", "Pacific Jewel", "Pacific World", "Panache barge", "Pascal Lota ferry", "Pascal Paoli ferry", "Patria Seaways ferry", "Paul Gauguin", "Pearl Mist", "Pearl Seaways ferry", "Piano Land", "PO Liberte ferry", "PO Pioneer ferry", "Polaris icebreaker", "Pont Aven ferry", "Porto", "Pride of America", "Pride of Burgundy ferry", "Pride of Canterbury ferry", "Pride of Hull ferry", "Pride of Kent ferry", "Pride of Rotterdam ferry", "Princess Anastasia ferry", "Princess Eleganza", "Princess Seaways ferry", "Professor Khromov", "Professor Molchanov", "Professor Multanovskiy", "PS Murray Princess", "PS Waverley", "Pullmantur Horizon", "Pullmantur Monarch", "Pullmantur Sovereign", "Pullmantur Zenith", "Quantum Of The Seas", "Quark Ultramarine", "Queen Anne", "Queen Elizabeth", "Queen Isabel", "Queen Mary 2", "Queen of Galapagos", "Queen of the Oceans", "Queen Victoria", "Radiance Of The Seas", "Raymonde barge", "Regal Princess", "Regina Baltica ferry", "Regina Seaways ferry", "Resilient Lady", "Resorts World One", "Rhapsody Of The Seas", "Ritz-Carlton Evrima", "Ritz-Carlton Ilma", "Ritz-Carlton Luminara", "River Duchess", "River Empress", "River Orchid", "River Princess", "River Queen", "Riverside Debussy", "Riverside Mozart", "Riverside Ravel", "RMS St Helena", "Robin Hood ferry", "Ros Crana barge", "Rosa barge", "Royal Clipper", "Royal Eleganza", "Royal Princess", "RRS Discovery", "RRS James Cook", "RRS Sir David Attenborough icebreaker", "RSV Nuyina icebreaker", "Ruby Princess", "Rusadir ferry", "RV Anawrahta", "RV Angkor Pandaw", "RV Bassac Pandaw", "RV Bengal Ganga", "RV Champa Pandaw", "RV Charaidew", "RV Cruiseco Adventurer", "RV Cruiseco Explorer", "RV Indochina Pandaw", "RV Indochine", "RV Indochine II", "RV Irrawaddy Explorer", "RV Jahan", "RV Kalaw Pandaw", "RV Kalay Pandaw", "RV Kanee Pandaw", "RV Katha Pandaw", "RV Kha Byoo Pandaw", "RV Kindat Pandaw", "RV La Marguerite", "RV Lan Diep", "RV Laos Pandaw", "RV Laura Bassi icebreaker", "RV Mekong Jewel", "RV Mekong Navigator", "RV Mekong Pandaw", "RV Mekong Prestige II", "RV Mekong Princess", "RV Orient Pandaw", "RV Pandaw II", "RV Princess Panhwar", "RV Rajmahal", "RV Sabaidee Pandaw", "RV Samatha", "RV Song Hong Pandaw", "RV Strand", "RV Thurgau Exotic 1", "RV Thurgau Exotic 2", "RV Thurgau Exotic 3", "RV Tonle Pandaw", "RV Toum Tiou II", "RV Varuna", "RV Yunnan Pandaw", "RV Zawgyi Pandaw", "Safari Endeavour", "Safari Explorer", "Safari Quest", "Safari Voyager", "Saga Pearl II", "Saga Ruby", "Saint-Malo ferry", "Salamanca ferry", "Salamis Filoxenia", "Sanctuary Ananda", "Sanctuary Nile Adventurer", "Sanctuary Sun Boat III", "Sanctuary Sun Boat IV", "Sanctuary Yangzi Explorer", "Sankt Peterburg icebreaker", "Santona ferry", "Sapphire Princess", "Savoir Faire barge", "Scarlet Lady", "Scenic Amber", "Scenic Aura", "Scenic Azure", "Scenic Crystal", "Scenic Diamond", "Scenic Eclipse", "Scenic Eclipse 2", "Scenic Emerald", "Scenic Gem", "Scenic Jade", "Scenic Jasper", "Scenic Jewel", "Scenic Opal", "Scenic Pearl", "Scenic Ruby", "Scenic Sapphire", "Scenic Spirit", "Scenic Tsar", "SCF Sakhalin icebreaker", "Scottish Highlander barge", "Sea Cloud", "Sea Cloud 2", "Sea Cloud Spirit", "Sea Endurance", "Seabourn Encore", "Seabourn Ovation", "Seabourn Pursuit", "Seabourn Quest", "Seabourn Sojourn", "Seabourn Venture", "SeaDream I", "SeaDream II", "SeaDream Innovation", "Serenade Of The Seas", "Seven Seas Explorer", "Seven Seas Grandeur", "Seven Seas Mariner", "Seven Seas Navigator", "Seven Seas Prestige", "Seven Seas Splendor", "Seven Seas Voyager", "Seven Sisters ferry", "Sevmorput icebreaker", "SH Diana", "SH Minerva", "SH Vega", "Shannon Princess barge", "Sicilia ferry", "Silja Europa ferry", "Silja Galaxy ferry", "Silja Serenade ferry", "Silja Symphony ferry", "Silver Cloud", "Silver Dawn", "Silver Endeavour", "Silver Galapagos", "Silver Moon", "Silver Muse", "Silver Nova", "Silver Origin", "Silver Ray", "Silver Shadow", "Silver Spirit", "Silver Whisper", "Silver Wind", "Sky Princess", "Sorolla ferry", "Sovetskiy Soyuz icebreaker", "Spectrum Of The Seas", "Spirit of Adventure", "Spirit of Britain ferry", "Spirit of British Columbia ferry", "Spirit of Chartwell barge", "Spirit of Discovery", "Spirit of France ferry", "Spirit of Scotland barge", "Spirit of Tasmania 1 ferry", "Spirit of Tasmania 2 ferry", "Spirit of Tasmania 4 ferry", "Spirit of Tasmania 5 ferry", "Spirit of the Danube", "Spirit of the Douro", "Spirit of the Moselle", "Spirit of the Rhine", "Spirit of Vancouver Island ferry", "SS Antoinette", "SS Beatrice", "SS Bon Voyage", "SS Catherine", "SS Elisabeth", "SS Joie de Vivre", "SS La Venezia", "SS Maria Theresa", "SS Sao Gabriel", "SS Victoria", "SS Wilderness Legacy", "Star Breeze", "Star Clipper", "Star Flyer", "Star Legend", "Star Of The Seas", "Star Pisces", "Star Pride", "Star Princess", "Star Seeker", "Star Voyager", "Stena Adventurer ferry", "Stena Baltica ferry", "Stena Britannica ferry", "Stena Ebba ferry", "Stena Edda ferry", "Stena Elektra ferry", "Stena Embla ferry", "Stena Estelle ferry", "Stena Estrid ferry", "Stena Europe ferry", "Stena Flavia ferry", "Stena Germanica ferry", "Stena Hollandica ferry", "Stena Horizon ferry", "Stena Jutlandica ferry", "Stena Livia ferry", "Stena Nautica ferry", "Stena Nordica ferry", "Stena Saga ferry", "Stena Scandica ferry", "Stena Scandinavica ferry", "Stena Skane ferry", "Stena Spirit ferry", "Stena Superfast VII ferry", "Stena Superfast VIII ferry", "Stena Superfast X ferry", "Stena Vision ferry", "Stepan Makarov icebreaker", "Storylines MV Narrative", "Sun Princess", "Sunflower Furano ferry", "Sunflower Kirishima ferry", "Sunflower Kurenai ferry", "Sunflower Murasaki ferry", "Sunflower Sapporo ferry", "Sunflower Satsuma ferry", "Superfast I ferry", "Superfast II ferry", "Superfast XI ferry", "Superspeed 1 ferry", "Superspeed 2 ferry", "SuperStar Aquarius", "SuperStar Gemini", "SuperStar Libra", "SV Noorderlicht", "SV Rembrandt van Rijn", "Sylvia Earle", "Symphony Of The Seas", "Tallink Megastar ferry", "Tallink MySTAR ferry", "Tallink Romantika ferry", "Tallink Victoria I ferry", "Taymyr icebreaker", "Tenacia ferry", "THE A", "THE B", "Thomson Spirit", "Tinker Bell ferry", "Tirrenia Athara ferry", "Tirrenia Bithia ferry", "Tirrenia Janas ferry", "Tirrenia Nuraghes ferry", "Tirrenia Raffaele Rubattino ferry", "Tirrenia Sharden ferry", "Tirrenia Vincenzo Florio ferry", "Tom Sawyer ferry", "Travelmarvel Capella", "Travelmarvel Diamond", "Travelmarvel Jewel", "Travelmarvel Polaris", "Travelmarvel Sapphire", "Travelmarvel Vega", "Treasure of Galapagos", "TUI Al Horeya", "TUI Alma", "TUI Bahareya", "TUI Isla", "TUI Maya", "TUI Skyla", "Ulysses ferry", "Uniworld River Tosca", "Uniworld SS Sphinx", "USCGC Healy icebreaker", "USCGC Polar Sentinel icebreaker", "Utopia Of The Seas", "Valiant Lady", "Variety Voyager", "Vasco da Gama-Nicko", "Vaygach icebreaker", "Ventura", "Victoria Sabrina", "Victoria Seaways ferry", "Victory 1", "Victory 2", "Vidanta Elegant", "Viking Aegir", "Viking Akun", "Viking Alruna", "Viking Alsvin", "Viking Amun", "Viking Annar", "Viking Astrea", "Viking Astrild", "Viking Atla", "Viking Aton", "Viking Baldur", "Viking Bestla", "Viking Beyla", "Viking Bragi", "Viking Buri", "Viking Cinderella ferry", "Viking Dagur", "Viking Delling", "Viking Egdir", "Viking Egil", "Viking Einar", "Viking Eir", "Viking Eistla", "Viking Eldir", "Viking Embla", "Viking Emerald", "Viking Fjorgyn", "Viking Forseti", "Viking Freya", "Viking Gabriella ferry", "Viking Gefjon", "Viking Gersemi", "Viking Glory ferry", "Viking Grace ferry", "Viking Gullveig", "Viking Gyda", "Viking Gymir", "Viking Hathor", "Viking Heimdal", "Viking Helgi", "Viking Helgrim", "Viking Hemming", "Viking Herja", "Viking Hermod", "Viking Hervor", "Viking Hild", "Viking Hlin", "Viking Honir", "Viking Idi", "Viking Idun", "Viking Ingvar", "Viking Ingvi", "Viking Jarl", "Viking Jupiter", "Viking Kadlin", "Viking Kara", "Viking Kari", "Viking Kvasir", "Viking Legend", "Viking Libra", "Viking Lif", "Viking Lofn", "Viking Magni", "Viking Mani", "Viking Mars", "Viking Mekong", "Viking Mimir", "Viking Mira", "Viking Mississippi", "Viking Modi", "Viking MS Antares", "Viking Neptune", "Viking Nerthus", "Viking Njord", "Viking Octantis", "Viking Odin", "Viking Orion", "Viking Osfrid", "Viking Osiris", "Viking Polaris", "Viking Prestige", "Viking Ptah", "Viking Ra", "Viking Radgrid", "Viking Rinda", "Viking Rolf", "Viking Rurik", "Viking Saigon", "Viking Saturn", "Viking Sea", "Viking Sekhmet", "Viking Sigrun", "Viking Sigyn", "Viking Sineus", "Viking Skadi", "Viking Skaga", "Viking Skirnir", "Viking Sky", "Viking Sobek", "Viking Star", "Viking Thoth", "Viking Tialfi", "Viking Tir", "Viking Tonle", "Viking Tor", "Viking Torgil", "Viking Truvor", "Viking Ullur", "Viking Vali", "Viking Var", "Viking Ve", "Viking Vela", "Viking Venus", "Viking Vesta", "Viking Vidar", "Viking Vilhjalm", "Viking Vili", "Viking XPRS ferry", "Viktor Chernomyrdin icebreaker", "Villa Vie Odyssey", "Visborg ferry", "Visby ferry", "Vision Of The Seas", "Vitus Bering icebreaker", "Vladivostok icebreaker", "Volcan de Tamadaba ferry", "Volcan de Tamasite ferry", "Volcan de Tijarafe ferry", "Volcan de Timanfaya ferry", "Volcan de Tinamar ferry", "Volcan del Teide ferry", "Voyager Of The Seas", "Wawel ferry", "WB Yeats ferry", "Wilderness Adventurer", "Wilderness Discoverer", "Wilderness Explorer", "Wind Spirit", "Wind Star", "Wind Surf", "Wonder Of The Seas", "World Adventurer", "World Discoverer", "World Explorer", "World Navigator", "World Traveller", "World Voyager", "Xavier III Galapagos", "Xue Long 2 icebreaker", "Yamal icebreaker", "Yevgeny Primakov icebreaker", "Yolita II Galapagos", "Zambezi Queen", "Zeus Palace ferry", "Zhao Shang Yi Dun-Viking Sun", "Zimbabwean Dream", "Zurbaran ferry"]
}

#Preview {
    CruiseInputView(onSave: { })
        .modelContainer(for: Cruise.self, inMemory: true)
}
