import SwiftUI
import CoreText

enum IPAMotion {
    static func press(_ pressed: Bool, reduced: Bool) -> Animation {
        .easeOut(duration: reduced ? 0.1 : pressed ? 0.08 : 0.14)
    }
    static func state(reduced: Bool) -> Animation {
        .easeOut(duration: reduced ? 0.1 : 0.18)
    }
    static func reveal(reduced: Bool) -> AnyTransition {
        .opacity
    }
}

struct IPAPillStyle: ButtonStyle {
    var prominent = false
    @AppStorage("IPAAccentHex") private var accentHex = "systemBlue"
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.ipaFont(.subheadline, weight: .bold)
            .lineLimit(1).fixedSize(horizontal: true, vertical: true)
            .foregroundStyle(prominent ? IPAAppearance.buttonForeground(accentHex) : IPAAppearance.accent(accentHex))
            .padding(.horizontal, 18).frame(minWidth: 66, minHeight: 34)
            .background(prominent ? IPAAppearance.accent(accentHex) : Color(uiColor: scheme == .dark ? .tertiarySystemFill : .secondarySystemFill), in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.82 : 1) : 0.5)
            .animation(IPAMotion.press(configuration.isPressed, reduced: reduceMotion), value: configuration.isPressed)
    }
}

private struct IPAAccentKey: EnvironmentKey { static let defaultValue = Color(uiColor: .systemBlue) }
extension EnvironmentValues {
    var ipaAccent: Color { get { self[IPAAccentKey.self] } set { self[IPAAccentKey.self] = newValue } }
}

