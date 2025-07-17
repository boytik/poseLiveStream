//
//  ContentView.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraVM = CameraViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            CameraView(viewModel: cameraVM)
                .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    
                    if let result = cameraVM.latestPoseResult {
                        PoseResultView(result: result)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                    
                    if cameraVM.isProcessing {
                        ProgressView()
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
                .padding()
                
                Spacer()
                VStack(spacing: 12) {
                    if cameraVM.processedImage != nil {
                        ProcessedImagePreview(viewModel: cameraVM)
                    }
                    
                    SettingsButton(showingSettings: $showingSettings)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: cameraVM)
        }
        .onAppear {
            cameraVM.startSession()
        }
        .onDisappear {
            cameraVM.stopSession()
        }
    }
}



struct SettingsButton: View {
    @Binding var showingSettings: Bool
    
    var body: some View {
        Button(action: {
            showingSettings.toggle()
        }) {
            Image(systemName: "gear")
                .font(.title)
                .padding()
                .background(Circle().fill(Color.black.opacity(0.5)))
                .foregroundColor(.white)
        }
    }
}

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
