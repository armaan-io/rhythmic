import SwiftUI
import UIKit

struct PadContact {
    let eventTime: Double
    let receivedTime: Double
}

struct TouchPad: UIViewRepresentable {
    var enabled: Bool
    var onContacts: ([PadContact]) -> Bool

    func makeUIView(context: Context) -> ContactView { ContactView() }
    func updateUIView(_ view: ContactView, context: Context) {
        view.onContacts = onContacts
        view.isUserInteractionEnabled = enabled
        view.alpha = enabled ? 1 : 0.45
    }

    final class ContactView: UIView {
        var onContacts: (([PadContact]) -> Bool)?
        private let label = UILabel()

        init() {
            super.init(frame: .zero)
            isMultipleTouchEnabled = true
            backgroundColor = .secondarySystemFill
            layer.cornerRadius = 24
            label.text = "Tap pad"
            label.font = .preferredFont(forTextStyle: .largeTitle)
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            addSubview(label)
            isAccessibilityElement = true
            accessibilityLabel = "Timing pad"
            accessibilityHint = "Each new finger contact records a raw timestamp during the run."
            accessibilityTraits = [.allowsDirectInteraction]
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    // Immediate UIKit delivery; dragging a held pad contact must not
                    // turn into scrolling or cancel the other independent contacts.
                    scrollView.delaysContentTouches = false
                    scrollView.canCancelContentTouches = false
                }
                ancestor = view.superview
            }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            label.frame = bounds
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            // One timestamp per physical contact, including simultaneous and overlapping fingers.
            // No gesture recognizer, release gate, coalescing, or move/release-generated taps.
            let received = ProcessInfo.processInfo.systemUptime
            let contacts = touches.map { PadContact(eventTime: $0.timestamp, receivedTime: received) }
            if onContacts?(contacts) == true {
                layer.removeAllAnimations()
                backgroundColor = .tertiarySystemFill
                UIView.animate(withDuration: 0.10, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                    self.backgroundColor = .secondarySystemFill
                }, completion: nil)
            }
        }
    }
}
