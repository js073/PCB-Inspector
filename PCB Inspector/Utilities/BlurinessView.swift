//
//  BlurinessView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 29/02/2024.
//
//  Simple view to provide coloured text depending on the blur rating of a image 

import SwiftUI

struct BlurinessView: View {
    @Binding var blurRating: Int // Value of bluriness
    
    var body: some View {
        Group {
            switch blurRating {
            case 0:
                Text("Low Image Blur")
                    .bold()
                    .foregroundStyle(.green)
            case 1:
                Text("Medium Image Blur")
                    .bold()
                    .foregroundStyle(.orange)
            case 2:
                Text("High Image Blur")
                    .bold()
                    .foregroundStyle(.red)
            default:
                Text("Error")
                    .bold()
            }
        }
        .padding([.top, .bottom], 12)
        .padding([.leading, .trailing], 17)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .foregroundStyle(.backgroundColourVariant)
        }
    }
}

#Preview {
    BlurinessView(blurRating: .constant(2))
}
