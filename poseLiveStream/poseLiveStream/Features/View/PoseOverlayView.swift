//
//  PoseOverlayView.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//
import UIKit
import Vision

class PoseOverlayView: UIView {
    
    // MARK: - Configuration
    struct Configuration {
        var jointColor: UIColor = .systemGreen
        var connectionColor: UIColor = .systemOrange
        var jointRadius: CGFloat = 6.0
        var connectionWidth: CGFloat = 4.0
        var confidenceThreshold: Float = 0.3
        var fadeDuration: TimeInterval = 0.5
        var maxObservations: Int = 3
        var highlightColor: UIColor = .systemRed
        var highlightJoints: [VNHumanBodyPoseObservation.JointName] = [.nose, .leftWrist, .rightWrist]
    }
    
    // MARK: - Properties
    private var observations: [VNHumanBodyPoseObservation] = []
    private var configuration = Configuration()
    private var displayLink: CADisplayLink?
    private var lastUpdateTime = Date()
    
    // Pre-allocated objects for better performance
    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.leftEye, .rightEye), (.leftEye, .nose), (.rightEye, .nose),
        (.leftEar, .leftEye), (.rightEar, .rightEye)
    ]
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        isOpaque = false
        layer.drawsAsynchronously = true // Improve performance
    }
    
    // MARK: - Public Methods
    func updatePose(_ observation: VNHumanBodyPoseObservation?) {
        lastUpdateTime = Date()
        
        if let observation = observation {
            observations.append(observation)
            if observations.count > configuration.maxObservations {
                observations.removeFirst()
            }
        } else {
            startFadeAnimation()
        }
        
        setNeedsDisplay()
    }
    
    func updateConfiguration(_ config: Configuration) {
        configuration = config
        setNeedsDisplay()
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.clear(rect)
        
        let elapsed = Date().timeIntervalSince(lastUpdateTime)
        let progress = min(elapsed / configuration.fadeDuration, 1.0)
        let remainingAlpha = 1.0 - CGFloat(progress)
        
        for (index, observation) in observations.enumerated() {
            let alpha = remainingAlpha * (1.0 - (CGFloat(index) * 0.3))
            drawObservation(observation, in: context, alpha: alpha)
        }
    }
    
    private func drawObservation(_ observation: VNHumanBodyPoseObservation,
                               in context: CGContext,
                               alpha: CGFloat) {
        drawConnections(in: context, observation: observation, alpha: alpha)
        drawJoints(in: context, observation: observation, alpha: alpha)
    }
    
    private func drawConnections(in context: CGContext,
                               observation: VNHumanBodyPoseObservation,
                               alpha: CGFloat) {
        let color = configuration.connectionColor.withAlphaComponent(alpha)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(configuration.connectionWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        for (startJoint, endJoint) in connections {
            guard let startPoint = try? observation.recognizedPoint(startJoint),
                  let endPoint = try? observation.recognizedPoint(endJoint),
                  startPoint.confidence > configuration.confidenceThreshold,
                  endPoint.confidence > configuration.confidenceThreshold else { continue }
            
            let startLocation = normalizedPoint(for: startPoint.location)
            let endLocation = normalizedPoint(for: endPoint.location)
            
            context.move(to: startLocation)
            context.addLine(to: endLocation)
            context.strokePath()
        }
    }
    
    private func drawJoints(in context: CGContext,
                          observation: VNHumanBodyPoseObservation,
                          alpha: CGFloat) {
        guard let allJoints = try? observation.recognizedPoints(.all) else { return }
        
        // Draw regular joints
        let regularColor = configuration.jointColor.withAlphaComponent(alpha)
        context.setFillColor(regularColor.cgColor)
        
        for (jointName, point) in allJoints {
            guard point.confidence > configuration.confidenceThreshold else { continue }
            
            let location = normalizedPoint(for: point.location)
            let radius = configuration.jointRadius * (0.5 + CGFloat(point.confidence) * 0.5)
            
            if configuration.highlightJoints.contains(jointName) {
                // Draw highlight ring
                let highlightColor = configuration.highlightColor.withAlphaComponent(alpha)
                context.setFillColor(highlightColor.cgColor)
                context.fillEllipse(in: CGRect(
                    x: location.x - radius * 1.5,
                    y: location.y - radius * 1.5,
                    width: radius * 3,
                    height: radius * 3
                ))
                
                // Draw inner circle
                context.setFillColor(regularColor.cgColor)
            }
            
            context.fillEllipse(in: CGRect(
                x: location.x - radius,
                y: location.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
    }
    
    private func normalizedPoint(for visionPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: visionPoint.x * bounds.width,
            y: (1 - visionPoint.y) * bounds.height
        )
    }
    
    // MARK: - Animation
    private func startFadeAnimation() {
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func handleDisplayLink() {
        let elapsed = Date().timeIntervalSince(lastUpdateTime)
        if elapsed > configuration.fadeDuration {
            observations.removeAll()
            displayLink?.invalidate()
            displayLink = nil
        }
        setNeedsDisplay()
    }
    
    // MARK: - Cleanup
    deinit {
        displayLink?.invalidate()
    }
}
