import AppKit
import QuartzCore
import SwiftUI

/// A view that applies a true variable Gaussian blur to content behind it.
/// Rather than fading opacity (which creates milkiness/fog), it smoothly decreases
/// the Gaussian blur radius from max at the top to 0 at the bottom.
struct VariableBlurView: NSViewRepresentable {
    var maxBlurRadius: CGFloat = 20

    func makeNSView(context _: Context) -> VariableBlurNSView {
        let view = VariableBlurNSView()
        view.maxBlurRadius = self.maxBlurRadius
        return view
    }

    func updateNSView(_ nsView: VariableBlurNSView, context _: Context) {
        nsView.maxBlurRadius = self.maxBlurRadius
    }
}

final class VariableBlurNSView: NSView {
    var maxBlurRadius: CGFloat = 20 {
        didSet {
            if oldValue != self.maxBlurRadius {
                self.updateBlur()
            }
        }
    }

    private var backdropLayer: CALayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.setupBackdropLayer()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        self.backdropLayer?.frame = self.bounds
    }

    private func setupBackdropLayer() {
        guard let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return }
        let layer = backdropClass.init()
        layer.name = "variableBlurBackdrop"
        layer.frame = self.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.layer?.addSublayer(layer)
        self.backdropLayer = layer
        self.updateBlur()
    }

    private func updateBlur() {
        guard let backdropLayer = self.backdropLayer else { return }
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return }
        let sel = NSSelectorFromString("filterWithName:")
        guard let filter = filterClass.perform(sel, with: "variableBlur")?.takeUnretainedValue() as? NSObject else { return }

        let maskImage = Self.makeGradientMask()
        filter.setValue(self.maxBlurRadius, forKey: "inputRadius")
        filter.setValue(maskImage, forKey: "inputMaskImage")
        filter.setValue(true, forKey: "inputNormalizeEdges")

        backdropLayer.filters = [filter]
    }

    private static func makeGradientMask(size: CGSize = CGSize(width: 32, height: 128)) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        // In CGContext, (0,0) is bottom.
        // We want max blur (1.0 = white) at the top and 0 blur (0.0 = black) at the bottom.
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: [1.0, 0.0],
            locations: [0.0, 1.0],
            count: 2
        ) else { return nil }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size.height),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
        return context.makeImage()
    }
}

struct WithinWindowBlurView: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.state = .active
        view.material = .sidebar
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}

