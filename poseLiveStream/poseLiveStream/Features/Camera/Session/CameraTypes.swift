

import Foundation

enum CameraStatus {
    case unconfigured
    case configured
    case unauthorized
    case failed
}

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

