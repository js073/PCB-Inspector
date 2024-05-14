//
//  Item.swift
//  PCB Inspector
//
//  Created by Jack Smith on 21/11/2023.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
