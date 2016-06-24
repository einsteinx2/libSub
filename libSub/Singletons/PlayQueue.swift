//
//  PlayQueue.swift
//  Pods
//
//  Created by Benjamin Baron on 2/11/16.
//
//

import Foundation
import MediaPlayer

@objc public enum RepeatMode: Int {
    case Normal
    case RepeatOne
    case RepeatAll
}

@objc public enum ShuffleMode: Int {
    case Normal
    case Shuffle
}

@objc public class PlayQueue: NSObject {
    
    //
    // MARK: - Notifications -
    //
    
    public struct Notifications {
        public static let playQueueIndexChanged = "playQueueIndexChanged"
    }
    
    private func notifyPlayQueueIndexChanged() {
        NSNotificationCenter.postNotificationToMainThreadWithName(PlayQueue.Notifications.playQueueIndexChanged, object: nil)
    }
    
    private func registerForNotifications() {
        // Watch for changes to the play queue playlist
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(PlayQueue.playlistChanged(_:)), name: Playlist.Notifications.playlistChanged, object: nil)
    }
    
    private func unregisterForNotifications() {
        NSNotificationCenter.removeObserverOnMainThread(self, name: Playlist.Notifications.playlistChanged, object: nil)
    }
    
    @objc private func playlistChanged(notification: NSNotification) {
        
    }
    
    //
    // MARK: - Properties -
    //
    
    public static let sharedInstance = PlayQueue()
    
    public var repeatMode = RepeatMode.Normal
    public var shuffleMode = ShuffleMode.Normal { didSet { /* TODO: Do something */ } }
    
    public private(set) var currentIndex = 0 { didSet { updateLockScreenInfo(); notifyPlayQueueIndexChanged() } }
    public var previousIndex: Int { return indexAtOffset(-1, fromIndex: currentIndex) }
    public var nextIndex: Int { return indexAtOffset(1, fromIndex: currentIndex) }
    public var currentDisplaySong: ISMSSong? { return currentSong ?? previousSong }
    public var currentSong: ISMSSong? { return playlist.songAtIndex(currentIndex) }
    public var previousSong: ISMSSong? { return playlist.songAtIndex(previousIndex) }
    public var nextSong: ISMSSong? { return playlist.songAtIndex(nextIndex) }
    public var songCount: Int { return playlist.songCount }
    public var isPlaying: Bool { return audioEngine.isPlaying() }
    public var isStarted: Bool { return audioEngine.isStarted() }
    public var currentSongProgress: Double { return audioEngine.progress() }
    public var songs: [ISMSSong] { return playlist.songs }
    public var playlist: Playlist { return Playlist.playQueue }
    
    private var audioEngine: AudioEngine { return AudioEngine.sharedInstance() }
    
    //
    // MARK: - Play Queue -
    //
    
    public func reset() {
        playlist.removeAllSongs()
        audioEngine.stop()
    }
    
    public func removeSongsAtIndexes(indexes: NSIndexSet) {
        // Stop the music if we're removing the current song
        let containsCurrentIndex = indexes.containsIndex(currentIndex)
        if containsCurrentIndex {
            audioEngine.stop()
        }
        
        // Remove the songs
        playlist.removeSongsAtIndexes(indexes)
        
        // Adjust the current index if songs are removed below it
        let range = NSMakeRange(0, currentIndex)
        let countOfIndexesBelowCurrent = indexes.countOfIndexesInRange(range)
        currentIndex = currentIndex - countOfIndexesBelowCurrent
        
        // If we removed the current song, start the next one
        if containsCurrentIndex {
            playSongAtIndex(currentIndex)
        }
    }
    
    public func moveSong(fromIndex fromIndex: Int, toIndex: Int, notify: Bool = false) {
        let original = currentIndex
        if playlist.moveSong(fromIndex: fromIndex, toIndex: toIndex, notify: notify) {
            if fromIndex == currentIndex && toIndex < currentIndex {
                // Moved the current song to a lower index
                currentIndex = toIndex
            } else if fromIndex == currentIndex && toIndex > currentIndex {
                // Moved the current song to a higher index
                currentIndex = toIndex - 1
            } else if fromIndex > currentIndex && toIndex <= currentIndex {
                // Moved a song from after the current song to before
                currentIndex += 1
            } else if fromIndex < currentIndex && toIndex >= currentIndex {
                // Moved a song from before the current song to after
                currentIndex -= 1
            }
        }
    }
    
    public func songAtIndex(index: Int) -> ISMSSong? {
        return playlist.songAtIndex(index)
    }
    
    public func indexAtOffset(offset: Int, fromIndex: Int) -> Int {
        switch repeatMode {
        case .Normal:
            if offset >= 0 {
                if fromIndex + offset > songCount {
                    // If we're past the end of the play queue, always return the last index + 1
                    return songCount
                } else {
                    return fromIndex + offset
                }
            } else {
                return fromIndex + offset >= 0 ? fromIndex + offset : 0;
            }
        case .RepeatAll:
            if offset >= 0 {
                if fromIndex + offset >= songCount {
                    let remainder = offset - (songCount - fromIndex)
                    return indexAtOffset(remainder, fromIndex: 0)
                } else {
                    return fromIndex + offset
                }
            } else {
                return fromIndex + offset >= 0 ? fromIndex + offset : songCount + fromIndex + offset;
            }
        case .RepeatOne:
            return fromIndex
        }
    }
    
    public func indexAtOffsetFromCurrentIndex(offset: Int) -> Int {
        return indexAtOffset(offset, fromIndex: self.currentIndex)
    }
    
    //
    // MARK: - Player Control -
    //
    
    public func playSongs(songs: [ISMSSong], playIndex: Int) {
        reset()
        playlist.addSongs(songs: songs)
        playSongAtIndex(playIndex)
    }
    
    public func playSongAtIndex(index: Int) {
        currentIndex = index
        if let currentSong = currentSong {
            if currentSong.contentType?.basicType != .Video {
                // Remove the video player if this is not a video
                NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_RemoveMoviePlayer)
            }
            
            if SavedSettings.sharedInstance().isJukeboxEnabled {
                if currentSong.contentType?.basicType == .Video {
                    EX2SlidingNotification.slidingNotificationOnMainWindowWithMessage("Cannot play videos in Jukebox mode.", image: nil)
                } else {
                    JukeboxSingleton.sharedInstance().jukeboxPlaySongAtPosition(index)
                }
            } else {
                ISMSStreamManager.sharedInstance().removeAllStreamsExceptForSong(currentSong)
                
                if currentSong.contentType?.basicType == .Video {
                    NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_PlayVideo, userInfo: ["song": currentSong])
                } else {
                    startSong()
                }
            }
        }
    }

    public func playPreviousSong() {
        if audioEngine.progress() > 10.0 {
            // Past 10 seconds in the song, so restart playback instead of changing songs
            playSongAtIndex(self.currentIndex)
        } else {
            // Within first 10 seconds, go to previous song
            playSongAtIndex(self.previousIndex)
        }
    }
    
    public func playNextSong() {
        playSongAtIndex(self.nextIndex)
    }
    
    public func play() {
        audioEngine.play()
    }
    
    public func pause() {
        audioEngine.pause()
    }
    
    public func playPause() {
        audioEngine.playPause()
    }
    
    public func stop() {
        audioEngine.stop()
    }
    
    public func startSong() {
        startSong(offsetBytes: 0, offsetSeconds: 0)
    }
    
    private var startSongDelayTimer: NSTimer?
    public func startSong(offsetBytes offsetBytes: Int, offsetSeconds: Int) {
        let work = {
            if let startSongDelayTimer = self.startSongDelayTimer {
                startSongDelayTimer.invalidate()
                self.startSongDelayTimer = nil
            }
            
            // Destroy the streamer to start a new song
            self.audioEngine.stop()
            
            if self.currentSong != nil {
                // Only start the caching process if it's been a half second after the last request
                // Prevents crash when skipping through playlist fast
                self.startSongDelayTimer = NSTimer.scheduledTimerWithTimeInterval(0.6, target: self, selector: #selector(PlayQueue.startSongWithByteAndSecondsOffset(_:)), userInfo: ["bytes": offsetBytes, "seconds": offsetSeconds], repeats: false)
            }
        }
        
        // Only allowed to manipulate BASS from the main thread
        if NSThread.isMainThread() {
            work()
        } else {
            EX2Dispatch.runInMainThreadAsync(work)
        }
    }
    
    public func startSongWithByteAndSecondsOffset(timer: NSTimer) {
        guard let userInfo = timer.userInfo as? [String: AnyObject] else {
            return
        }
        
        NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_RemoveMoviePlayer)
        
        if let currentSong = currentSong {
            let settings = SavedSettings.sharedInstance()
            let streamManager = ISMSStreamManager.sharedInstance()
            let cacheQueueManager = ISMSCacheQueueManager.sharedInstance()
            let offsetBytes = userInfo["bytes"] as? NSNumber
            let offsetSeconds = userInfo["seconds"] as? NSNumber
            let audioEngineStartSong = {
                if let bytes = offsetBytes?.integerValue {
                    self.audioEngine.startSong(currentSong, index: self.currentIndex, offsetInBytes: bytes)
                } else if let seconds = offsetSeconds?.integerValue {
                    self.audioEngine.startSong(currentSong, index: self.currentIndex, offsetInSeconds: seconds)
                }
            }
            
            // Check to see if the song is already cached
            if currentSong.isFullyCached {
                // The song is fully cached, start streaming from the local copy
                audioEngineStartSong()
            } else {
                // Fill the stream queue
                if !settings.isOfflineMode {
                    streamManager.fillStreamQueue(true)
                } else if !currentSong.isFullyCached && settings.isOfflineMode {
                    // TODO: Prevent this running forever in RepeatAll mode with no songs available
                    self.playSongAtIndex(nextIndex)
                } else {
                    if cacheQueueManager.currentQueuedSong.isEqualToSong(currentSong) {
                        // The cache queue is downloading this song, remove it before continuing
                        cacheQueueManager.removeCurrentSong()
                    }
                    
                    if streamManager.isSongDownloading(currentSong) {
                        // The song is caching, start streaming from the local copy
                        if let handler = streamManager.handlerForSong(currentSong) {
                            if !audioEngine.isPlaying() && handler.isDelegateNotifiedToStartPlayback {
                                // Only start the player if the handler isn't going to do it itself
                                audioEngineStartSong()
                            }
                        }
                    } else if streamManager.isSongFirstInQueue(currentSong) && !streamManager.isQueueDownloading {
                        // The song is first in queue, but the queue is not downloading. Probably the song was downloading
                        // when the app quit. Resume the download and start the player
                        streamManager.resumeQueue()
                        
                        // The song is caching, start streaming from the local copy
                        if let handler = streamManager.handlerForSong(currentSong) {
                            if !self.audioEngine.isPlaying() && handler.isDelegateNotifiedToStartPlayback {
                                // Only start the player if the handler isn't going to do it itself
                                audioEngineStartSong()
                            }
                        }
                    } else {
                        // Clear the stream manager
                        streamManager.removeAllStreams()
                        
                        var isTempCache = false
                        if let offsetBytes = offsetBytes {
                            if offsetBytes.integerValue > 0 || !settings.isSongCachingEnabled {
                                isTempCache = true
                            }
                        }
                        
                        let bytes = offsetBytes?.unsignedLongLongValue ?? 0
                        let seconds = offsetSeconds?.doubleValue ?? 0
                        
                        // Start downloading the current song from the correct offset
                        streamManager.queueStreamForSong(currentSong, byteOffset: bytes, secondsOffset: seconds, atIndex: 0, isTempCache: isTempCache, isStartDownload: true)
                        
                        // Fill the stream queue
                        if settings.isSongCachingEnabled {
                            streamManager.fillStreamQueue(self.audioEngine.isStarted())
                        }
                    }
                }
            }
        }
    }
    
    //
    // MARK: - Lock Screen -
    //
    
    private var lockScreenUpdateTimer: NSTimer?
    public func updateLockScreenInfo() {
        #if os(iOS)
            var trackInfo = [String: AnyObject]()
            if let song = self.currentSong {
                if let title = song.title {
                    trackInfo[MPMediaItemPropertyTitle] = title
                }
                if let albumName = song.album?.name {
                    trackInfo[MPMediaItemPropertyAlbumTitle] = albumName
                }
                if let artistName = song.artist?.name {
                    trackInfo[MPMediaItemPropertyArtist] = artistName
                }
                if let genre = song.genre?.name {
                    trackInfo[MPMediaItemPropertyGenre] = genre
                }
                if let duration = song.duration {
                    trackInfo[MPMediaItemPropertyPlaybackDuration] = duration
                }
                trackInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = currentIndex
                trackInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = songCount
                trackInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioEngine.progress()
                trackInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
                
                if SavedSettings.sharedInstance().isLockScreenArtEnabled {
                    if let coverArtId = song.coverArtId {
                        let artDataModel = SUSCoverArtDAO(delegate: nil, coverArtId: coverArtId, isLarge: true)
                        trackInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: artDataModel.coverArtImage())
                    }
                }
                
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = trackInfo
            }
            
            // Run this every 30 seconds to update the progress and keep it in sync
            if let lockScreenUpdateTimer = self.lockScreenUpdateTimer {
                lockScreenUpdateTimer.invalidate()
            }
            lockScreenUpdateTimer = NSTimer(timeInterval: 30.0, target: self, selector: #selector(PlayQueue.updateLockScreenInfo), userInfo: nil, repeats: false)
        #endif
    }
}

