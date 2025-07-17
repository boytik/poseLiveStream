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
    }
    
    // MARK: - Properties
    private var observations: [VNHumanBodyPoseObservation] = []
    private var configuration = Configuration()
    private var fadeTimer: Timer?
    private var lastUpdateTime = Date()
    
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
    }
    
    // MARK: - Public Methods
    func updatePose(_ observation: VNHumanBodyPoseObservation?) {
        lastUpdateTime = Date()
        
        if let observation = observation {
            // Добавляем новое наблюдение в историю
            observations.append(observation)
            
            // Ограничиваем историю до 3 последних кадров
            if observations.count > 3 {
                observations.removeFirst()
            }
        } else {
            // Запускаем таймер для плавного исчезновения
            startFadeTimer()
        }
        
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
    
    func updateConfiguration(_ config: Configuration) {
        configuration = config
        setNeedsDisplay()
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.clear(rect)
        
        // Рисуем все наблюдения с разной прозрачностью
        for (index, observation) in observations.enumerated() {
            let alpha = CGFloat(1.0) - (CGFloat(index) * 0.3)
            drawObservation(observation, in: context, alpha: alpha)
        }
    }
    
    private func drawObservation(_ observation: VNHumanBodyPoseObservation,
                               in context: CGContext,
                               alpha: CGFloat) {
        // Рисуем соединения
        drawConnections(in: context, observation: observation, alpha: alpha)
        
        // Рисуем суставы
        drawJoints(in: context, observation: observation, alpha: alpha)
    }
    
    private func drawConnections(in context: CGContext,
                               observation: VNHumanBodyPoseObservation,
                               alpha: CGFloat) {
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
            (.leftEye, .rightEye), (.leftEye, .nose), (.rightEye, .nose),
            (.leftEar, .leftEye), (.rightEar, .rightEye)
        ]
        
        let color = configuration.connectionColor.withAlphaComponent(alpha)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(configuration.connectionWidth)
        context.setLineCap(.round)
        
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
        let allJoints = try? observation.recognizedPoints(.all)
        let color = configuration.jointColor.withAlphaComponent(alpha)
        context.setFillColor(color.cgColor)
        
        allJoints?.forEach { (jointName, point) in
            guard point.confidence > configuration.confidenceThreshold else { return }
            
            let location = normalizedPoint(for: point.location)
            let radius = configuration.jointRadius * (0.5 + CGFloat(point.confidence) * 0.5)
            
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
    
    // MARK: - Fade Animation
    private func startFadeTimer() {
        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            
            let elapsed = Date().timeIntervalSince(self.lastUpdateTime)
            if elapsed > self.configuration.fadeDuration {
                self.observations.removeAll()
                self.fadeTimer?.invalidate()
                self.fadeTimer = nil
            }
            
            self.setNeedsDisplay()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        fadeTimer?.invalidate()
    }
}
