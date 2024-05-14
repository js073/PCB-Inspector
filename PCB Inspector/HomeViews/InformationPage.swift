//
//  InformationPage.swift
//  PCB Inspector
//
//  Created by Jack Smith on 16/02/2024.
//
//  Page to give information on how to use application

import SwiftUI

struct InformationPage: View {
    var body: some View {
        GeometryReader { infoGeo in
            VStack(alignment: .leading) {
                SectionDescription(titleText: "How to use PCB Inspector", bodyText: "Info for using here")
            }
            .padding(.all, 20)
            .frame(width: infoGeo.size.width, alignment: .leading)
        }
        .navigationTitle("Information")
    }
}

/// View to give a title and description section
struct SectionDescription: View {
    var titleText: String
    var bodyText: String
    
    var body: some View {
        Text(titleText)
            .font(.title2)
            .bold()
            .multilineTextAlignment(.leading)
        Text(bodyText)
            .multilineTextAlignment(.leading)
    }
}

#Preview {
    InformationPage()
}
