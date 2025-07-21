

import AVFoundation

final class CameraSessionConfigurator {
    
    enum ConfigurationError: Error {
        case noCameraAvailable
        case cannotAddInput
        case cannotAddOutput
    }
    
    //MARK: Methods
    
    func configure(session: AVCaptureSession,
                   videoOutput: AVCaptureVideoDataOutput,
                   photoOutput: AVCapturePhotoOutput) throws {
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        session.sessionPreset = .hd1280x720
        
        try configureInput(for: session)
        try configureOutputs(session: session, videoOutput: videoOutput, photoOutput: photoOutput)
    }
    //MARK: Private Methods
    
    private func configureInput(for session: AVCaptureSession) throws {
        session.inputs.forEach { session.removeInput($0) }
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw ConfigurationError.noCameraAvailable
        }
        
        try camera.lockForConfiguration()
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
        }
        camera.unlockForConfiguration()
        
        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw ConfigurationError.cannotAddInput
        }
        session.addInput(input)
    }
    
    private func configureOutputs(session: AVCaptureSession,
                                  videoOutput: AVCaptureVideoDataOutput,
                                  photoOutput: AVCapturePhotoOutput) throws {
        session.outputs.forEach { session.removeOutput($0) }
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            throw ConfigurationError.cannotAddOutput
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            throw ConfigurationError.cannotAddOutput
        }
    }
}
