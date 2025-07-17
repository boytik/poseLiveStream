//
//  Extensions.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//
//import SwiftUI
//import AVFoundation
//import Vision
//import Combine
//import CoreImage
//import CoreImage.CIFilterBuiltins
//import Foundation
//
//// MARK: - AVCapturePhotoCaptureDelegate
//extension CameraViewModel: AVCapturePhotoCaptureDelegate {
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//        guard error == nil,
//              let imageData = photo.fileDataRepresentation(),
//              let image = UIImage(data: imageData) else { return }
//        
//        isProcessing = true
//        
//        processingQueue.async { [weak self] in
//            guard let self = self else { return }
//            
//            // Detect pose in captured image
//            guard let ciImage = CIImage(image: image) else { return }
//            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up)
//            
//            var detectedPose: VNHumanBodyPoseObservation?
//            
//            do {
//                try handler.perform([self.poseRequest])
//                detectedPose = self.poseRequest.results?.first as? VNHumanBodyPoseObservation
//            } catch {
//                print("Pose detection error: \(error)")
//            }
//            
//            // Process image
//            guard let processedImage = self.processImage(image, pose: detectedPose),
//                  let resizedImage = self.resizeImage(processedImage, maxDimension: 640) else {
//                self.isProcessing = false
//                return
//            }
//            
//            // Send to server
//            self.networkService.classifyPose(image: resizedImage) { [weak self] result in
//                DispatchQueue.main.async {
//                    self?.isProcessing = false
//                    
//                    switch result {
//                    case .success(let classification):
//                        self?.latestPoseResult = classification
//                    case .failure(let error):
//                        print("Server error: \(error)")
//                    }
//                }
//            }
//        }
//    }
//}
//
//// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
//extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//        
//        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
//        
//        do {
//            try requestHandler.perform([poseRequest])
//            
//            if let observation = poseRequest.results?.first as? VNHumanBodyPoseObservation {
//                DispatchQueue.main.async { [weak self] in
//                    self?.overlayView?.updatePose(observation)
//                }
//            }
//        } catch {
//            print("Pose detection error: \(error)")
//        }
//    }
//}
