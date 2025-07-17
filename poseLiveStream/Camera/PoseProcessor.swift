
import Vision
import Foundation

struct PoseClassificationResult: Codable {
    let pose: String
    let confidence: Float
    let alternatives: [AlternativePose]?
    
}
struct AlternativePose: Codable {
    let pose: String
    let confidence: Float
}

class PoseProcessor {
    private let confidenceThreshold: Float

    init(confidenceThreshold: Float = 0.3) {
        self.confidenceThreshold = confidenceThreshold
    }

    func classifyPose(_ observation: VNHumanBodyPoseObservation) -> PoseClassificationResult {
        guard let keypoints = try? observation.recognizedPoints(.all) else {
            return PoseClassificationResult(pose: "Unknown", confidence: 0.0, alternatives: [])
        }

        let (poseName, confidence) = analyzePose(keypoints)
        return PoseClassificationResult(pose: poseName, confidence: confidence, alternatives: [])
    }

    private func analyzePose(_ keypoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> (String, Float) {
        if isStandingPose(keypoints) {
            return ("Standing", 0.9)
        } else if isSittingPose(keypoints) {
            return ("Sitting", 0.85)
        } else if isWalkingPose(keypoints) {
            return ("Walking", 0.8)
        } else if isRaisedHandsPose(keypoints) {
            return ("Raised Hands", 0.75)
        } else {
            return ("Unknown", 0.5)
        }
    }

    private func isStandingPose(_ keypoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Bool {
        guard let leftHip = keypoints[.leftHip], leftHip.confidence > confidenceThreshold,
              let rightHip = keypoints[.rightHip], rightHip.confidence > confidenceThreshold,
              let leftKnee = keypoints[.leftKnee], leftKnee.confidence > confidenceThreshold,
              let rightKnee = keypoints[.rightKnee], rightKnee.confidence > confidenceThreshold else {
            return false
        }
        return abs(leftHip.location.y - leftKnee.location.y) < 0.2 &&
               abs(rightHip.location.y - rightKnee.location.y) < 0.2
    }

    private func isSittingPose(_ keypoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Bool {
        guard let leftHip = keypoints[.leftHip], leftHip.confidence > confidenceThreshold,
              let rightHip = keypoints[.rightHip], rightHip.confidence > confidenceThreshold,
              let leftKnee = keypoints[.leftKnee], leftKnee.confidence > confidenceThreshold,
              let rightKnee = keypoints[.rightKnee], rightKnee.confidence > confidenceThreshold else {
            return false
        }
        return (leftHip.location.y - leftKnee.location.y) > 0.3 &&
               (rightHip.location.y - rightKnee.location.y) > 0.3
    }

    private func isWalkingPose(_ keypoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Bool {
        guard let leftAnkle = keypoints[.leftAnkle], leftAnkle.confidence > confidenceThreshold,
              let rightAnkle = keypoints[.rightAnkle], rightAnkle.confidence > confidenceThreshold else {
            return false
        }
        return abs(leftAnkle.location.y - rightAnkle.location.y) > 0.1
    }

    private func isRaisedHandsPose(_ keypoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> Bool {
        guard let leftWrist = keypoints[.leftWrist], leftWrist.confidence > confidenceThreshold,
              let rightWrist = keypoints[.rightWrist], rightWrist.confidence > confidenceThreshold,
              let leftShoulder = keypoints[.leftShoulder], leftShoulder.confidence > confidenceThreshold,
              let rightShoulder = keypoints[.rightShoulder], rightShoulder.confidence > confidenceThreshold else {
            return false
        }
        return leftWrist.location.y < leftShoulder.location.y &&
               rightWrist.location.y < rightShoulder.location.y
    }
}
