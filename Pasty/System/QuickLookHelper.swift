import SwiftUI
import AVKit

/// Custom NSView that keeps AVPlayerLayer frame in sync with its bounds.
/// Custom NSView that keeps AVPlayerLayer frame in sync with its bounds.
class PlayerContainerView: NSView {
    let playerLayer = AVPlayerLayer()
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        playerLayer.cornerRadius = 6
        layer?.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layout() {
        super.layout()
        // Keep player layer frame in sync with view bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

/// Native inline video player using AVPlayerLayer.
/// Hardware-accelerated Metal decoding — minimal RAM, zero copies.
struct InlineVideoPlayer: NSViewRepresentable {
    let fileURLString: String
    
    func makeNSView(context: Context) -> PlayerContainerView {
        let container = PlayerContainerView()
        
        let url: URL
        if fileURLString.hasPrefix("file://") {
            url = URL(string: fileURLString) ?? URL(fileURLWithPath: fileURLString.replacingOccurrences(of: "file://", with: ""))
        } else {
            url = URL(fileURLWithPath: fileURLString)
        }
        
        let player = AVPlayer(url: url)
        container.playerLayer.player = player
        context.coordinator.player = player
        
        player.play()
        return container
    }
    
    func updateNSView(_ nsView: PlayerContainerView, context: Context) {}
    
    static func dismantleNSView(_ nsView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.player = nil
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator: NSObject, @unchecked Sendable {
        var player: AVPlayer?
    }
}
