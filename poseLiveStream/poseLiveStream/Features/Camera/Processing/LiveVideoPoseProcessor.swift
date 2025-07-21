

import Foundation
import AVFoundation
import Vision
import UIKit
import ImageIO

final class LiveVideoPoseProcessor {
    //MARK: Properties
    
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let queue = DispatchQueue(label: "live.pose.processor")

    var onPoseDetected: ((VNHumanBodyPoseObservation?) -> Void)?

    //MARK: Method
    
    func process(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let orientation = exifOrientationForCurrentDeviceOrientation()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)

        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                try handler.perform([self.poseRequest])
                let result = self.poseRequest.results?.first
                DispatchQueue.main.async {
                    self.onPoseDetected?(result)
                }
            } catch {
                print("Live pose detection error: \(error.localizedDescription)")
            }
        }
    }
    
    //MARK: Private Method
    
    private func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
        case .portraitUpsideDown: return .left
        case .landscapeLeft: return .upMirrored
        case .landscapeRight: return .down
        case .portrait: return .right
        default: return .right
        }
    }
}

