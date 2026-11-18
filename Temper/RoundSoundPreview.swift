import AVFAudio

/// Plays a Round Sound once on Settings' Round Sound screen, so the owner hears what they pick. Like the Cues, it mixes
/// with other audio and plays on silent. Settings isn't on screen during a Workout, so it never meets the Workout's
/// audio.
///
/// Best effort: a sound that can't play leaves the choice made all the same.
final class RoundSoundPreview {
    private struct Graph {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
    }

    private let session = AVAudioSession.sharedInstance()
    /// Built at the first play, since SwiftUI makes a new preview each time it remakes the screen and keeps only one.
    private var graph: Graph?
    /// Counts the plays, so the end of one that's been cut short doesn't stop the one that replaced it.
    private var plays = 0

    func play(_ sound: RoundSound) {
        guard let format = CueBank.format, let buffer = sound.sound(in: format) else { return }
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let graph = try builtGraph(in: format)
            if !graph.engine.isRunning {
                try graph.engine.start()
            }
            graph.player.stop()
            plays += 1
            graph.player.scheduleBuffer(
                buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack,
                completionHandler: finished(plays))
            try graph.player.playAudio()
        } catch {
            stop()
        }
    }

    private func builtGraph(in format: AVAudioFormat) throws -> Graph {
        if let graph {
            return graph
        }
        let graph = Graph()
        graph.engine.attach(graph.player)
        try graph.engine.connectNode(graph.player, to: graph.engine.mainMixerNode, format: format)
        self.graph = graph
        return graph
    }

    /// Nonisolated, because the player calls this on its own thread.
    private nonisolated func finished(_ play: Int) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { [weak self] _ in
            Task { @MainActor in
                guard let self, play == self.plays else { return }
                self.stop()
            }
        }
    }

    /// Lets other audio know it can come back to full volume.
    private func stop() {
        graph?.player.stop()
        graph?.engine.stop()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
