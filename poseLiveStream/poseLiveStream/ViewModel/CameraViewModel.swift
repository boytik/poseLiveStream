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

class CameraViewModel: NSObject, ObservableObject {
    // MARK: - Configuration
    struct Configuration {
        var captureInterval: TimeInterval = 2.0
        var blurRadius: CGFloat = 30
        var preserveFace: Bool = true
        var maxImageDimension: CGFloat = 640
        var confidenceThreshold: Float = 0.3
    }
    
    // MARK: - Published Properties
    @Published var latestPoseResult: PoseClassificationResult?
    @Published var isProcessing = false
    @Published var cameraStatus: CameraStatus = .unconfigured
    @Published var error: CameraError?
    @Published var processedImage: UIImage?
    
    // MARK: - Properties
    var config = Configuration()
    weak var overlayView: PoseOverlayView?
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let processingQueue = DispatchQueue(label: "camera.processing", qos: .userInitiated)
    private var captureTimer: Timer?
    private var lastCaptureTime = Date.distantPast
    private let context = CIContext()
    private var cancellables = Set<AnyCancellable>()
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let faceRequest = VNDetectFaceRectanglesRequest()
    
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
                self.startPeriodicCapture()
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
                self.stopPeriodicCapture()
            }
        }
    }
    
    // MARK: - Configuration
    private func configureSession() {
        checkPermissions { [weak self] granted in
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
        
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraError.cannotAddInput
        }
        session.addInput(input)
    }
    
    private func setupOutputs() {
        session.outputs.forEach { session.removeOutput($0) }
        
        // Video Output
        if session.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            session.addOutput(videoOutput)
        }
        
        // Photo Output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.connection(with: .video)?.isEnabled = true
        }
    }
    
    // MARK: - Permission Handling
    func checkPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    // MARK: - Capture Handling
    private func startPeriodicCapture() {
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
    
    private func stopPeriodicCapture() {
        DispatchQueue.main.async { [weak self] in
            self?.captureTimer?.invalidate()
            self?.captureTimer = nil
        }
    }
    
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
    
    // MARK: - Image Processing
    private func processCapturedImage(_ image: UIImage) {
        isProcessing = true
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Detect pose and face
            guard let pose = self.detectPose(in: image) else {
                DispatchQueue.main.async { self.isProcessing = false }
                return
            }
            
            let faceRectangles = self.detectFaces(in: image)
            
            // 2. Apply privacy effects
            guard let processedImage = self.applyPrivacyEffects(to: image, pose: pose, faceRectangles: faceRectangles),
                  let resizedImage = self.resizeImage(processedImage) else {
                DispatchQueue.main.async { self.isProcessing = false }
                return
            }
            
            // 3. Store processed image
            self.storeProcessedImage(resizedImage)
            
            // 4. Send to server
            self.sendToServer(resizedImage, pose: pose)
        }
    }
    
    private func detectPose(in image: UIImage) -> VNHumanBodyPoseObservation? {
        guard let cgImage = image.cgImage else { return nil }
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([poseRequest])
            return poseRequest.results?.first
        } catch {
            print("Pose detection failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func detectFaces(in image: UIImage) -> [CGRect] {
        guard config.preserveFace, let cgImage = image.cgImage else { return [] }
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([faceRequest])
            return faceRequest.results?.map { $0.boundingBox } ?? []
        } catch {
            print("Face detection failed: \(error.localizedDescription)")
            return []
        }
    }
    
    private func applyPrivacyEffects(to image: UIImage, pose: VNHumanBodyPoseObservation, faceRectangles: [CGRect]) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let bodyRegion = calculateBodyRegion(for: pose, imageSize: image.size)
        let blurredImage = applyBlur(to: ciImage, in: bodyRegion, excluding: faceRectangles)
        
        return drawPoseLandmarks(on: blurredImage, pose: pose)
    }
    
    private func calculateBodyRegion(for pose: VNHumanBodyPoseObservation, imageSize: CGSize) -> CGRect {
        let keyPoints: [VNHumanBodyPoseObservation.JointName] = [
            .leftShoulder, .rightShoulder, .leftHip, .rightHip
        ]
        
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        for jointName in keyPoints {
            if let point = try? pose.recognizedPoint(jointName), point.confidence > config.confidenceThreshold {
                let x = point.location.x * imageSize.width
                let y = (1 - point.location.y) * imageSize.height
                
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        
        let expansion: CGFloat = 1.5
        let width = (maxX - minX) * expansion
        let height = (maxY - minY) * expansion
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        return CGRect(
            x: centerX - width / 2,
            y: centerY - height / 2,
            width: width,
            height: height
        )
    }
    
    private func applyBlur(to image: CIImage, in region: CGRect, excluding faceRectangles: [CGRect]) -> CIImage {
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = image
        blurFilter.radius = Float(config.blurRadius)
        
        guard let blurredImage = blurFilter.outputImage else { return image }
        
        // Create a mask that covers the body but excludes faces
        let bodyMask = createBodyMask(imageSize: image.extent.size, bodyRegion: region, faceRectangles: faceRectangles)
        
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = blurredImage
        blendFilter.backgroundImage = image
        blendFilter.maskImage = bodyMask
        
        return blendFilter.outputImage ?? image
    }
    
    private func createBodyMask(imageSize: CGSize, bodyRegion: CGRect, faceRectangles: [CGRect]) -> CIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        
        let maskImage = renderer.image { context in
            // Fill entire image with white (will be blurred)
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
            
            // Fill body region with black (will not be blurred)
            UIColor.black.setFill()
            context.fill(bodyRegion)
            
            // Fill face regions with white (will be blurred)
            if config.preserveFace {
                UIColor.white.setFill()
                for faceRect in faceRectangles {
                    // Convert faceRect from normalized coordinates
                    let convertedRect = CGRect(
                        x: faceRect.origin.x * imageSize.width,
                        y: (1 - faceRect.origin.y - faceRect.height) * imageSize.height,
                        width: faceRect.width * imageSize.width,
                        height: faceRect.height * imageSize.height
                    )
                    context.fill(convertedRect)
                }
            }
        }
        
        return CIImage(image: maskImage) ?? CIImage(color: CIColor.white)
    }
    
    private func drawPoseLandmarks(on image: CIImage, pose: VNHumanBodyPoseObservation?) -> UIImage? {
        guard let pose = pose else { return UIImage(ciImage: image) }
        
        let renderer = UIGraphicsImageRenderer(size: image.extent.size)
        
        return renderer.image { context in
            // Draw original image
            UIImage(ciImage: image).draw(at: .zero)
            
            // Draw pose connections
            drawPoseConnections(pose, context: context.cgContext, imageSize: image.extent.size)
            
            // Draw joints
            drawJoints(pose, context: context.cgContext, imageSize: image.extent.size)
        }
    }
    
    private func drawPoseConnections(_ pose: VNHumanBodyPoseObservation, context: CGContext, imageSize: CGSize) {
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
        ]
        
        context.setStrokeColor(UIColor.systemPink.cgColor)
        context.setLineWidth(8.0)
        context.setLineCap(.round)
        
        for (startJoint, endJoint) in connections {
            guard let startPoint = try? pose.recognizedPoint(startJoint),
                  let endPoint = try? pose.recognizedPoint(endJoint),
                  startPoint.confidence > config.confidenceThreshold,
                  endPoint.confidence > config.confidenceThreshold else { continue }
            
            let start = CGPoint(
                x: startPoint.location.x * imageSize.width,
                y: (1 - startPoint.location.y) * imageSize.height
            )
            let end = CGPoint(
                x: endPoint.location.x * imageSize.width,
                y: (1 - endPoint.location.y) * imageSize.height
            )
            
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        }
    }
    
    private func drawJoints(_ pose: VNHumanBodyPoseObservation, context: CGContext, imageSize: CGSize) {
        context.setFillColor(UIColor.systemOrange.cgColor)
        
        let allJoints = try? pose.recognizedPoints(.all)
        allJoints?.forEach { (_, point) in
            guard point.confidence > config.confidenceThreshold else { return }
            
            let location = CGPoint(
                x: point.location.x * imageSize.width,
                y: (1 - point.location.y) * imageSize.height
            )
            
            context.fillEllipse(in: CGRect(
                x: location.x - 12,
                y: location.y - 12,
                width: 24,
                height: 24
            ))
        }
    }
    
    private func resizeImage(_ image: UIImage) -> UIImage? {
        let ratio = min(config.maxImageDimension / image.size.width,
                       config.maxImageDimension / image.size.height)
        guard ratio < 1 else { return image }
        
        let newSize = CGSize(width: image.size.width * ratio,
                            height: image.size.height * ratio)
        
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func storeProcessedImage(_ image: UIImage) {
        DispatchQueue.main.async {
            self.processedImage = image
        }
    }
    
    // MARK: - Network Communication
    private func sendToServer(_ image: UIImage, pose: VNHumanBodyPoseObservation) {
        NetworkService().classifyPose(image: image) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let classification):
                    self?.latestPoseResult = classification
                case .failure(let error):
                    self?.error = .networkError(error)
                }
            }
        }
    }
}

// MARK: - AVCapture Delegates
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        do {
            try handler.perform([poseRequest])
            if let observation = poseRequest.results?.first {
                DispatchQueue.main.async { [weak self] in
                    self?.overlayView?.updatePose(observation)
                }
            }
        } catch {
            print("Real-time pose detection error: \(error.localizedDescription)")
        }
    }
}

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

