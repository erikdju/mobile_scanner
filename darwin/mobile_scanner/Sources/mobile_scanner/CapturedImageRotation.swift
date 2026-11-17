import CoreImage

/// Rotates only the image being encoded, leaving the shared camera buffer alone.
enum CapturedImageRotation {
    static func correction(captureAngle: CGFloat, bufferAngle: CGFloat, mirrored: Bool) -> CGFloat {
        let angle = (captureAngle - bufferAngle).truncatingRemainder(dividingBy: 360)
        return mirrored ? -angle : angle
    }

    static func rotate(_ image: CGImage, clockwiseDegrees: CGFloat) -> CGImage? {
        let angle = (clockwiseDegrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let source = CIImage(cgImage: image)
        let rotated: CIImage
        switch angle {
        case 0: return image
        case 90: rotated = source.oriented(.right)
        case 180: rotated = source.oriented(.down)
        case 270: rotated = source.oriented(.left)
        default: rotated = source.transformed(by: CGAffineTransform(rotationAngle: -angle * .pi / 180))
        }
        return CIContext().createCGImage(rotated, from: rotated.extent)
    }
}
