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
    @Query private var cruiseStops: [CruiseStop]
    
    @State private var isPresentingAdd = false // modal sheet
    
    // summary calculations
    var cruiseCount: Int {
        cruises.count
    }
    var shipCount: Int {
        Set(cruises.map { $0.ship }).count
    }
    var uniqueCountries: [String] {
        let countries = cruiseStops.compactMap { $0.country?.trimmingCharacters(in: .whitespacesAndNewlines) }
                                 .filter { !$0.isEmpty }
        return Array(Set(countries)).sorted()
    }
    var uniquePorts: [String] {
        let ports = cruiseStops.compactMap { $0.port.trimmingCharacters(in: .whitespacesAndNewlines) }
                                 .filter { !$0.isEmpty }
        return Array(Set(ports)).sorted()
    }


    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .center) {
                Image(systemName: "ferry")
                    .foregroundColor(.secondary)
                Text("Ships")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(shipCount)")
                    .font(.title2)
                    .bold()
            }
            Spacer()
            VStack(alignment: .center) {
                Image(systemName: "water.waves")
                    .foregroundColor(.secondary)
                Text("Cruises")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(cruiseCount)")
                    .font(.title2)
                    .bold()
            }
            Spacer()
            VStack(alignment: .center) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.secondary)
                Text("Ports")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(uniquePorts.count)")
                    .font(.title2)
                    .bold()
            }
            Spacer()
            VStack(alignment: .center) {
                Image(systemName: "globe.americas")
                    .foregroundColor(.secondary)
                Text("Countries")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(uniqueCountries.count)")
                    .font(.title2)
                    .bold()
            }
            Spacer()
        }
        List {
            Section("Cruises") {
                if cruises.count < 1 {
                    Button(action: addItems) {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                            Text("Import SeaVee")
                                .foregroundColor(.white)
                                .bold()
                        }
                        .frame(maxWidth: .infinity) // Make button full-width
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .buttonStyle(PlainButtonStyle()) // Remove default button styling
                } else {
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
                                    Text("\(cruise.itinerary.count) stops")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle("My SeaVee")
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
    
    private func addItems() {
        isPresentingAdd = true
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
                // Fetch all Cruises
                let cruiseDescriptor = FetchDescriptor<Cruise>()
                let allCruises = try modelContext.fetch(cruiseDescriptor)
                
                // Delete them
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
