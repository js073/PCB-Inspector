//
//  Error Screen.swift
//  PCB Inspector
//
//  Created by Jack Smith on 14/12/2023.
//
//  Error screen to be displayed when an error occurs

import SwiftUI

struct ErrorScreen: View {
    @State fileprivate var path = NavigationPath()
    
    var body: some View {
        VStack {
            Text("This is not the page you're looking for...")
                .font(.title)
                .bold()
                .padding(.bottom, 30)
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .foregroundStyle(.red)
                .frame(width: 100, height: 100)
                .scaledToFit()
                .padding(.bottom, 20)
            Text("Oops! An error occured, please go back!")
                .bold()
                .padding(.bottom, 20)
            Text("Or, retrun to the home page")
                .bold()
        }.navigationTitle("Error")
    }
}

#Preview {
    ErrorScreen()
}
