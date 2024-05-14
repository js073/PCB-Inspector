//
//  NoteSection.swift
//  PCB Inspector
//
//  Created by Jack Smith on 29/01/2024.
//

import SwiftUI

struct NoteSection: View { // Note section at the bottom of the info page popover
    @Binding var component: ICInfo? // Current component
    var addNoteAction: (UUID?, String?) -> () // Function to perform when adding the new note
    var deleteNoteAction: (UUID?) -> () // Function to perform when removing the note
    @State var isEditing: Bool = false // Used to show if the user is currently editing the note
    @FocusState var focused: Bool
    @State var currentText: String = "" // Current note string
    
    var body: some View {
        Group {
            if component != nil {
                if component!.note != nil || isEditing {
                    VStack {
                        HStack {
                            Text("Note")
                                .bold()
                                .font(.title2)
                            Spacer()
                            if isEditing {
                                Button {
                                    saveNote()
                                    focused = false
                                } label: {
                                    Image(systemName: "checkmark")
                                        .font(.title2)
                                        .imageScale(.small)
                                }
                                .buttonStyle(SmallAccentButtonStyle())
                            } else {
                                Button {
                                    isEditing = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        focused = true
                                    }
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.title2)
                                }
                                .buttonStyle(SmallAccentButtonStyle())
                                Button {
                                    deleteNoteAction(component!.baseInfo.id)
                                    currentText = ""
                                    component!.note = nil
                                    
                                } label: {
                                    Image(systemName: "xmark.bin.fill")
                                        .font(.title2)
                                        .imageScale(.small)
                                }
                                .buttonStyle(SmallAccentButtonStyle(colour: .red))
                            }
                        }
                        Divider()
                        TextField("Note", text: $currentText)
                            .onSubmit {
                                saveNote()
                            }
                            .focused($focused, equals: true)
                            .disabled(!isEditing)
                    }
                    .padding(.all, 20)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .foregroundStyle(.backgroundColour)
                    }
                    .padding(.all, 20)
                } else {
                    VStack {
                        Button {
                            isEditing = true
                            focused = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Note")
                            }
                        }
                        .buttonStyle(SmallAccentButtonStyle())
                    }
                }
            }
        }
        .task {
            currentText = component?.note ?? ""
        }
    }
    
    private func saveNote() {
        component!.note = currentText
        addNoteAction(component!.baseInfo.id, currentText)
        isEditing = false
    }
}

