import CoreImage
import XCTest
@testable import mobile_scanner

final class CapturedImageRotationTests: XCTestCase {
    func testCorrectionAccountsForExistingBufferRotationAndMirroring() {
        for capture in stride(from: 0, through: 270, by: 90) {
            for buffer in stride(from: 0, through: 270, by: 90) {
                for mirrored in [false, true] {
                    let correction = CapturedImageRotation.correction(
                        captureAngle: CGFloat(capture), bufferAngle: CGFloat(buffer), mirrored: mirrored)
                    let applied = mirrored ? -correction : correction
                    XCTAssertEqual((CGFloat(buffer) + applied + 360)
                        .truncatingRemainder(dividingBy: 360), CGFloat(capture))
                }
            }
        }
    }

    func testRotationPreservesPixelsAndSwapsDimensionsOnlyForQuarterTurns() throws {
        // An asymmetric image verifies actual pixel rotation, including 180°,
        // rather than relying on dimensions or JPEG orientation metadata.
        let pixels: [UInt8] = [
            255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
            0, 255, 255, 255, 255, 0, 255, 255, 255, 255, 0, 255,
        ]
        let image = try XCTUnwrap(CGImage(width: 3, height: 2, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: 12, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(pixels) as CFData)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent))
        let expected = [0: [0, 1, 2, 3, 4, 5], 90: [3, 0, 4, 1, 5, 2],
                        180: [5, 4, 3, 2, 1, 0], 270: [2, 5, 1, 4, 0, 3]]
        for angle in [0, 90, 180, 270, -90] {
            let rotated = try XCTUnwrap(CapturedImageRotation.rotate(image, clockwiseDegrees: CGFloat(angle)))
            XCTAssertEqual(rotated.width, angle % 180 == 0 ? 3 : 2)
            XCTAssertEqual(rotated.height, angle % 180 == 0 ? 2 : 3)
            var output = [UInt8](repeating: 0, count: pixels.count)
            let context = try XCTUnwrap(CGContext(data: &output, width: rotated.width, height: rotated.height,
                bitsPerComponent: 8, bytesPerRow: rotated.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(rotated, in: CGRect(x: 0, y: 0, width: rotated.width, height: rotated.height))
            for (index, sourceIndex) in expected[(angle + 360) % 360]!.enumerated() {
                for channel in 0..<4 {
                    XCTAssertEqual(output[index * 4 + channel], pixels[sourceIndex * 4 + channel])
                }
            }
        }
        XCTAssertEqual(image.width, 3)
        XCTAssertEqual(image.height, 2)
    }
}
