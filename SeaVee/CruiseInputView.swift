//
//  CruiseInputView.swift
//  SeaVee
//
//  Created by Jessi Draper on 03.12.25.
//

import SwiftUI

struct CruiseInputView: View {
    @Environment(\.modelContext) private var modelContext

    // user input states
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var selectedShip: String = ""
    
    let ships: [String] = ["ship1","ship2", "ship3"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Cruise Details")
                    .font(.title3)
                    .bold()
                
                Picker("Find your ship", selection: $selectedShip) {
                    ForEach(ships, id: \.self) { ship in
                        Text(ship)
                    }
                }

                Text("Enter your contract dates")
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)

            }
//            .pickerStyle(.menu)
        }
        .padding()
    }
}

#Preview {
    CruiseInputView()
        .modelContainer(for: Cruise.self, inMemory: true)
}
