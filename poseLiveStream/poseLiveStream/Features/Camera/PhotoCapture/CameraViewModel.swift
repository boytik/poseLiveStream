

import SwiftUI
import AVFoundation
import Vision
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins

final class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - Published Properties
    
    @Published var latestPoseResult: PoseClassificationResult?
    @Published var isProcessing = false
    @Published var cameraStatus: CameraStatus = .unconfigured
    @Published var error: CameraError?
    @Published var processedImage: UIImage?
    @Published var frameRate: Double = 0
    
    // MARK: - Dependencies
    
    private let sessionConfigurator = CameraSessionConfigurator()
    private let frameRateTracker = FrameRateTracker()
    private let livePoseProcessor = LiveVideoPoseProcessor()
    private let poseProcessor = PoseProcessor()
    private let poseHandler = LivePoseHandler()
    
    // MARK: - Configuration
    
    var config = CameraConfiguration()
    weak var overlayView: PoseOverlayView?
    
    // MARK: - AVFoundation
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var photoHandler: PhotoCaptureHandler!
    
    // MARK: - Timers & Queues
    
    private var photoTimer: PhotoCaptureTimer?
    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInitiated)
    private var captureTimer: Timer?
    
    // MARK: - State Tracking
    
    private var lastCaptureTime = Date.distantPast
    private var lastProcessedFrameTime = Date.distantPast
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init / Deinit
    
    override init() {
        super.init()
        setupPhotoHandler()
        configureSession()
        setupFrameRateTracking()
        setupPoseCallbacks()
    }

    deinit {
        stopSession()
        frameRateTracker.stopTracking()
    }
    
    // MARK: - Session Control
    
    func startSession() {
        processingQueue.async { [weak self] in
            guard let self else { return }
            guard !session.isRunning else { return }
            
            session.startRunning()
            startCaptureTimer()
            updateStatus(.configured)
        }
    }
    
    func stopSession() {
        processingQueue.async { [weak self] in
            guard let self else { return }
            guard session.isRunning else { return }

            session.stopRunning()
            stopCaptureTimer()
        }
    }
    
    // MARK: - AVCapture Delegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        processVideoFrame(sampleBuffer)
    }
}

private extension CameraViewModel {
    
    // MARK: - Setup
    
    func configureSession() {
        CameraPermissionService.checkCameraPermission { [weak self] granted in
            guard let self else { return }
            granted ? setupCaptureSession() : updateStatus(.unauthorized, error: .permissionDenied)
        }
    }
    
    func setupCaptureSession() {
        processingQueue.async { [weak self] in
            guard let self else { return }
            
            do {
                try sessionConfigurator.configure(session: session, videoOutput: videoOutput, photoOutput: photoOutput)
                videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
                updateStatus(.configured)
            } catch {
                updateStatus(.failed, error: .configurationFailed)
            }
        }
    }
    
    func setupPhotoHandler() {
        photoHandler = PhotoHandlerFactory.makeHandler(
            config: config,
            onProcessed: { [weak self] image in self?.processedImage = image },
            onProcessingStateChanged: { [weak self] state in self?.isProcessing = state }
        )
    }
    
    func setupPoseCallbacks() {
        poseHandler.onUpdateOverlay = { [weak self] obs in self?.overlayView?.updatePose(obs) }
        poseHandler.onClassified = { [weak self] result in self?.latestPoseResult = result }
        livePoseProcessor.onPoseDetected = { [weak self] obs in self?.poseHandler.handle(observation: obs) }
    }

    func setupFrameRateTracking() {
        frameRateTracker.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fps in self?.frameRate = fps }
            .store(in: &cancellables)
        frameRateTracker.startTracking()
    }

    // MARK: - Capture Logic

    func processVideoFrame(_ buffer: CMSampleBuffer) {
        frameRateTracker.incrementFrame()

        let now = Date()
        let interval = 1.0 / Double(config.processingFPS)
        guard now.timeIntervalSince(lastProcessedFrameTime) >= interval else { return }
        lastProcessedFrameTime = now

        livePoseProcessor.process(sampleBuffer: buffer)
    }

    func capturePhoto() {
        guard shouldCapturePhoto() else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: photoHandler)
        lastCaptureTime = Date()
    }

    func shouldCapturePhoto() -> Bool {
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

    func startCaptureTimer() {
        photoTimer = PhotoCaptureTimer(interval: config.captureInterval) { [weak self] in self?.capturePhoto() }
        photoTimer?.start()
    }

    func stopCaptureTimer() {
        photoTimer?.stop()
        photoTimer = nil
    }

    // MARK: - Helpers

    func updateStatus(_ status: CameraStatus, error: CameraError? = nil) {
        DispatchQueue.main.async {
            self.cameraStatus = status
            self.error = error
        }
    }
}
