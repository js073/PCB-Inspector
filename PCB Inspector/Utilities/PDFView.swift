//
//  PDFView.swift
//  PCB Inspector
//
//  Created by Jack Smith on 06/03/2024.
//

import SwiftUI
import PDFKit

struct PDFUIView: UIViewRepresentable {
    let url : URL
    
    func makeUIView(context: Context) -> some UIView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // perform update
    }
}

#Preview {
    PDFUIView(url: URL(fileURLWithPath: "https://datasheet.octopart.com/PIC18F44J10-I/PT-Microchip-datasheet-8383908.pdf"))
}
