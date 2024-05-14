//
//  SavingPopover.swift
//  PCB Inspector
//
//  Created by Jack Smith on 04/01/2024.
//
//  View used to show the saving popover for the multi-element view

import SwiftUI

struct SavingPopover: View {
    @Binding var controller: MultiElementController // controller
    @Binding var closeWindowAction: () -> () // action used to close window
    @State fileprivate var savedName: String = "" // The name given by the user for the saved component
    @State fileprivate var savedPCBNames: [String]? // Stores the saved names of all PCBs
    @State fileprivate var saveNameStatus: Bool = true // Used to display if the current saved name is unique or not
    @State fileprivate var savingState: SavingProgress = .none // Current state of saving
    let disappearTime: Double = 3 // Time to close window after
    
    var body: some View {
        VStack {
            switch savingState {
            case .saving:
                Text("Saving model")
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.accent)
            case .saved:
                Text("Saved successfully")
                    .bold()
                    .onAppear { // Hide after 3 seconds
                        let delay = RunLoop.SchedulerTimeType(.init(timeInterval: disappearTime, since: .now))
                        RunLoop.main.schedule(after: delay) {
                            withAnimation {
                                closeWindowAction()
                            }
                        }
                    }
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.green)
                    .frame(width: 30)
                    .padding(.bottom, 10)
                ProgressView(timerInterval: Date()...Date().addingTimeInterval(disappearTime))
                    .labelsHidden()
            case .error:
                Text("Error occured")
                    .bold()
                    .onAppear { // Hide after 3 seconds
                        let delay = RunLoop.SchedulerTimeType(.init(timeInterval: disappearTime, since: .now))
                        RunLoop.main.schedule(after: delay) {
                            closeWindowAction()
                        }
                    }
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.red)
                    .frame(width: 30)
                    .padding(.bottom, 10)
                ProgressView(timerInterval: Date()...Date().addingTimeInterval(disappearTime))
                    .labelsHidden()
                    .tint(.red)
            case .none:
                Text("Enter name")
                    .bold()
                TextField("Name", text: $savedName)
                    .onChange(of: savedName) {
                        if let savedPCBNames {
                            saveNameStatus = savedPCBNames.contains(savedName) || savedName == ""
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Name must be unique and non-empty")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.red)
                }
                .opacity(saveNameStatus ? 1.0 : 0)
                .frame(maxWidth: .infinity)
                HStack {
                    Button {
                        withAnimation {
                            closeWindowAction()
                        }
                        savedName = ""
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SmallMonoButtonStyle())
                    Button {
                        Task {
                            savingState = .saving
                            if controller.saveCurrent(savedName) {
                                savingState = .saved
                            } else {
                                savingState = .error
                            }
                        }
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SmallAccentButtonStyle())
                    .disabled(saveNameStatus)
                    .opacity(saveNameStatus ? 0.5 : 1)
                }
                .padding([.leading, .trailing], 10)
            }
        }
//        .fixedSize()
        .task {
//            savedPCBNames = []
            savedPCBNames = controller.dataController.getSavedNames()
        }
    }
}

fileprivate enum SavingProgress { // ENUM used to display the saving progress
    case saving // saving in progress
    case saved // saving complete
    case error // error during saving
    case none // no progress
}

#Preview {
    SavingPopover(controller: .constant(MultiElementController()), closeWindowAction:  .constant {
        print("hello there")
    })
}
