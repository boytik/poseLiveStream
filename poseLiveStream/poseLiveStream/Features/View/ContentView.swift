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

