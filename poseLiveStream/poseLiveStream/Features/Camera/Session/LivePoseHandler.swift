

import Vision

final class LivePoseHandler {
    
    //MARK: Properties
    
    var onUpdateOverlay: ((VNHumanBodyPoseObservation?) -> Void)?
    var onClassified: ((PoseClassificationResult?) -> Void)?

    private let classifier: PoseProcessor

    //MARK: Init
    
    init(classifier: PoseProcessor = PoseProcessor()) {
        self.classifier = classifier
    }

    //MARK: Method
    
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

