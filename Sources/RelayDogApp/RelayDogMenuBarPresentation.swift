import AppKit

public enum RelayDogMenuBarPresentation {
    public static let title = "RelayDog"
    public static let statusItemTitle = ""
    public static let statusItemShowsTitle = false
    public static let statusItemIconSize = NSSize(width: 18, height: 18)
    public static let statusItemIconSourceInset: CGFloat = 96
    public static let statusItemIconCornerRadiusRatio: CGFloat = 0.22
    public static let statusItemIconRemovesLightEdge = true
    public static let fallbackSystemImage = "pawprint.fill"

    public static var iconImage: NSImage? {
        guard let logoImage = RelayDogBrandAssets.logoImage else {
            return nil
        }
        return croppedStatusIcon(from: logoImage) ?? logoImage
    }

    private static func croppedStatusIcon(from image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let inset = min(
            Int(statusItemIconSourceInset),
            max(0, min(cgImage.width, cgImage.height) / 2 - 1)
        )
        let cropRect = CGRect(
            x: inset,
            y: inset,
            width: cgImage.width - inset * 2,
            height: cgImage.height - inset * 2
        )
        guard let croppedImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        let roundedImage = roundedStatusIcon(from: croppedImage) ?? croppedImage
        return NSImage(
            cgImage: roundedImage,
            size: NSSize(width: roundedImage.width, height: roundedImage.height)
        )
    }

    private static func roundedStatusIcon(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let radius = min(CGFloat(width), CGFloat(height)) * statusItemIconCornerRadiusRatio
        context.clear(rect)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        context.draw(image, in: rect)
        return context.makeImage()
    }
}
