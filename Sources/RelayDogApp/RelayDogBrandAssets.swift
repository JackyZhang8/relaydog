import AppKit

public enum RelayDogBrandAssets {
    private static let resourceBundleName = "RelayDog_RelayDogApp.bundle"

    static func resourceBundleURL(
        mainBundleURL: URL = Bundle.main.bundleURL,
        mainResourceURL: URL? = Bundle.main.resourceURL,
        fileManager: FileManager = .default
    ) -> URL? {
        let candidates = [
            mainResourceURL?.appendingPathComponent(resourceBundleName, isDirectory: true),
            mainBundleURL
                .appendingPathComponent("Contents/Resources", isDirectory: true)
                .appendingPathComponent(resourceBundleName, isDirectory: true),
            mainBundleURL.appendingPathComponent(resourceBundleName, isDirectory: true)
        ]

        for candidate in candidates.compactMap({ $0 }) {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
        }

        return nil
    }

    private static var resourceBundle: Bundle? {
        if let url = resourceBundleURL(), let bundle = Bundle(url: url) {
            return bundle
        }

        if Bundle.main.bundleURL.pathExtension == "app" {
            return nil
        }

        return Bundle.module
    }

    public static var logoImage: NSImage? {
        resourceBundle?.image(forResource: "relaydog-logo")
    }

    public static func cornerAlpha() -> UInt8? {
        guard let image = logoImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let alphaInfo = cgImage.alphaInfo
        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
        let byteOrder = cgImage.bitmapInfo.intersection(.byteOrderMask)

        switch alphaInfo {
        case .premultipliedFirst, .first:
            return bytes[0]
        case .premultipliedLast, .last:
            return bytes[bytesPerPixel - 1]
        case .noneSkipFirst:
            return 255
        case .noneSkipLast, .none, .alphaOnly:
            return alphaInfo == .alphaOnly ? bytes[0] : 255
        @unknown default:
            if byteOrder == .byteOrder32Little {
                return bytes[3]
            }
            return bytes[0]
        }
    }
}
