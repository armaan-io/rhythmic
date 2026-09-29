import SwiftUI
import UIKit

struct PadContact {
    let eventTime: Double
    let receivedTime: Double
}

struct TouchPad: UIViewRepresentable {
    var enabled: Bool
    var hapticsEnabled: Bool = false
    var onContacts: ([PadContact]) -> Bool

    func makeUIView(context: Context) -> ContactView { ContactView() }
    func updateUIView(_ view: ContactView, context: Context) {
        view.onContacts = onContacts
        view.hapticsEnabled = hapticsEnabled
        view.isUserInteractionEnabled = enabled
        view.alpha = enabled ? 1 : 0.45
    }

    final class ContactView: UIView {
        var onContacts: (([PadContact]) -> Bool)?
        var hapticsEnabled = false
        private let label = UILabel()
        private lazy var impact = UIImpactFeedbackGenerator(style: .light)
        private var flashReset: DispatchWorkItem?

        init() {
            super.init(frame: .zero)
            isMultipleTouchEnabled = true
            backgroundColor = UIColor(AppTheme.surface)
            layer.cornerRadius = 20
            layer.cornerCurve = .continuous
            layer.borderWidth = 1
            layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).withAlphaComponent(0.25).cgColor
            label.text = "Tap anywhere"
            label.font = .preferredFont(forTextStyle: .callout)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.textAlignment = .center
            label.isUserInteractionEnabled = false
            addSubview(label)
            isAccessibilityElement = true
            accessibilityLabel = "Rhythm pad"
            accessibilityHint = "Tap anywhere to play the rhythm. Each new finger touch plays a hit during practice."
            accessibilityTraits = [.allowsDirectInteraction]
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).withAlphaComponent(0.25).cgColor
        }
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
            label.frame = bounds.insetBy(dx: 16, dy: 12)
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            // One timestamp per physical contact, including simultaneous and overlapping fingers.
            // No gesture recognizer, release gate, coalescing, or move/release-generated taps.
            let received = ProcessInfo.processInfo.systemUptime
            let contacts = touches.map { PadContact(eventTime: $0.timestamp, receivedTime: received) }
            if onContacts?(contacts) == true {
                // Feedback follows timestamp recording and the audio callback.
                if hapticsEnabled { impact.impactOccurred() }
                flashReset?.cancel()
                layer.removeAllAnimations()
                backgroundColor = .tertiarySystemFill
                if UIAccessibility.isReduceMotionEnabled {
                    let reset = DispatchWorkItem { [weak self] in
                        self?.backgroundColor = UIColor(AppTheme.surface)
                    }
                    flashReset = reset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: reset)
                } else {
                    UIView.animate(withDuration: 0.10, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                        self.backgroundColor = UIColor(AppTheme.surface)
                    }, completion: nil)
                }
            }
        }
    }
}
