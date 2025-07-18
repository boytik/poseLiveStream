import UIKit
import Vision

final class CapturedImageProcessor {
    private let config: CameraConfiguration
    private let imageProcessor: ImageProcessor
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let faceRequest = VNDetectFaceRectanglesRequest()

    init(config: CameraConfiguration) {
        self.config = config
        self.imageProcessor = ImageProcessor(config: config)
    }

    func process(image: UIImage) -> UIImage? {
        guard let pose = detectPose(in: image) else { return nil }
        let faces = detectFaces(in: image)
        guard let blurred = imageProcessor.processImage(image, pose: pose, faceRects: faces) else { return nil }
        return imageProcessor.resizeImage(blurred)
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
}

