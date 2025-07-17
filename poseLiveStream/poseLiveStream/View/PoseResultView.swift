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
        VStack(alignment: .leading) {
            Text(result.pose)
                .font(.headline)
                .foregroundColor(.white)
            Text("\(Int(result.confidence * 100))%")
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

struct ProcessedImagePreview: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        if let image = viewModel.processedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                )
        }
    }
}
