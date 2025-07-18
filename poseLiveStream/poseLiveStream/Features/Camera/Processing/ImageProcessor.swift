//
//  ImageProcessor.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//
import UIKit
import Vision
import CoreImage

final class ImageProcessor {
    private let context = CIContext()
    private let config: CameraViewModel.Configuration

    init(config: CameraViewModel.Configuration) {
        self.config = config
    }

    func processImage(
        _ image: UIImage,
        pose: VNHumanBodyPoseObservation,
        faceRects: [CGRect]
    ) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let bodyRegion = calculateBodyRegion(for: pose, imageSize: image.size)
        let blurred = applyBlur(to: ciImage, in: bodyRegion, excluding: faceRects)
        return drawPoseLandmarks(on: blurred, pose: pose)
    }

    func resizeImage(_ image: UIImage) -> UIImage? {
        let ratio = min(config.maxImageDimension / image.size.width,
                        config.maxImageDimension / image.size.height)
        guard ratio < 1 else { return image }

        let newSize = CGSize(width: image.size.width * ratio,
                             height: image.size.height * ratio)

        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func calculateBodyRegion(for pose: VNHumanBodyPoseObservation, imageSize: CGSize) -> CGRect {
        let keyPoints: [VNHumanBodyPoseObservation.JointName] = [.leftShoulder, .rightShoulder, .leftHip, .rightHip]

        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity

        for jointName in keyPoints {
            if let point = try? pose.recognizedPoint(jointName),
               point.confidence > config.confidenceThreshold {
                let x = point.location.x * imageSize.width
                let y = (1 - point.location.y) * imageSize.height
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }

        let expansion: CGFloat = 1.5
        let width = (maxX - minX) * expansion
        let height = (maxY - minY) * expansion
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
    }

    private func applyBlur(to image: CIImage, in region: CGRect, excluding faces: [CGRect]) -> CIImage {
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = image
        blurFilter.radius = Float(config.blurRadius)
        guard let blurred = blurFilter.outputImage else { return image }

        let mask = createMask(imageSize: image.extent.size, bodyRegion: region, faceRects: faces)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = blurred
        blend.backgroundImage = image
        blend.maskImage = mask

        return blend.outputImage ?? image
    }

    private func createMask(imageSize: CGSize, bodyRegion: CGRect, faceRects: [CGRect]) -> CIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let maskImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))
            UIColor.black.setFill()
            ctx.fill(bodyRegion)

            if config.preserveFace {
                for face in faceRects {
                    let converted = CGRect(
                        x: face.origin.x * imageSize.width,
                        y: (1 - face.origin.y - face.height) * imageSize.height,
                        width: face.width * imageSize.width,
                        height: face.height * imageSize.height
                    )
                    ctx.fill(converted)
                }
            }
        }
        return CIImage(image: maskImage) ?? CIImage(color: CIColor.white)
    }

    private func drawPoseLandmarks(on image: CIImage, pose: VNHumanBodyPoseObservation?) -> UIImage? {
        guard let pose = pose else { return UIImage(ciImage: image) }
        let size = image.extent.size

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIImage(ciImage: image).draw(at: .zero)
            drawConnections(pose, context: ctx.cgContext, size: size)
            drawJoints(pose, context: ctx.cgContext, size: size)
        }
    }

    private func drawConnections(_ pose: VNHumanBodyPoseObservation, context: CGContext, size: CGSize) {
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
        ]
        context.setStrokeColor(UIColor.systemPink.cgColor)
        context.setLineWidth(8)
        context.setLineCap(.round)

        for (a, b) in connections {
            if let p1 = try? pose.recognizedPoint(a), let p2 = try? pose.recognizedPoint(b),
               p1.confidence > config.confidenceThreshold,
               p2.confidence > config.confidenceThreshold {
                let start = CGPoint(x: p1.location.x * size.width, y: (1 - p1.location.y) * size.height)
                let end = CGPoint(x: p2.location.x * size.width, y: (1 - p2.location.y) * size.height)
                context.move(to: start)
                context.addLine(to: end)
                context.strokePath()
            }
        }
    }

    private func drawJoints(_ pose: VNHumanBodyPoseObservation, context: CGContext, size: CGSize) {
        context.setFillColor(UIColor.systemOrange.cgColor)
        let joints = try? pose.recognizedPoints(.all)

        joints?.forEach { _, point in
            if point.confidence > config.confidenceThreshold {
                let p = CGPoint(x: point.location.x * size.width, y: (1 - point.location.y) * size.height)
                context.fillEllipse(in: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24))
            }
        }
    }
}
