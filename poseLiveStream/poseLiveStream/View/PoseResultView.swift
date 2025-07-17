//
//  PoseResultView.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import SwiftUI

struct PoseResultView: View {
    let result: PoseClassificationResult
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Основная информация о позе
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.pose)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    ConfidenceBar(value: result.confidence)
                }
                
                Spacer()
                
                // Кнопка расширения
                if hasAlternatives {
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
            }
            
            // Альтернативные позы (если есть)
            if isExpanded && hasAlternatives {
                Divider()
                    .background(Color.white.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Другие варианты:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    ForEach(result.alternatives?.prefix(3) ?? [], id: \.pose) { alt in
                        AlternativePoseView(pose: alt.pose, confidence: Double(alt.confidence))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark)))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    private var hasAlternatives: Bool {
        !(result.alternatives?.isEmpty ?? true)
    }
}

// Вспомогательные View компоненты

struct ConfidenceBar: View {
    let value: Float  // Используем Float вместо Double
    
    var body: some View {
        HStack(spacing: 6) {
            Text("\(Int(value * 100))%")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(confidenceColor)
                .frame(width: 36, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(confidenceColor)
                        .frame(width: geometry.size.width * CGFloat(value), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
    
    private var confidenceColor: Color {
        switch value {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .red
        }
    }
}

struct AlternativePoseView: View {
    let pose: String
    let confidence: Double
    
    var body: some View {
        HStack {
            Text(pose)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(Int(confidence * 100))%")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(confidenceColor)
        }
        .padding(8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var confidenceColor: Color {
        confidence > 0.5 ? .green : .yellow
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}
