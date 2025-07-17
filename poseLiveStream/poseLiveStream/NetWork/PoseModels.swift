//
//  PoseMdeols.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

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
