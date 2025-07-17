//
//  CameraViewModel.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import SwiftUI
import AVFoundation
import Vision
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins


class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: - Configuration
    struct Configuration {
        var captureInterval: TimeInterval = 2.0
        var blurRadius: CGFloat = 30
        var preserveFace: Bool = true
        var maxImageDimension: CGFloat = 640
        var confidenceThreshold: Float = 0.3
        var processingFPS: Int = 10
    }
    
    // MARK: - Published Properties
    @Published var latestPoseResult: PoseClassificationResult?
    @Published var isProcessing = false
    @Published var cameraStatus: CameraStatus = .unconfigured
    @Published var error: CameraError?
    @Published var processedImage: UIImage?
    @Published var frameRate: Double = 0
    
    // MARK: - Properties
    var config = Configuration()
    weak var overlayView: PoseOverlayView?
    private lazy var imageProcessor = ImageProcessor(config: config)
    private lazy var capturedImageProcessor = CapturedImageProcessor(config: config)

    private let livePoseProcessor = LiveVideoPoseProcessor()
    private let poseProcessor = PoseProcessor()
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInitiated)
    private var captureTimer: Timer?
    private var lastCaptureTime = Date.distantPast
    private var lastProcessedFrameTime = Date.distantPast
    private var frameCount = 0
    private var lastFrameRateCalculation = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Camera Status
    enum CameraStatus {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }
    
    // MARK: - Error Handling
    enum CameraError: Error {
        case noCameraAvailable
        case cannotAddInput
        case cannotAddOutput
        case permissionDenied
        case configurationFailed
        case networkError(Error)
        case processingFailed
        
        var localizedDescription: String {
            switch self {
            case .noCameraAvailable: return "Camera not available"
            case .cannotAddInput: return "Can't add camera input"
            case .cannotAddOutput: return "Can't add camera output"
            case .permissionDenied: return "Permission denied"
            case .configurationFailed: return "Configuration failed"
            case .networkError(let error): return "Network error: \(error.localizedDescription)"
            case .processingFailed: return "Image processing failed"
            }
        }
    }
    
    // MARK: - Lifecycle
    override init() {
        super.init()
        configureSession()
        setupFrameRateCalculation()
        livePoseProcessor.onPoseDetected = { [weak self] observation in
            guard let self = self else { return }
            self.overlayView?.updatePose(observation)
            if let obs = observation {
                self.classifyPose(obs)
            } else {
                self.latestPoseResult = nil
            }
        }
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Session Management
    func startSession() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.session.isRunning {
                self.session.startRunning()
                self.startCaptureTimer()
                DispatchQueue.main.async {
                    self.cameraStatus = .configured
                }
            }
        }
    }
    
    func stopSession() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
                self.stopCaptureTimer()
            }
        }
    }
    
    private func startCaptureTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.captureTimer?.invalidate()
            self?.captureTimer = Timer.scheduledTimer(
                withTimeInterval: self?.config.captureInterval ?? 2.0,
                repeats: true
            ) { [weak self] _ in
                self?.capturePhoto()
            }
        }
    }
    
    private func stopCaptureTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.captureTimer?.invalidate()
            self?.captureTimer = nil
        }
    }
    
    // MARK: - Configuration
    private func configureSession() {
        CameraPermissionService.checkCameraPermission { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                self.setupCaptureSession()
            } else {
                DispatchQueue.main.async {
                    self.cameraStatus = .unauthorized
                    self.error = .permissionDenied
                }
            }
        }
    }
    
    private func setupCaptureSession() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            
            do {
                self.session.sessionPreset = .hd1280x720
                try self.setupInputs()
                self.setupOutputs()
                
                DispatchQueue.main.async {
                    self.cameraStatus = .configured
                }
            } catch let error as CameraError {
                DispatchQueue.main.async {
                    self.cameraStatus = .failed
                    self.error = error
                }
            } catch {
                DispatchQueue.main.async {
                    self.cameraStatus = .failed
                    self.error = .configurationFailed
                }
            }
        }
    }
    
    private func setupInputs() throws {
        session.inputs.forEach { session.removeInput($0) }
        
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw CameraError.noCameraAvailable
        }
        
        try camera.lockForConfiguration()
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }
        camera.unlockForConfiguration()
        
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
    }
    
    private func setupOutputs() {
        session.outputs.forEach { session.removeOutput($0) }
        
        // Video Output для реального времени
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            if let connection = videoOutput.connection(with: .video) {
                connection.videoRotationAngle = 0
                connection.isEnabled = true
            }
        } else {
            error = .cannotAddOutput
            cameraStatus = .failed
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.connection(with: .video)?.isEnabled = true
        }
    }
    
    
    private func setupFrameRateCalculation() {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.frameRate = Double(self.frameCount)
                self.frameCount = 0
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Real-time Processing
    func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
        processVideoFrame(sampleBuffer)
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        frameCount += 1

        let now = Date()
        let interval = 1.0 / Double(config.processingFPS)
        guard now.timeIntervalSince(lastProcessedFrameTime) >= interval else { return }
        lastProcessedFrameTime = now

        livePoseProcessor.process(sampleBuffer: sampleBuffer)
    }

    
    // MARK: - Pose Classification
    private func classifyPose(_ observation: VNHumanBodyPoseObservation) {
        latestPoseResult = poseProcessor.classifyPose(observation)
    }
    
    
    // MARK: - Photo Capture
    func capturePhoto() {
        guard shouldCapturePhoto() else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        lastCaptureTime = Date()
    }
    
    private func shouldCapturePhoto() -> Bool {
        guard session.isRunning,
              !isProcessing,
              let connection = photoOutput.connection(with: .video),
              connection.isEnabled,
              Date().timeIntervalSince(lastCaptureTime) >= config.captureInterval else {
            return false
        }
        return true
    }
    
    private func processCapturedImage(_ image: UIImage) {
        isProcessing = true
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let result = self.capturedImageProcessor.process(image: image)

            DispatchQueue.main.async {
                self.processedImage = result
                self.isProcessing = false
            }
        }
    }

}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                   didFinishProcessingPhoto photo: AVCapturePhoto,
                   error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            isProcessing = false
            return
        }
        processCapturedImage(image)
    }
}
