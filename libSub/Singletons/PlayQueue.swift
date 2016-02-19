//
//  PlayQueue.swift
//  Pods
//
//  Created by Benjamin Baron on 2/11/16.
//
//

import Foundation
import MediaPlayer

@objc
public enum RepeatMode: Int {
    case Normal
    case RepeatOne
    case RepeatAll
}

@objc
public enum ShuffleMode: Int {
    case Normal
    case Shuffle
}

@objc
public class PlayQueue: NSObject {
    
    public static let sharedInstance = PlayQueue()
    
    public var repeatMode = RepeatMode.Normal
    
    public var shuffleMode = ShuffleMode.Normal {
        didSet {
            // TODO: Do something
        }
    }
    
    public private(set) var currentIndex = 0 {
        didSet {
            updateLockScreenInfo()
        }
    }
    
    public var previousIndex: Int {
        switch self.repeatMode {
        case .Normal:
            return self.currentIndex - 1
        case .RepeatAll:
            let index = self.currentIndex - 1
            if index < 0 {
                // Roll over to end of playlist
                return self.playlist.songCount - 1
            } else {
                return index
            }
        case .RepeatOne:
            return self.currentIndex
        }
    }
    
    public var nextIndex: Int {
        switch self.repeatMode {
        case .Normal:
            return self.currentIndex + 1
        case .RepeatAll:
            let index = self.currentIndex + 1
            if index >= self.playlist.songCount {
                // Roll over to beginning of playlist
                return 0
            } else {
                return index
            }
        case .RepeatOne:
            return self.currentIndex
        }
    }
    
    public var currentDisplaySong: ISMSSong? {
        // Either the current song, or the previous song if we're past the end of the playlist
        if let song = self.currentSong {
            return song
        } else {
            return self.previousSong
        }
    }

    public var currentSong: ISMSSong? {
        return self.playlist.songAtIndex(self.currentIndex)
    }
    
    public var previousSong: ISMSSong? {
        return self.playlist.songAtIndex(self.previousIndex)
    }
    
    public var nextSong: ISMSSong? {
        return self.playlist.songAtIndex(self.nextIndex)
    }
    
    public var songCount: Int {
        return self.playlist.songCount
    }
    
    public var isPlaying: Bool {
        return self.audioEngine.isPlaying()
    }
    
    public var isStarted: Bool {
        return self.audioEngine.isStarted()
    }
    
    public var currentSongProgress: Double {
        return self.audioEngine.progress()
    }
    
    private var playlist: Playlist {
        return Playlist.playQueue
    }
    
    private var audioEngine: AudioEngine {
        return AudioEngine.sharedInstance()
    }
    
    public func playSongs(songs: [ISMSSong], playIndex: Int) {
        reset()
        self.playlist.addSongs(songs: songs)
        self.playSongAtIndex(playIndex)
    }
    
    public func reset() {
        self.playlist.removeAllSongs()
        self.audioEngine.stop()
    }
    
    public func removeSongsAtIndexes(indexes: NSIndexSet) {
        self.playlist.removeSongsAtIndexes(indexes)
    }
    
    public func songAtIndex(index: Int) -> ISMSSong? {
        return self.playlist.songAtIndex(index)
    }
    
    public func indexAtOffset(offset: Int, fromIndex: Int) -> Int {
        let songCount = self.songCount
        
        switch self.repeatMode {
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
            return fromIndex
            // TODO: Finish implementing this, needs to roll over as many times as necessary
//            if offset >= 0 {
//                if fromIndex + offset >= songCount {
//                    var tempIndex = songCount - 1
//                    var remainder = fromIndex + offset - songCount
//                    while remainder > 0 {
//                        
//                    }
//                } else {
//                    return fromIndex + offset
//                }
//            } else {
//                return fromIndex + offset >= 0 ? fromIndex + offset : songCount + fromIndex + offset;
//            }
        case .RepeatOne:
            return fromIndex
        }
    }
    
