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
            // Камера на весь экран
            CameraView(viewModel: cameraVM)
                .edgesIgnoringSafeArea(.all)
            VStack {
                VStack {
                    if let result = cameraVM.latestPoseResult {
                        PoseResultView(result: result)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                            )
                            .transition(.opacity)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 8)
                
                Spacer()
                
                VStack(spacing: 20) {
                    if cameraVM.processedImage != nil {
                        ProcessedImagePreview(viewModel: cameraVM)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                removal: .opacity
                            ))
                    }
                    SettingsButton(showingSettings: $showingSettings)
                        .padding(.bottom, 30)
                }
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
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.6)) {
                showingSettings.toggle()
            }
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.5))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