enum IPAAppearance {
    static func accent(_ hex: String) -> Color {
        // Migrate the previous default to Apple's adaptive native blue. Custom
        // colors remain literal values; the default follows appearance/contrast.
        if hex == "systemBlue" || hex.uppercased() == "007AFF" { return Color(uiColor: .systemBlue) }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return Color(uiColor: .systemBlue) }
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    static func buttonForeground(_ hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else { return .white }
        let luminance = (Double((value >> 16) & 255) * 0.2126 + Double((value >> 8) & 255) * 0.7152 + Double(value & 255) * 0.0722) / 255
        return luminance > 0.68 ? .black : .white
    }
    static func hex(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    static func uiFont(size: CGFloat, style: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let choice = UserDefaults.standard.string(forKey: "IPAFontChoice") ?? "system"
        let bold = UserDefaults.standard.bool(forKey: "IPABoldText")
        var base = UIFont.systemFont(ofSize: size, weight: bold ? .bold : weight)
        if choice == "pixel", let pixel = UIFont(name: "Monocraft", size: size) { base = pixel }
        else if choice != "system" {
            let design: UIFontDescriptor.SystemDesign = choice == "rounded" ? .rounded : choice == "serif" ? .serif : .monospaced
            if let descriptor = base.fontDescriptor.withDesign(design) { base = UIFont(descriptor: descriptor, size: size) }
        }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
    private static let registration: Void = {
        guard let url = Bundle.main.url(forResource: "Monocraft", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()
    static func registerFonts() { _ = registration }
}

struct IPATheme: ViewModifier {
    @AppStorage("IPAAccentHex") private var hex = "systemBlue"
    @AppStorage("IPAFontChoice") private var font = "system"
    @AppStorage("IPABoldText") private var bold = false
    func body(content: Content) -> some View {
        content.tint(IPAAppearance.accent(hex)).accentColor(IPAAppearance.accent(hex))
            .environment(\.ipaAccent, IPAAppearance.accent(hex))
            .fontWeight(bold ? .bold : nil)
            .fontDesign(font == "rounded" ? .rounded : font == "serif" ? .serif : font == "mono" || font == "pixel" ? .monospaced : .default)
            .task { IPAAppearance.registerFonts() }
            .onAppear { applyWindowTint(hex) }
            .onChange(of: hex) { _, value in
                applyWindowTint(value)
            }
    }
    private func applyWindowTint(_ value: String) {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows { window.tintColor = UIColor(IPAAppearance.accent(value)) }
        }
    }
}
private struct IPAFontModifier: ViewModifier {
    let style: Font.TextStyle
    let weight: Font.Weight
    @AppStorage("IPAFontChoice") private var choice = "system"
    @AppStorage("IPABoldText") private var bold = false
    private var font: Font {
        let sizes: [Font.TextStyle: CGFloat] = [.largeTitle: 34, .title: 28, .title2: 22, .title3: 20, .headline: 17, .body: 17, .callout: 16, .subheadline: 15, .footnote: 13, .caption: 12, .caption2: 11]
        if choice == "pixel" { return .custom("Monocraft", size: sizes[style] ?? 17, relativeTo: style).weight(bold ? .bold : weight) }
        let design: Font.Design = choice == "rounded" ? .rounded : choice == "serif" ? .serif : choice == "mono" ? .monospaced : .default
        return .system(style, design: design).weight(bold ? .bold : weight)
    }
    func body(content: Content) -> some View { content.font(font) }
}
extension View {
    func ipaFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View { modifier(IPAFontModifier(style: style, weight: weight)) }
}

struct IPAAppearanceView: View {
    @AppStorage("IPASoundsEnabled") private var sounds = true
    @AppStorage("IPAHapticsEnabled") private var haptics = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("IPAAppearance") private var mode = "system"
    @AppStorage("IPAAccentHex") private var hex = "systemBlue"
    @AppStorage("IPAFontChoice") private var font = "system"
    @AppStorage("IPABoldText") private var bold = false
    var body: some View {
        Form {
            Section("Preview") {
                HStack(spacing: 14) {
                    IPABrandGlyph(size: 44)
                    VStack(alignment: .leading, spacing: 4) { Text("Make it yours.").ipaFont(.headline, weight: .semibold); Text("Your apps, your style.").ipaFont(.subheadline).foregroundStyle(.secondary) }
                    Spacer(minLength: 4)
                    Text("Open").ipaFont(.subheadline, weight: .bold).foregroundStyle(.tint).padding(.horizontal, 14).padding(.vertical, 8).background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                }.padding(.vertical, 8)
            }
            Section("Display") {
                Picker("Appearance", selection: $mode) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                ColorPicker("Accent Color", selection: Binding(get: { IPAAppearance.accent(hex) }, set: { hex = IPAAppearance.hex($0) }), supportsOpacity: false)
                HStack {
                    ForEach(["systemBlue", "AF52DE", "FFCC00", "FF2D55", "34C759", "FF9500"], id: \.self) { value in
                        Button { hex = value } label: {
                            Circle().fill(IPAAppearance.accent(value)).frame(width: 32, height: 32)
                                .overlay { if (hex == value || (value == "systemBlue" && hex.uppercased() == "007AFF")) { Image(systemName: "checkmark").foregroundStyle(value == "FFCC00" ? .black : .white).font(.caption.bold()).transition(IPAMotion.reveal(reduced: reduceMotion)) } }.frame(maxWidth: .infinity, minHeight: 44)
                                .animation(IPAMotion.state(reduced: reduceMotion), value: hex)
                        }.buttonStyle(IPAControlPressStyle()).accessibilityLabel(["systemBlue": "Blue", "AF52DE": "Purple", "FFCC00": "Yellow", "FF2D55": "Pink", "34C759": "Green", "FF9500": "Orange"][value] ?? value).accessibilityAddTraits((hex == value || (value == "systemBlue" && hex.uppercased() == "007AFF")) ? .isSelected : [])
                    }
                }
            }
            Section {
                Picker("Font", selection: $font) { Text("System").tag("system"); Text("Rounded").tag("rounded"); Text("Serif").tag("serif"); Text("Monospaced").tag("mono"); Text("Pixel · Monocraft").tag("pixel") }
                Toggle("Bold Text", isOn: $bold)
            } header: { Text("Typography") } footer: { Text("Monocraft is an openly licensed pixel font. System controls, keyboards and installed apps keep their own typography. Text continues to follow your iPhone’s text-size setting.") }
            Section { NavigationLink { IPAIconPicker() } label: { Label("App Icon", systemImage: "app") } } header: { Text("Home Screen") } footer: { Text("Choose an included icon. Your iPhone also controls Home Screen dark and tinted appearances.") }
            Section("Sounds & Haptics") {
                Toggle("Success Sounds", isOn: $sounds)
                Toggle("Haptic Feedback", isOn: $haptics)
                Button("Preview App Opening") { IPAFeedback.appWillOpen() }
                Button("Preview Success") { IPAFeedback.success() }
            }
            Section { Button("Reset Appearance") { mode = "system"; hex = "systemBlue"; font = "system"; bold = false } }
        }.navigationTitle("Appearance").navigationBarTitleDisplayMode(.inline).ipaNativePage()
            .modifier(IPATheme())
            .preferredColorScheme(mode == "light" ? .light : mode == "dark" ? .dark : nil)
    }
}

private struct IPAIconPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var current = UIApplication.shared.alternateIconName
    @State private var changing = false
    @State private var error: String?
    private let choices: [(String, String?, String)] = [("Automatic", nil, "IconPreviewDefault"), ("Light", "AppIconLight", "IconPreviewLight"), ("Midnight", "AppIconMidnight", "IconPreviewMidnight")]
    var body: some View {
        List {
            ForEach(choices, id: \.0) { name, icon, asset in
                Button {
                    changing = true
                    UIApplication.shared.setAlternateIconName(icon) { failure in
                        DispatchQueue.main.async { changing = false; current = UIApplication.shared.alternateIconName; if failure != nil { error = "The icon couldn’t be changed. Try again while iPAStore is open." } }
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(asset).resizable().scaledToFit().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14))
                        Text(name).foregroundStyle(.primary)
                        Spacer()
                        if current == icon { Image(systemName: "checkmark").foregroundStyle(.tint).transition(IPAMotion.reveal(reduced: reduceMotion)) }
                    }.padding(.vertical, 6).animation(IPAMotion.state(reduced: reduceMotion), value: current)
                }.buttonStyle(IPAControlPressStyle(scale: 0.985)).disabled(changing || !UIApplication.shared.supportsAlternateIcons)
            }
            if !UIApplication.shared.supportsAlternateIcons { Text("Alternate icons aren’t available in this build or on this device.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("App Icon").navigationBarTitleDisplayMode(.inline).ipaNativePage()
            .alert("App Icon", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}


struct IPAControlPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
            .animation(IPAMotion.press(configuration.isPressed, reduced: reduceMotion), value: configuration.isPressed)
    }
}
