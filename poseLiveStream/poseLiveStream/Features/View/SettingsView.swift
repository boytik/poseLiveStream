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
                Section(header: Text("CAPTURE SETTINGS").font(.footnote)) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Stepper(
                            "Interval: \(viewModel.config.captureInterval, specifier: "%.1f") sec",
                            value: $viewModel.config.captureInterval,
                            in: 0.5...10,
                            step: 0.5
                        )
                    }
                    
                    HStack {
                        Image(systemName: "video")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Stepper(
                            "FPS: \(viewModel.config.processingFPS)",
                            value: $viewModel.config.processingFPS,
                            in: 1...30
                        )
                    }
                }
                
                Section(header: Text("PRIVACY").font(.footnote)) {
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Slider(
                            value: $viewModel.config.blurRadius,
                            in: 0...100,
                            step: 5
                        ) {
                            Text("Blur")
                        } minimumValueLabel: {
                            Text("0%")
                                .font(.caption2)
                        } maximumValueLabel: {
                            Text("100%")
                                .font(.caption2)
                        }
                        Text("\(Int(viewModel.config.blurRadius))%")
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Image(systemName: "face.smiling")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Toggle("Preserve Faces", isOn: $viewModel.config.preserveFaceWithoutBlur)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}
