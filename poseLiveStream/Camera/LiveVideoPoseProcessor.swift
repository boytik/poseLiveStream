//
//  LiveVideoPoseProcessor.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import Foundation
import AVFoundation
import Vision

final class LiveVideoPoseProcessor {
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let queue = DispatchQueue(label: "live.pose.processor")

    var onPoseDetected: ((VNHumanBodyPoseObservation?) -> Void)?

    func process(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

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
}
