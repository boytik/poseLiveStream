

import SwiftUI
import AVFoundation
import Vision
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins


class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - Published Properties
    @Published var latestPoseResult: PoseClassificationResult?
    @Published var isProcessing = false
    @Published var cameraStatus: CameraStatus = .unconfigured
    @Published var error: CameraError?
    @Published var processedImage: UIImage?
    @Published var frameRate: Double = 0
    
    // MARK: - Properties
    private let poseHandler = LivePoseHandler()
    var config = CameraConfiguration()
    weak var overlayView: PoseOverlayView?
    private let sessionConfigurator = CameraSessionConfigurator()
    private var photoTimer: PhotoCaptureTimer?
    private let livePoseProcessor = LiveVideoPoseProcessor()
    private let poseProcessor = PoseProcessor()
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInitiated)
    private var captureTimer: Timer?
    private var lastCaptureTime = Date.distantPast
    private var lastProcessedFrameTime = Date.distantPast
    private var lastFrameRateCalculation = Date()
    private let frameRateTracker = FrameRateTracker()
    private var cancellables = Set<AnyCancellable>()
    
    private lazy var photoHandler: PhotoCaptureHandler = {
        PhotoHandlerFactory.makeHandler(
            config: config,
            onProcessed: { [weak self] image in
                self?.processedImage = image
            },
            onProcessingStateChanged: { [weak self] processing in
                self?.isProcessing = processing
            }
        )
    }()
    
    // MARK: - Lifecycle
    override init() {
        super.init()
        configureSession()
        setupFrameRateCalculation()

        poseHandler.onUpdateOverlay = { [weak self] observation in
            self?.overlayView?.updatePose(observation)
        }
        poseHandler.onClassified = { [weak self] result in
            self?.latestPoseResult = result
        }

        livePoseProcessor.onPoseDetected = { [weak self] observation in
            self?.poseHandler.handle(observation: observation)
        }
    }

    
    deinit {
        stopSession()
        frameRateTracker.stopTracking()
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
        photoTimer = PhotoCaptureTimer(interval: config.captureInterval) { [weak self] in
            self?.capturePhoto()
        }
        photoTimer?.start()
    }
    
    private func stopCaptureTimer() {
        photoTimer?.stop()
        photoTimer = nil
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
            
            do {
                try self.sessionConfigurator.configure(
                    session: self.session,
                    videoOutput: self.videoOutput,
                    photoOutput: self.photoOutput
                )
                
                self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
                
                DispatchQueue.main.async {
                    self.cameraStatus = .configured
                }
            } catch {
                DispatchQueue.main.async {
                    self.cameraStatus = .failed
                    self.error = .configurationFailed
                }
            }
        }
    }
    
    private func setupFrameRateCalculation() {
        frameRateTracker.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fps in
                self?.frameRate = fps
            }
            .store(in: &cancellables)

        frameRateTracker.startTracking()
    }
    
    // MARK: - Real-time Processing
    
    func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
        processVideoFrame(sampleBuffer)
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        frameRateTracker.incrementFrame()
        
        let now = Date()
        let interval = 1.0 / Double(config.processingFPS)
        guard now.timeIntervalSince(lastProcessedFrameTime) >= interval else { return }
        lastProcessedFrameTime = now

        livePoseProcessor.process(sampleBuffer: sampleBuffer)
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() {
        guard shouldCapturePhoto() else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: photoHandler)
        lastCaptureTime = Date()
    }
    
    private func shouldCapturePhoto() -> Bool {
        guard session.isRunning else {
            print("Session not running")
            return false
        }
        guard !isProcessing else {
            print("Already processing")
            return false
        }
        guard let connection = photoOutput.connection(with: .video), connection.isEnabled else {
            print("Photo output connection unavailable or disabled")
            return false
        }
        guard Date().timeIntervalSince(lastCaptureTime) >= config.captureInterval else {
            print("Waiting for capture interval")
            return false
        }
        return true
    }

}