    public func indexAtOffsetFromCurrentIndex(offset: Int) -> Int {
        return indexAtOffset(offset, fromIndex: self.currentIndex)
    }
    
    public func playSongAtIndex(index: Int) {
        self.currentIndex = index
        if let currentSong = self.currentSong {
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
        self.audioEngine.play()
    }
    
    public func pause() {
        self.audioEngine.pause()
    }
    
    public func playPause() {
        self.audioEngine.playPause()
    }
    
    public func stop() {
        self.audioEngine.stop()
    }
    
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
                trackInfo[MPNowPlayingInfoPropertyPlaybackQueueIndex] = self.currentIndex
                trackInfo[MPNowPlayingInfoPropertyPlaybackQueueCount] = self.songCount
                trackInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.audioEngine.progress()
                trackInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

                if SavedSettings.sharedInstance().isLockScreenArtEnabled {
                    if let coverArtId = song.coverArtId {
                        let artDataModel = SUSCoverArtDAO(delegate: nil, coverArtId: coverArtId.stringValue, isLarge: true)
                        trackInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: artDataModel.coverArtImage())
                    } else {
                        trackInfo[MPMediaItemPropertyArtwork] = NSNull()
                    }
                }
                
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = trackInfo
            }
            
            // Run this every 30 seconds to update the progress and keep it in sync
            if let lockScreenUpdateTimer = self.lockScreenUpdateTimer {
                lockScreenUpdateTimer.invalidate()
            }
            self.lockScreenUpdateTimer = NSTimer(timeInterval: 30.0, target: self, selector: "updateLockScreenInfo", userInfo: nil, repeats: false)
        #endif
    }
    
    public func startSong() {
        startSong(offsetBytes: 0, offsetSeconds: 0)
    }
    
    private var startSongDelayTimer: NSTimer?
    public func startSong(offsetBytes offsetBytes: Int, offsetSeconds: Double) {
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
                self.startSongDelayTimer = NSTimer.scheduledTimerWithTimeInterval(0.6, target: self, selector: "startSongWithByteAndSecondsOffset:", userInfo: ["bytes": offsetBytes, "seconds": offsetSeconds], repeats: false)
            }
        }

        // Only allowed to manipulate BASS from the main thread
        if NSThread.isMainThread() {
            work()
        } else {
            EX2Dispatch.runInMainThreadAsync(work)
        }
    }
    
    // TODO: Clean this up
    public func startSongWithByteAndSecondsOffset(timer: NSTimer) {
        
        guard let userInfo = timer.userInfo as? [String: AnyObject] else {
            return
        }
        
        NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_RemoveMoviePlayer)

        if let currentSong = self.currentSong {
            let settings = SavedSettings.sharedInstance()
            let streamManager = ISMSStreamManager.sharedInstance()
            let cacheQueueManager = ISMSCacheQueueManager.sharedInstance()
            let offsetBytes = userInfo["bytes"] as! NSNumber
            let offsetSeconds = userInfo["seconds"] as! NSNumber
            let currentIndex = self.currentIndex
            
            // Check to see if the song is already cached
            if currentSong.isFullyCached {
                // The song is fully cached, start streaming from the local copy
                self.audioEngine.startSong(currentSong, atIndex: UInt(currentIndex), withOffsetInBytes: offsetBytes, orSeconds: offsetSeconds)
            } else {
                // Fill the stream queue
                if !settings.isOfflineMode {
                    streamManager.fillStreamQueue(true)
                } else if !currentSong.isFullyCached && settings.isOfflineMode {
                    // TODO: Prevent this running forever in RepeatAll mode with no songs available
                    self.playSongAtIndex(self.nextIndex)
                } else {
                    if cacheQueueManager.currentQueuedSong.isEqualToSong(currentSong) {
                        // The cache queue is downloading this song, remove it before continuing
                        cacheQueueManager.removeCurrentSong()
                    }
                    
                    if streamManager.isSongDownloading(currentSong) {
                        // The song is caching, start streaming from the local copy
                        let handler = streamManager.handlerForSong(currentSong)
                        if !self.audioEngine.isPlaying() && handler.isDelegateNotifiedToStartPlayback {
                            // Only start the player if the handler isn't going to do it itself
                            self.audioEngine.startSong(currentSong, atIndex: UInt(currentIndex), withOffsetInBytes:offsetBytes, orSeconds:offsetSeconds)
                        }
                    } else if streamManager.isSongFirstInQueue(currentSong) && !streamManager.isQueueDownloading {
                        // The song is first in queue, but the queue is not downloading. Probably the song was downloading
                        // when the app quit. Resume the download and start the player
                        streamManager.resumeQueue()
                        
                        // The song is caching, start streaming from the local copy
                        let handler = streamManager.handlerForSong(currentSong)
                        if !self.audioEngine.isPlaying() && handler.isDelegateNotifiedToStartPlayback {
                            // Only start the player if the handler isn't going to do it itself
                            self.audioEngine.startSong(currentSong, atIndex: UInt(currentIndex), withOffsetInBytes:offsetBytes, orSeconds:offsetSeconds)
                        }
                    } else {
                        // Clear the stream manager
                        streamManager.removeAllStreams()
                        
                        var isTempCache = false
                        if offsetBytes.integerValue > 0 || !settings.isSongCachingEnabled {
                            isTempCache = true
                        }
                        
                        // Start downloading the current song from the correct offset
                        streamManager.queueStreamForSong(currentSong, byteOffset: offsetBytes.unsignedLongLongValue, secondsOffset: offsetSeconds.doubleValue, atIndex: 0, isTempCache: isTempCache, isStartDownload: true)
                        
                        // Fill the stream queue
                        if settings.isSongCachingEnabled {
                            streamManager.fillStreamQueue(self.audioEngine.isStarted())
                        }
                    }
                }
            }
        }
    }
}

