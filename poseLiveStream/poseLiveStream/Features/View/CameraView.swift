//
//  CameraView.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        let overlayView = PoseOverlayView(frame: view.bounds)
        overlayView.isUserInteractionEnabled = false
        view.addSubview(overlayView)
        
        viewModel.overlayView = overlayView
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
