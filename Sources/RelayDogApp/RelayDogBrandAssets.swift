import AppKit

public enum RelayDogBrandAssets {
    public static var logoImage: NSImage? {
        Bundle.module.image(forResource: "relaydog-logo")
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
