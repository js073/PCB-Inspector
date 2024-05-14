//
//  OpenExistingView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 04/01/2024.
//
//  View for selecting a saved PCB

import SwiftUI

struct OpenExistingView: View {
    @State fileprivate var dataHandler = DataHandler.handlerShared
    @State fileprivate var savedPCBs: [IdentifiedPCBStorage]?
    
    var body: some View {
        VStack {
            if let saved = savedPCBs {
                if saved.isEmpty { // No saved PCBs
                    Text("No saved PCBs")
                        .font(.title)
                        .bold()
                } else { // Saved PCBs avaliable
                    List {
                        ForEach(saved) { pcb in
                            ListItem(currentPCB: .constant(pcb))
                        }
                        .onDelete(perform: { indexSet in
                            let deleteNames = indexSet.map { saved[$0].boardName }
                            for name in deleteNames {
                                let _ = dataHandler.deletePCB(name)
                            }
                            savedPCBs = dataHandler.getAllSavedPCBs()
                        })
                    }
                    .toolbar {
                        EditButton()
                    }
                }
            } else { // Error occured retrieving PCBs
                Text("Error occured")
                    .font(.title)
                    .bold()
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("Saved PCBs")
        .task {
            savedPCBs = dataHandler.getAllSavedPCBs()
//            savedPCBs = [IdentifiedPCBStorage(boardName: "tmp", boardImage: Data.init(), identifiedComponents: [], identifiedICs: [])]
        }
    }
}

fileprivate struct ListItem: View { // Item in the list of avaliable saved PCBs 
    @Binding var currentPCB: IdentifiedPCBStorage
    
    var body: some View {
        NavigationLink(destination: MultiElementView(isOpeningExisiting: true, existingPCB: currentPCB)) {
            VStack {
                Text(currentPCB.boardName)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
//                Divider()
                Text("Identified Components: \(currentPCB.identifiedComponents.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Identified ICs: \(currentPCB.identifiedICs.count)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Created: \(currentPCB.creationDate.formatted())")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        OpenExistingView()
    }
}
