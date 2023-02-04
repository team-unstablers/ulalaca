//
// Created by Gyuhwan Park on 2023/02/04.
//

import Foundation

protocol ScreenLockObserverDelegate {
    func screenIsLocked()
    func screenIsUnlocked()
}

class ScreenLockObserver: NSObject {
    public var delegate: ScreenLockObserverDelegate? = nil

    private let notificationCenter = DistributedNotificationCenter.default

    override init() {
        super.init()

        startObserve()
    }

    deinit {
        stopObserve()
    }

    private func startObserve() {
        notificationCenter.addObserver(
            self,
            selector: #selector(screenIsLocked(_:)),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(screenIsUnlocked(_:)),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    private func stopObserve() {
        notificationCenter.removeObserver(self)
    }

    @objc
    private func screenIsLocked(_ notification: Notification) {
        DispatchQueue.main.async {
            self.delegate?.screenIsLocked()
        }
    }

    @objc
    private func screenIsUnlocked(_ notification: Notification) {
        DispatchQueue.main.async {
            self.delegate?.screenIsUnlocked()
        }
    }
}
