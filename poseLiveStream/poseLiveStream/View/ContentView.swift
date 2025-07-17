//
//  ContentView.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var showPermissionAlert = false
    @State private var isCameraActive = false
    
    @State private var blurLevel: Double = 30 {
        didSet {
            cameraViewModel.config.blurRadius = CGFloat(blurLevel)
        }
    }
    
    @State private var captureInterval: TimeInterval = 2.0 {
        didSet {
            cameraViewModel.config.captureInterval = captureInterval
        }
    }
    
    var body: some View {
        ZStack {
            // 1. Основной слой - предпросмотр камеры
            CameraPreviewView(viewModel: cameraViewModel)
                .edgesIgnoringSafeArea(.all)
            
            // 2. Интерфейс поверх камеры
            VStack {
                resultsView
                
                // Добавлено отображение обработанного изображения
                if let processedImage = cameraViewModel.processedImage {
                    Image(uiImage: processedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .padding()
                }
                
                Spacer()
                controlPanel
            }
        }
        .onAppear {
            checkCameraPermissions()
        }
        .alert("Требуется доступ к камере",
               isPresented: $showPermissionAlert) {
            Button("Настройки") {
                openAppSettings()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Пожалуйста, разрешите доступ к камере в настройках приложения")
        }
    }
    
    // MARK: - Subviews
    
    private var resultsView: some View {
        Group {
            if let result = cameraViewModel.latestPoseResult {
                PoseResultView(result: result)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding(.top, 50)
            }
            
            if cameraViewModel.isProcessing {
                ProcessingIndicatorView()
                    .padding(.top, 20)
            }
        }
    }
    
    private var controlPanel: some View {
        VStack(spacing: 20) {
            blurControl
            captureIntervalControl
            cameraToggleButton
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private var blurControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Интенсивность размытия: \(Int(blurLevel))")
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
            
            Slider(value: $blurLevel, in: 0...50, step: 1)
                .accentColor(.blue)
        }
    }
    
    private var captureIntervalControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Интервал съемки: \(Int(captureInterval)) сек")
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
            
            Stepper(value: $captureInterval, in: 1...5, step: 1) {
                EmptyView()
            }
            .labelsHidden()
        }
    }
    
    private var cameraToggleButton: some View {
        Button {
            isCameraActive.toggle()
            if isCameraActive {
                cameraViewModel.startSession()
            } else {
                cameraViewModel.stopSession()
            }
        } label: {
            Image(systemName: isCameraActive ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(isCameraActive ? .red : .green)
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkCameraPermissions() {
        cameraViewModel.checkPermissions { granted in
            showPermissionAlert = !granted
            if granted {
                isCameraActive = true
                cameraViewModel.startSession()
            }
        }
    }
    
    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

// MARK: - Additional Views

struct ProcessingIndicatorView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("Обработка...")
                .foregroundColor(.white)
                .font(.caption)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        viewModel.overlayView = PoseOverlayView(frame: view.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        if let overlay = viewModel.overlayView {
            view.addSubview(overlay)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
        
        viewModel.overlayView?.frame = uiView.bounds
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
