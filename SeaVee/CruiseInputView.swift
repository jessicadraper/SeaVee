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
    @State private var selectedShip: String = ""
    @State private var isLoading: Bool = false
    @State private var isLoaded: Bool = false
    
    let ships: [String] = ["ship1","ship2", "ship3"]
    
    var onSave: () -> Void // closure to dismiss parent
    
    var body: some View {
        Form {
            // MARK: - Ship Picker
            Section(
                header: Text("Find your ship")
                    .textCase(.none)
                    .font(.title2)
                    .padding(.bottom,6)
                    .foregroundColor(.secondary)) {
                        Picker("Select Ship", selection: $selectedShip) {
                            ForEach(ships, id: \.self) { ship in
                                Text(ship)
                            }
                            .padding(.vertical, 8)
                        }
                        .pickerStyle(.navigationLink)
                        .scrollContentBackground(.hidden)
                    }
            
            
            // MARK: - Dates
            Section(header: Text("Enter your contract dates")
                .textCase(.none)
                .font(.title2)
                .padding(.bottom,6)
                .foregroundColor(.secondary)) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            
            // MARK: - Import Button
            Section {
                Button(action: importCruises) {
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
//            .navigationDestination(isPresented: $isLoaded) {
//                CruiseListView()
//            }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
    
    private func importCruises() {
        isLoading = true;
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
        modelContext.insert(sampleCruise)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try modelContext.save()
                onSave() // dismiss sheet
            } catch {
                print("Failed to save cruise: \(error)")
            }
            isLoading = false
        }
    }
}

#Preview {
    CruiseInputView(onSave: { })
        .modelContainer(for: Cruise.self, inMemory: true)
}
