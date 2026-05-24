//
//  LoopPlayer.swift
//  Brooklyn
//
//  Created by Pedro Carrasco on 23/02/2019.
//  Copyright © 2019 Pedro Carrasco. All rights reserved.
//

import AVFoundation

// MARK: - LoopPlayer
final class LoopPlayer: AVQueuePlayer {

    // Tracks ObjectIdentifiers of items that belong to this player instance,
    // so we can filter out AVPlayerItemDidPlayToEndTime notifications from other
    // LoopPlayer instances (e.g. screensaver preview + main display, multi-monitor).
    // Only mutated on the main queue — see playerItemDidFinish for the dispatch hop.
    private var managedItemIDs: Set<ObjectIdentifier> = []

    // Source state, kept so `start()` can rebuild the queue after `stop()` drained it.
    private var sourceAnimations: [Animation] = []
    private var sourceNumberOfLoops: Int = 0
    private var sourceShouldRandomize: Bool = false

    // MARK: Lifecycle
    init(items: [Animation], numberOfLoops: Int, shouldRandomize: Bool) {
        self.sourceAnimations = items
        self.sourceNumberOfLoops = numberOfLoops
        self.sourceShouldRandomize = shouldRandomize

        let avItems = LoopPlayer.buildItems(from: items,
                                            numberOfLoops: numberOfLoops,
                                            shouldRandomize: shouldRandomize)
        super.init(items: avItems)
        avItems.forEach { managedItemIDs.insert(ObjectIdentifier($0)) }
        observe()
    }

    override init() {
        super.init()
    }

    deinit {
        unobserve()
    }
}

// MARK: - Actions
extension LoopPlayer {

    /// Repopulates the queue from the saved source animations if it has been
    /// drained by `stop()`. No-op when the queue still has items, so the first
    /// `startAnimation()` after init doesn't double up.
    func start() {
        guard items().isEmpty else { return }
        let avItems = LoopPlayer.buildItems(from: sourceAnimations,
                                            numberOfLoops: sourceNumberOfLoops,
                                            shouldRandomize: sourceShouldRandomize)
        avItems.forEach {
            managedItemIDs.insert(ObjectIdentifier($0))
            insert($0, after: items().last)
        }
    }

    func stop() {
        managedItemIDs.removeAll()
        removeAllItems()
    }

    func play(_ animation: Animation) {
        guard let item = AVPlayerItem(video: animation, extension: .mp4, for: LoopPlayer.self) else { return }
        actionAtItemEnd = .none
        stop()
        [item].prepareForQueue().forEach {
            managedItemIDs.insert(ObjectIdentifier($0))
            insert($0, after: items().last)
        }
        actionAtItemEnd = .advance
    }
}

// MARK: - Queue building
private extension LoopPlayer {

    static func buildItems(from animations: [Animation],
                           numberOfLoops: Int,
                           shouldRandomize: Bool) -> [AVPlayerItem] {
        return (shouldRandomize ? animations.shuffled() : animations)
            .reduce(into: [AVPlayerItem]()) {
                guard let item = AVPlayerItem(video: $1, extension: .mp4, for: LoopPlayer.self) else { return }
                $0.append(contentsOf: Array(copy: item, count: numberOfLoops))
            }
            .prepareForQueue()
    }
}

// MARK: - Observers
private extension LoopPlayer {

    func observe() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidFinish),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }

    func unobserve() {
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                  object: nil)
    }

    @objc
    func playerItemDidFinish(_ notification: Notification) {
        // AVFoundation posts this notification on an internal queue. Hop to main so
        // `managedItemIDs` is only ever read/mutated from one thread (the same one
        // `play(_:)` / `stop()` run on).
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let finishedItem = notification.object as? AVPlayerItem,
                  self.managedItemIDs.contains(ObjectIdentifier(finishedItem)) else { return }
            self.managedItemIDs.remove(ObjectIdentifier(finishedItem))
            // Copy the item that actually finished, not `currentItem` (which is the
            // next item already playing). This keeps multi-animation queues cycling
            // through their inputs instead of biasing toward the last one, and avoids
            // freezing when the queue empties.
            guard let itemCopy = finishedItem.copy() as? AVPlayerItem else { return }
            self.managedItemIDs.insert(ObjectIdentifier(itemCopy))
            self.insert(itemCopy, after: self.items().last)
        }
    }
}

// MARK: - AVPlayerItems' Utils
fileprivate extension Array where Element: AVPlayerItem {
    
    func prepareForQueue() -> [AVPlayerItem] {
        if count == 1, let itemCopy = first?.copy() as? AVPlayerItem {
            return self + [itemCopy]
        }
        
        return self
    }
    
    init(copy item: Element, count: Int) {
        let elements = [Int](0...count).compactMap { _ in return item.copy() as? Element }
        self.init(elements)
    }
}