extension PlayQueue: BassGaplessPlayerDelegate {
    
    public func bassFirstStreamStarted(player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }
    
    public func bassSongEndedCalled(player: BassGaplessPlayer) {
        // Increment current playlist index
        self.currentIndex = self.nextIndex
        
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }
    
    public func bassFreed(player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerClearSocial()
    }

    public func bassIndexAtOffset(offset: Int, fromIndex index: Int, player: BassGaplessPlayer) -> Int {
        return self.indexAtOffset(offset, fromIndex: index)
    }
    
    public func bassSongForIndex(index: Int, player: BassGaplessPlayer) -> ISMSSong? {
        return self.songAtIndex(index)
    }
    
    public func bassCurrentPlaylistIndex(player: BassGaplessPlayer) -> Int {
        return self.currentIndex
    }
    
    public func bassRetrySongAtIndex(index: Int, player: BassGaplessPlayer) {
        EX2Dispatch.runInMainThreadAsync() {
            self.playSongAtIndex(index)
        }
    }
    
    public func bassUpdateLockScreenInfo(player: BassGaplessPlayer) {
        self.updateLockScreenInfo()
    }
    
    public func bassRetrySongAtOffsetInBytes(bytes: Int, andSeconds seconds: Int, player: BassGaplessPlayer) {
        //MusicSingleton.sharedInstance().startSongAtOffsetInBytes(bytes, andSeconds: seconds)
    }
    
    public func bassFailedToCreateNextStreamForIndex(index: Int, player: BassGaplessPlayer) {
        // The song ended, and we tried to make the next stream but it failed
        let song = self.songAtIndex(index)
        let handler = ISMSStreamManager.sharedInstance().handlerForSong(song)
        
        if !handler.isDownloading || handler.isDelegateNotifiedToStartPlayback {
            // If the song isn't downloading, or it is and it already informed the player to play (i.e. the playlist will stop if we don't force a retry), then retry
            EX2Dispatch.runInMainThreadAsync() {
                self.playSongAtIndex(index)
            }
        }
    }
    
    public func bassRetrievingOutputData(player: BassGaplessPlayer) {
        // TODO: Is this the best place for this?
        SocialSingleton.sharedInstance().playerHandleSocial()
    }
}