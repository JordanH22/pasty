import Cocoa

func createSquircleImage(inputPath: String, outputPath: String, cornerRadiusRatio: CGFloat = 0.225) {
    guard let image = NSImage(contentsOfFile: inputPath) else {
        print("Could not load image at \(inputPath)")
        return
    }
    
    let size = image.size
    let outImage = NSImage(size: size)
    
    outImage.lockFocus()
    let rect = NSRect(origin: .zero, size: size)
    
    let radius = min(size.width, size.height) * cornerRadiusRatio
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()
    
    image.draw(in: rect)
    outImage.unlockFocus()
    
    guard let cgImage = outImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    let bitRep = NSBitmapImageRep(cgImage: cgImage)
    
    // Save to PNG
    guard let pngData = bitRep.representation(using: .png, properties: [:]) else { return }
    try? pngData.write(to: URL(fileURLWithPath: outputPath))
    
    print("Successfully created rounded logo at \(outputPath)")
}

let input = CommandLine.arguments.dropFirst().first ?? "website/assets/images/logo.png"
let output = "website/assets/images/logo_round.png"

createSquircleImage(inputPath: input, outputPath: output)
