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
    @Query private var cruises: [Cruise]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(cruises) { cruise in
                    NavigationLink(value: cruise) {
                        VStack(alignment: .leading) {
                            Text(cruise.line)
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
            .navigationDestination(for: Cruise.self) { cruise in
                CruiseDetailView(cruise: cruise)
            }
            .scrollContentBackground(.hidden)
            .background(Color.blue.opacity(0.07))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addCruise) {
                        Label("Add Cruise", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addCruise() {
        withAnimation {
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
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(cruises[index])
            }
        }
    }
}

#Preview {
    CruiseListView()
        .modelContainer(for: Cruise.self, inMemory: true)
}
