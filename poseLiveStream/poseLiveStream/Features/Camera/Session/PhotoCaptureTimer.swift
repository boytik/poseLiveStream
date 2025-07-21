

import Foundation

final class PhotoCaptureTimer {
    
    //MARK: Properties
    private var timer: Timer?
    private let interval: TimeInterval
    private let action: () -> Void
    
    //MARK: Init
    init(interval: TimeInterval, action: @escaping () -> Void) {
        self.interval = interval
        self.action = action
    }
    
    //MARK: Methods
    func start() {
        stop()
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
    
    //MARK: Life Cycle
    deinit {
        stop()
    }
}

