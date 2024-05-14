//
//  Tollbar.swift
//  PCB Inspector
//
//  Created by Jack Smith on 05/01/2024.
//
//  Provides a tollbar

import SwiftUI

struct ToolbarCustom: ToolbarContent {
    @Binding var path: NavigationPath
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
//            NavigationLink(destination: HomeView()))
            Button {
                path = NavigationPath()
            } label: {
                Image(systemName: "house.circle")
            }
        }
    }
}

#Preview {
    NavigationStack {
        Text("h")
            .toolbar {
                ToolbarCustom(path: .constant(NavigationPath()))
            }
    }
}