extension PlayQueue: BassGaplessPlayerDelegate {
    
    public func bassFirstStreamStarted(player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }
    
    public func bassSongEndedCalled(player: BassGaplessPlayer) {
        // Increment current playlist index
        currentIndex = nextIndex
        
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }
    
    public func bassFreed(player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }

    public func bassIndexAtOffset(offset: Int, fromIndex index: Int, player: BassGaplessPlayer) -> Int {
        return indexAtOffset(offset, fromIndex: index)
    }
    
    public func bassSongForIndex(index: Int, player: BassGaplessPlayer) -> ISMSSong? {
        return songAtIndex(index)
    }
    
    public func bassCurrentPlaylistIndex(player: BassGaplessPlayer) -> Int {
        return currentIndex
    }
    
    public func bassRetrySongAtIndex(index: Int, player: BassGaplessPlayer) {
        EX2Dispatch.runInMainThreadAsync() {
            self.playSongAtIndex(index)
        }
    }
    
    public func bassUpdateLockScreenInfo(player: BassGaplessPlayer) {
        updateLockScreenInfo()
    }
    
    public func bassRetrySongAtOffsetInBytes(bytes: Int, andSeconds seconds: Int, player: BassGaplessPlayer) {
        startSong(offsetBytes: bytes, offsetSeconds: seconds)
    }
    
    public func bassFailedToCreateNextStreamForIndex(index: Int, player: BassGaplessPlayer) {
        // The song ended, and we tried to make the next stream but it failed
        if let song = self.songAtIndex(index), handler = ISMSStreamManager.sharedInstance().handlerForSong(song) {
            if !handler.isDownloading || handler.isDelegateNotifiedToStartPlayback {
                // If the song isn't downloading, or it is and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
                EX2Dispatch.runInMainThreadAsync() {
                    self.playSongAtIndex(index)
                }
            }
        }
    }
    
    public func bassRetrievingOutputData(player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerHandleSocial()
    }
}