//
//  CameraView.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import SwiftUI
import AVFoundation

// Основное View для отображения камеры
struct CameraView: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    // Создание UIView для камеры
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // 1. Настройка слоя предпросмотра камеры
        let previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill // Заполнение с сохранением пропорций
        view.layer.addSublayer(previewLayer)
        
        // 2. Добавление поверхностного View для рисования позы
        let overlayView = PoseOverlayView(frame: view.bounds)
        overlayView.isUserInteractionEnabled = false // Чтобы не перехватывало касания
        view.addSubview(overlayView)
        
        // Связываем overlayView с ViewModel
        viewModel.overlayView = overlayView
        
        // Запускаем камеру
        viewModel.startSession()
        
        return view
    }
    
    // Обновление View при изменениях
    func updateUIView(_ uiView: UIView, context: Context) {
        // Обновляем размеры слоя предпросмотра
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) {
            previewLayer.frame = uiView.bounds
        }
        
        // Обновляем размеры overlayView
        if let overlayView = uiView.subviews.first(where: { $0 is PoseOverlayView }) {
            overlayView.frame = uiView.bounds
        }
    }
    
    // Очистка при удалении View
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // ViewModel сама управляет остановкой сессии в deinit
    }
}

// Превью для Canvas в Xcode
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView(viewModel: CameraViewModel())
            .edgesIgnoringSafeArea(.all) // На весь экран
    }
}
