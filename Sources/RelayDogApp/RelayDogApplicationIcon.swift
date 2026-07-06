import AppKit

public enum RelayDogApplicationIcon {
    public static func install(setIcon: (NSImage?) -> Void) {
        setIcon(RelayDogBrandAssets.logoImage)
    }

    @MainActor
    public static func install() {
        install { image in
            NSApplication.shared.applicationIconImage = image
        }
    }
}
