import SwiftUI

/// A system font at a fixed design-token point size that also scales with the
/// user's accessibility text-size setting (Dynamic Type).
///
/// macOS has no global Dynamic Type slider the way iOS does, so this is mainly
/// future-proofing: text scales when the `dynamicTypeSize` environment is driven
/// (e.g. a future in-app text-size control) and otherwise stays at the design size.
private struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    /// Drop-in replacement for `.font(.system(size:weight:))` that scales with Dynamic Type.
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight, relativeTo: textStyle))
    }
}
