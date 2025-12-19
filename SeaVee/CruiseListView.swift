//
//  CruiseListView.swift
//  SeaVee
//
//  Created by Jessi Draper on 02.12.25.
//

import SwiftUI
import SwiftData

struct CruiseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cruise.startDate, order: .forward) private var cruises: [Cruise]
    
    @State private var isPresentingAdd = false // modal sheet
    
    var cruiseCount: Int {
        cruises.count
    }
    
    var shipCount: Int {
        Set(cruises.map { $0.ship }).count
    }
    
    var uniqueCountries: [String] {
        let allStops = cruises.flatMap { $0.itinerary }
        let countries = allStops.compactMap { $0.country?.trimmingCharacters(in: .whitespacesAndNewlines) }
                                 .filter { !$0.isEmpty }
        return Array(Set(countries)).sorted()
    }

    var portCount: Int {
        cruises.reduce(0) { $0 + $1.itinerary.count }
    }


    var body: some View {
        List {
            HStack {
                Spacer()
                VStack(alignment: .center) {
                    Text("Ships")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(shipCount)")
                        .font(.title2)
                        .bold()
                }
                Spacer()
                VStack(alignment: .center) {
                    Text("Cruises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(cruiseCount)")
                        .font(.title2)
                        .bold()
                }
                Spacer()
                VStack(alignment: .center) {
                    Text("Countries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(uniqueCountries.count)")
                        .font(.title2)
                        .bold()
                }
                Spacer()
            }
            .listRowSeparator(.hidden)
            
            ForEach(cruises, id: \.id) { cruise in
                NavigationLink(destination: CruiseDetailView(cruise: cruise)) {
                    VStack(alignment: .leading) {
                        Text(cruise.ship)
                            .textCase(.uppercase)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .kerning(0.5)
                        Text(cruise.title)
                            .bold()
                            .padding(.bottom, 3)
                        HStack {
                            Text("\(cruise.startDate.formatted(date: .abbreviated, time: .omitted)) – \(cruise.endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                            Spacer()
                            Text("\(cruise.itinerary.count) ports")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("My Cruises")
        .scrollContentBackground(.hidden)
        .background(Color.blue.opacity(0.07))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isPresentingAdd = true
                } label: {
                    Label("Add Cruise", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    clearAllCruises()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .fullScreenCover(isPresented: $isPresentingAdd) {
            NavigationStack {
                CruiseInputView {
                    isPresentingAdd = false // dismiss sheet when done
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(cruises[index])
            }
        }
    }
    
    private func clearAllCruises() {
        withAnimation {
            do {
                // 1. Fetch all CruiseStops
                let stopDescriptor = FetchDescriptor<CruiseStop>()
                let allStops = try modelContext.fetch(stopDescriptor)

                // 2. Delete them
                for stop in allStops {
                    modelContext.delete(stop)
                }

                // 3. Fetch all Cruises
                let cruiseDescriptor = FetchDescriptor<Cruise>()
                let allCruises = try modelContext.fetch(cruiseDescriptor)

                // 4. Delete them
                for cruise in allCruises {
                    modelContext.delete(cruise)
                }

                try modelContext.save()
            } catch {
                print("Failed clearing all cruises: \(error)")
            }
        }
    }
}

#Preview {
    CruiseListView()
        .modelContainer(for: Cruise.self, inMemory: true)
}
