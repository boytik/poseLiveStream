import Vision

final class LivePoseHandler {
    var onUpdateOverlay: ((VNHumanBodyPoseObservation?) -> Void)?
    var onClassified: ((PoseClassificationResult?) -> Void)?

    private let classifier: PoseProcessor

    init(classifier: PoseProcessor = PoseProcessor()) {
        self.classifier = classifier
    }

    func handle(observation: VNHumanBodyPoseObservation?) {
        onUpdateOverlay?(observation)

        if let observation {
            let result = classifier.classifyPose(observation)
            onClassified?(result)
        } else {
            onClassified?(nil)
        }
    }
}

