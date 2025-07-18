//
//  SettingsView.swift
//  poseLiveStream
//
//  Created by Евгений on 18.07.2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Capture Settings")) {
                    Stepper(
                        "Interval: \(viewModel.config.captureInterval, specifier: "%.1f") sec",
                        value: $viewModel.config.captureInterval,
                        in: 0.5...10,
                        step: 0.5
                    )
                    
                    Stepper(
                        "FPS: \(viewModel.config.processingFPS)",
                        value: $viewModel.config.processingFPS,
                        in: 1...30
                    )
                }
                
                Section(header: Text("Privacy")) {
                    Slider(
                        value: $viewModel.config.blurRadius,
                        in: 0...100,
                        step: 5,
                        label: { Text("Blur: \(Int(viewModel.config.blurRadius))") }
                    )
                    
                    Toggle("Preserve Faces", isOn: $viewModel.config.preserveFace)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
