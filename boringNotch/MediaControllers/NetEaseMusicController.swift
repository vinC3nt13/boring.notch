//
//  NetEaseMusicController.swift
//  boringNotch
//

import AppKit
import Combine
import Foundation

final class NetEaseMusicController: MediaControllerProtocol {
    static let bundleIdentifier = "com.netease.163music"

    @Published private var playbackState = PlaybackState(
        bundleIdentifier: NetEaseMusicController.bundleIdentifier,
        title: "Not Playing",
        artist: "网易云音乐"
    )

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }

    let supportsVolumeControl = true
    let supportsFavorite = true

    private let nowPlayingController: NowPlayingController?
    private var cancellable: AnyCancellable?

    init() {
        nowPlayingController = NowPlayingController()
        cancellable = nowPlayingController?.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.receive(state)
            }
    }

    func setFavorite(_ favorite: Bool) async {
        guard await XPCHelperClient.shared.ensureAccessibilityAuthorization(
            promptIfNeeded: true
        ) else { return }

        guard await XPCHelperClient.shared.setNetEaseFavorite(favorite) else {
            return
        }

        playbackState.isFavorite = favorite
    }

    func play() async {
        await launchIfNeeded()
        await nowPlayingController?.play()
    }

    func pause() async {
        guard isActive() else { return }
        await nowPlayingController?.pause()
    }

    func seek(to time: Double) async {
        guard isActive() else { return }
        await nowPlayingController?.seek(to: time)
    }

    func nextTrack() async {
        guard isActive() else { return }
        await nowPlayingController?.nextTrack()
    }

    func previousTrack() async {
        guard isActive() else { return }
        await nowPlayingController?.previousTrack()
    }

    func togglePlay() async {
        if isActive() {
            await nowPlayingController?.togglePlay()
        } else {
            await play()
        }
    }

    func toggleShuffle() async {
        guard isActive() else { return }
        await nowPlayingController?.toggleShuffle()
    }

    func toggleRepeat() async {
        guard isActive() else { return }
        await nowPlayingController?.toggleRepeat()
    }

    func setVolume(_ level: Double) async {
        guard await XPCHelperClient.shared.ensureAccessibilityAuthorization(
            promptIfNeeded: true
        ) else { return }

        guard await XPCHelperClient.shared.setNetEaseVolume(level) else {
            return
        }

        playbackState.volume = max(0, min(1, level))
    }

    func isActive() -> Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier
        ).isEmpty
    }

    func updatePlaybackInfo() async {
        await nowPlayingController?.updatePlaybackInfo()

        guard await XPCHelperClient.shared.isAccessibilityAuthorized() else {
            return
        }

        if let favorite = await XPCHelperClient.shared.currentNetEaseFavorite() {
            playbackState.isFavorite = favorite
        }
        if let volume = await XPCHelperClient.shared.currentNetEaseVolume() {
            playbackState.volume = volume
        }
    }

    private func receive(_ state: PlaybackState) {
        guard state.bundleIdentifier == Self.bundleIdentifier else {
            if playbackState.title == "Not Playing" {
                return
            }
            playbackState = PlaybackState(
                bundleIdentifier: Self.bundleIdentifier,
                title: "Not Playing",
                artist: "网易云音乐"
            )
            return
        }

        playbackState = state
    }

    private func launchIfNeeded() async {
        guard !isActive(),
              let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: Self.bundleIdentifier
              )
        else { return }

        await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.openApplication(
                at: appURL,
                configuration: configuration
            ) { _, _ in
                continuation.resume()
            }
        }

        try? await Task.sleep(for: .milliseconds(800))
    }
}
