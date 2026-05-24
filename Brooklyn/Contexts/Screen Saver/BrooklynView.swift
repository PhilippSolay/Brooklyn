//
//  BrooklynView.swift
//  Brooklyn
//
//  Created by Pedro Carrasco on 30/10/2018.
//  Copyright © 2018 Pedro Carrasco. All rights reserved.
//

import Foundation
import ScreenSaver
import AVKit

// MARK: - BrooklynView
final class BrooklynView: ScreenSaverView {

    // MARK: Local Typealias
    typealias Static = BrooklynView
    
    // MARK: Constant
    private enum Constant {
        static let backgroundColor = NSColor(red: 0.00, green: 0.01, blue: 0.00, alpha:1.0)
    }
    
    // MARK: Outlets
    private let videoLayer = AVPlayerLayer()
    
    // MARK: Properties
    private let manager = BrooklynManager(mode: .screensaver)
    private lazy var preferences = PreferencesWindowController(windowNibName: PreferencesWindowController.identifier)

    // MARK: Initialization
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        configure()
    }

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        configure()
    }
}

// MARK: - Lifecycle
extension BrooklynView {
    
    override func startAnimation() {
        super.startAnimation()
        videoLayer.player = manager.player
        manager.player.start()
        manager.player.play()
    }

    override func stopAnimation() {
        super.stopAnimation()
        // Just pause here — `stopAnimation` is called every time the screensaver
        // is dismissed (e.g. mouse wiggle), and dropping the queue would force a
        // full rebuild on every re-activation. Real teardown happens below in
        // viewWillMove(toWindow:) when the window goes nil.
        manager.player.pause()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        // newWindow == nil means the view is being removed from the window
        // hierarchy — the actual teardown signal. Drain the queue and drop the
        // layer's player reference so VTDecoderXPCService can release.
        guard newWindow == nil else { return }
        manager.player.pause()
        manager.player.stop()
        videoLayer.player = nil
    }

    // videoLayer is assigned as the view's main layer (layer = videoLayer in
    // defineLayer). autoresizingMask only applies to sublayers, not the main
    // layer, so the layer's frame doesn't follow the view automatically.
    // Without this, the preview pane on macOS 14+ ends up rendering to a 0x0
    // surface (frames decode but displayed: 0). Sync the layer to bounds on
    // every layout pass.
    override func layout() {
        super.layout()
        videoLayer.frame = bounds
    }
}

// MARK: - Configuration
private extension BrooklynView {
    
    func configure() {
        defineLayer()
        setupLayer()
    }
    
    func defineLayer() {
        wantsLayer = true
        defineVideoLayer()
        layer = videoLayer
    }
    
    func setupLayer() {
        videoLayer.player = manager.player
    }
}

// MARK: - Define Layers
private extension BrooklynView {

    func defineVideoLayer() {
        videoLayer.frame = bounds
        videoLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        videoLayer.needsDisplayOnBoundsChange = true
        videoLayer.contentsGravity = .resizeAspect
        videoLayer.backgroundColor = Constant.backgroundColor.cgColor
    }
}

// MARK: - Preferences
extension BrooklynView {

    override var hasConfigureSheet: Bool {
        return true
    }

    override var configureSheet: NSWindow? {
        return preferences.window
    }
}
