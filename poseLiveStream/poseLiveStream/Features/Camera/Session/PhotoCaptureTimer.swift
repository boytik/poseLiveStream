//
//  PhotoCaptureTimer.swift
//  poseLiveStream
//
//  Created by Евгений on 17.07.2025.
//

import Foundation

final class PhotoCaptureTimer {
    private var timer: Timer?
    private let interval: TimeInterval
    private let action: () -> Void

    init(interval: TimeInterval, action: @escaping () -> Void) {
        self.interval = interval
        self.action = action
    }

    func start() {
        stop() // гарантируем, что старый таймер уничтожен
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: true) { _ in
                self.action()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}

