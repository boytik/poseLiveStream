//
//  FrameRateTracker.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import Combine
import Foundation

final class FrameRateTracker {
    @Published private(set) var frameRate: Double = 0
    private var frameCount = 0
    private var timer: AnyCancellable?
    
    var publisher: AnyPublisher<Double, Never> {
        $frameRate.eraseToAnyPublisher()
    }
    
    func startTracking() {
        stopTracking()
        timer = Timer
            .publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.frameRate = Double(self.frameCount)
                self.frameCount = 0
            }
    }
    
    func stopTracking() {
        timer?.cancel()
        timer = nil
    }
    
    func incrementFrame() {
        frameCount += 1
    }
    
    deinit {
        stopTracking()
    }
}

