//
//  PoseResultView.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import SwiftUI

struct PoseResultView: View {
    let result: PoseClassificationResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка состояния
            Image(systemName: result.confidence > 0.7 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(result.confidence > 0.7 ? .green : .yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                // Название позы
                Text(result.pose.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                // Прогресс бар уверенности
                ConfidenceBar(confidence: Double(result.confidence))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(result.confidence > 0.7 ? Color.green.opacity(0.5) : Color.yellow.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, 8)
    }
}

struct ProcessedImagePreview: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        if let image = viewModel.processedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(radius: 5)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

struct ConfidenceBar: View {
    let confidence: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: geometry.size.width, height: 4)
                    .foregroundColor(Color.white.opacity(0.2))
                
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: min(CGFloat(confidence) * geometry.size.width, geometry.size.width), height: 4)
                    .foregroundColor(confidence > 0.7 ? .green : .yellow)
                    .animation(.easeInOut, value: confidence)
            }
        }
        .frame(height: 4)
    }
}
