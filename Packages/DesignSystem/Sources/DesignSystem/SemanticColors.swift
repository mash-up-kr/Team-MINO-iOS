import SwiftUI

fileprivate extension Color {
    init(semantic name: String) { self.init(name, bundle: .module) }
}

public extension ShapeStyle where Self == Color {
    /// Figma `Label/Strong`
    static var mhLabelStrong: Color { Color(semantic: "Label/Strong") }
    /// Figma `Label/Normal`
    static var mhLabelNormal: Color { Color(semantic: "Label/Normal") }
    /// Figma `Label/Neutral`
    static var mhLabelNeutral: Color { Color(semantic: "Label/Neutral") }
    /// Figma `Label/Alternative`
    static var mhLabelAlternative: Color { Color(semantic: "Label/Alternative") }
    /// Figma `Label/Assistive`
    static var mhLabelAssistive: Color { Color(semantic: "Label/Assistive") }
    /// Figma `Label/Disable`
    static var mhLabelDisable: Color { Color(semantic: "Label/Disable") }
    /// Figma `Primary/Normal`
    static var mhPrimaryNormal: Color { Color(semantic: "Primary/Normal") }
    /// Figma `Primary/Strong`
    static var mhPrimaryStrong: Color { Color(semantic: "Primary/Strong") }
    /// Figma `Primary/Heavy`
    static var mhPrimaryHeavy: Color { Color(semantic: "Primary/Heavy") }
    /// Figma `Background/Normal/Normal`
    static var mhBackgroundNormalNormal: Color { Color(semantic: "Background/Normal/Normal") }
    /// Figma `Background/Normal/Alternative`
    static var mhBackgroundNormalAlternative: Color { Color(semantic: "Background/Normal/Alternative") }
    /// Figma `Background/Elevated/Normal`
    static var mhBackgroundElevatedNormal: Color { Color(semantic: "Background/Elevated/Normal") }
    /// Figma `Background/Elevated/Alternative`
    static var mhBackgroundElevatedAlternative: Color { Color(semantic: "Background/Elevated/Alternative") }
    /// Figma `Background/Transparent/Normal`
    static var mhBackgroundTransparentNormal: Color { Color(semantic: "Background/Transparent/Normal") }
    /// Figma `Background/Transparent/Alternative`
    static var mhBackgroundTransparentAlternative: Color { Color(semantic: "Background/Transparent/Alternative") }
    /// Figma `Interaction/Inactive`
    static var mhInteractionInactive: Color { Color(semantic: "Interaction/Inactive") }
    /// Figma `Interaction/Disable`
    static var mhInteractionDisable: Color { Color(semantic: "Interaction/Disable") }
    /// Figma `Line/Normal/Normal`
    static var mhLineNormalNormal: Color { Color(semantic: "Line/Normal/Normal") }
    /// Figma `Line/Normal/Neutral`
    static var mhLineNormalNeutral: Color { Color(semantic: "Line/Normal/Neutral") }
    /// Figma `Line/Normal/Alternative`
    static var mhLineNormalAlternative: Color { Color(semantic: "Line/Normal/Alternative") }
    /// Figma `Line/Solid/Normal`
    static var mhLineSolidNormal: Color { Color(semantic: "Line/Solid/Normal") }
    /// Figma `Line/Solid/Neutral`
    static var mhLineSolidNeutral: Color { Color(semantic: "Line/Solid/Neutral") }
    /// Figma `Line/Solid/Alternative`
    static var mhLineSolidAlternative: Color { Color(semantic: "Line/Solid/Alternative") }
    /// Figma `Status/Positive`
    static var mhStatusPositive: Color { Color(semantic: "Status/Positive") }
    /// Figma `Status/Cautionary`
    static var mhStatusCautionary: Color { Color(semantic: "Status/Cautionary") }
    /// Figma `Status/Negative`
    static var mhStatusNegative: Color { Color(semantic: "Status/Negative") }
    /// Figma `Accent/Background/Red Orange`
    static var mhAccentBackgroundRedOrange: Color { Color(semantic: "Accent/Background/Red Orange") }
    /// Figma `Accent/Background/Lime`
    static var mhAccentBackgroundLime: Color { Color(semantic: "Accent/Background/Lime") }
    /// Figma `Accent/Background/Cyan`
    static var mhAccentBackgroundCyan: Color { Color(semantic: "Accent/Background/Cyan") }
    /// Figma `Accent/Background/Light Blue`
    static var mhAccentBackgroundLightBlue: Color { Color(semantic: "Accent/Background/Light Blue") }
    /// Figma `Accent/Background/Violet`
    static var mhAccentBackgroundViolet: Color { Color(semantic: "Accent/Background/Violet") }
    /// Figma `Accent/Background/Purple`
    static var mhAccentBackgroundPurple: Color { Color(semantic: "Accent/Background/Purple") }
    /// Figma `Accent/Background/Pink`
    static var mhAccentBackgroundPink: Color { Color(semantic: "Accent/Background/Pink") }
    /// Figma `Accent/Foreground/Red`
    static var mhAccentForegroundRed: Color { Color(semantic: "Accent/Foreground/Red") }
    /// Figma `Accent/Foreground/Red Orange`
    static var mhAccentForegroundRedOrange: Color { Color(semantic: "Accent/Foreground/Red Orange") }
    /// Figma `Accent/Foreground/Orange`
    static var mhAccentForegroundOrange: Color { Color(semantic: "Accent/Foreground/Orange") }
    /// Figma `Accent/Foreground/Lime`
    static var mhAccentForegroundLime: Color { Color(semantic: "Accent/Foreground/Lime") }
    /// Figma `Accent/Foreground/Green`
    static var mhAccentForegroundGreen: Color { Color(semantic: "Accent/Foreground/Green") }
    /// Figma `Accent/Foreground/Cyan`
    static var mhAccentForegroundCyan: Color { Color(semantic: "Accent/Foreground/Cyan") }
    /// Figma `Accent/Foreground/Light Blue`
    static var mhAccentForegroundLightBlue: Color { Color(semantic: "Accent/Foreground/Light Blue") }
    /// Figma `Accent/Foreground/Blue`
    static var mhAccentForegroundBlue: Color { Color(semantic: "Accent/Foreground/Blue") }
    /// Figma `Accent/Foreground/Violet`
    static var mhAccentForegroundViolet: Color { Color(semantic: "Accent/Foreground/Violet") }
    /// Figma `Accent/Foreground/Purple`
    static var mhAccentForegroundPurple: Color { Color(semantic: "Accent/Foreground/Purple") }
    /// Figma `Accent/Foreground/Pink`
    static var mhAccentForegroundPink: Color { Color(semantic: "Accent/Foreground/Pink") }
    /// Figma `Inverse/Primary`
    static var mhInversePrimary: Color { Color(semantic: "Inverse/Primary") }
    /// Figma `Inverse/Background`
    static var mhInverseBackground: Color { Color(semantic: "Inverse/Background") }
    /// Figma `Inverse/Label`
    static var mhInverseLabel: Color { Color(semantic: "Inverse/Label") }
    /// Figma `Static/White`
    static var mhStaticWhite: Color { Color(semantic: "Static/White") }
    /// Figma `Static/Black`
    static var mhStaticBlack: Color { Color(semantic: "Static/Black") }
    /// Figma `Fill/Normal`
    static var mhFillNormal: Color { Color(semantic: "Fill/Normal") }
    /// Figma `Fill/Strong`
    static var mhFillStrong: Color { Color(semantic: "Fill/Strong") }
    /// Figma `Fill/Alternative`
    static var mhFillAlternative: Color { Color(semantic: "Fill/Alternative") }
    /// Figma `Material/Dimmer`
    static var mhMaterialDimmer: Color { Color(semantic: "Material/Dimmer") }
}

enum SemanticColorBundle {
    static var current: Bundle { .module }
}
