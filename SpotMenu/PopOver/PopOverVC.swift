import Cocoa
import WebKit
import MusicPlayer

final class PopOverViewController: NSViewController {
    
    // MARK: - Properties
    
    private var lastArtworkUrl = ""
    fileprivate var rightTimeIsDuration: Bool = true
    private var defaultImage: NSImage!
    private var musicPlayerManager: MusicPlayerManager!
    private var position: Double = 0
    private var duration: Double = 0
    private var isPlaying: Bool = false
    private var timer: Timer!
    
    // MARK: - IBOutlets
    
    @IBOutlet weak fileprivate var positionSlider: NSSlider!
    @IBOutlet weak private var artistLabel: NSTextField!
    @IBOutlet weak private var aLabel: NSTextField!
    @IBOutlet weak private var titleLabel: NSTextField!
    @IBOutlet weak private var playerStateButton: NSButton!
    @IBOutlet weak private var artworkImageView: NSImageView!
    @IBOutlet weak private var leftTime: NSTextField!
    @IBOutlet weak private var rightTime: NSTextField!
    
    // MARK: - Lifecycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        defaultImage = artworkImageView.image
        self.preferredContentSize = NSSize(width: 300, height: 300)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        self.musicPlayerManager.delegate = self
        
        let track = musicPlayerManager.existMusicPlayer(with: .spotify)?.currentTrack
        updateInfo(track: track)
      
        
        let state = musicPlayerManager.existMusicPlayer(with: .spotify)?.playbackState
        updateButton(state: state)
        
        if let state = state {
            self.isPlaying = state == .playing
        }
        if let track = track {
            self.duration = track.duration
        }
        if let position = musicPlayerManager.existMusicPlayer(with: .spotify)?.playerPosition {
            self.position = position
        }
        
        updateTime()
        
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(self.updatePlayerPosition),
            userInfo: nil,
            repeats: true)
    }
    
    override func viewDidDisappear() {
        timer.invalidate()
        self.musicPlayerManager.delegate = nil
    }
    
    // MARK: - Public methods
    
    func setUpMusicPlayerManager() {
        if self.musicPlayerManager == nil {
            self.musicPlayerManager = MusicPlayerManager()
            self.musicPlayerManager.add(musicPlayer: MusicPlayerName.spotify)
            self.musicPlayerManager.add(musicPlayer: MusicPlayerName.iTunes)
        }
    }

    // MARK: - Private methods
    
    @objc private func updatePlayerPosition() {
        if isPlaying {
            
            positionSlider.doubleValue = floor(position/duration * 100)
            self.position = self.position + 1
            updateTime()
        }
    }
    
    private func updateInfo(track: MusicTrack?) {
        if let track = track {
            if let artworkUrl = track.artworkUrl , artworkUrl != lastArtworkUrl {
                if let url = URL(string: artworkUrl) {
                    self.artworkImageView.downloadImage(url: url)
                    lastArtworkUrl = artworkUrl
                }
            }
            if track.artworkUrl == nil {
                artworkImageView.image = defaultImage
            }
            if let artwork = track.artwork {
                artworkImageView.image = artwork
            }
            
            if let artist = track.artist {
                artistLabel.stringValue = artist
                artistLabel.textColor = nil
                
            } else {
                artistLabel.stringValue = "Artist"
                artistLabel.textColor = NSColor.gray
            }
            
            titleLabel.stringValue = track.title
            titleLabel.textColor = nil
            
        } else {
            artistLabel.stringValue = "Artist"
            artistLabel.textColor = NSColor.gray
            
            titleLabel.stringValue = "Title"
            titleLabel.textColor = NSColor.gray
        }

        updateTime()
    }
    
    fileprivate func updateTime() {
        let leftTimeTuple = secondsToHoursMinutesSeconds(seconds: self.position)
        leftTime.stringValue = getTimeString(tuple: leftTimeTuple)
        
        switch rightTimeIsDuration {
        case true:
            let rightTimeTuple = secondsToHoursMinutesSeconds(seconds: self.duration)
            rightTime.stringValue = getTimeString(tuple: rightTimeTuple)
        case false:
            let rightTimeTuple = secondsToHoursMinutesSeconds(seconds: self.duration - self.position)
            rightTime.stringValue = "-" + getTimeString(tuple: rightTimeTuple)
        }
        
    }

    private func updateButton(state: MusicPlaybackState?) {
        if let state = state {
            switch state {
            case .paused:
                playerStateButton.title = "▶︎"
            case .playing, .fastForwarding, .rewinding, .reposition:
                playerStateButton.title = "❚❚"
            default:
                playerStateButton.title = "▶︎"
            }
        }
        else {
            playerStateButton.title = "▶︎"
        }
    }
    
    
    private func secondsToHoursMinutesSeconds (seconds : Double) -> (Int, Int, Int) {
        return (Int(seconds / 3600),
                Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60),
                Int((seconds.truncatingRemainder(dividingBy: 3600).truncatingRemainder(dividingBy:
            60))))
    }
    
    private func getTimeString(tuple: (Int,Int,Int))-> String {
        return String(format: "%02d:%02d", tuple.1, tuple.2)
    }
}

// MARK: Actions

private extension PopOverViewController {
    
    @IBAction func goLeft(_ sender: NSButton) {
        self.musicPlayerManager.currentPlayer?.playPrevious()
    }
    
    @IBAction func goRight(_ sender: NSButton) {
        self.musicPlayerManager.currentPlayer?.playNext()
    }
    
    @IBAction func openSpotify(_ sender: Any) {
        self.musicPlayerManager.currentPlayer?.activate()
    }
    
    @IBAction func positionSliderAction(_ sender: AnyObject) {
        self.position = (positionSlider.doubleValue/100.0)*self.duration
        self.musicPlayerManager.currentPlayer?.playerPosition = self.position
    }
    
    @IBAction func togglePlay(_ sender: AnyObject) {
        if let state = self.musicPlayerManager.currentPlayer?.playbackState {
            switch state {
            case .paused:
                self.musicPlayerManager.currentPlayer?.play()
            case .playing:
                self.musicPlayerManager.currentPlayer?.pause()
            default: break
            }
        }

    }
    
    @IBAction func toggleRightTime(_ sender: AnyObject) {
        rightTimeIsDuration = !rightTimeIsDuration
        updateTime()
    }
}

extension PopOverViewController:  MusicPlayerManagerDelegate {
    func manager(_ manager: MusicPlayerManager, trackingPlayer player: MusicPlayer, didChangeTrack track: MusicTrack, atPosition position: TimeInterval) {
        self.duration = track.duration
        self.position = position
        updateInfo(track: track)
    }
    
    func manager(_ manager: MusicPlayerManager, trackingPlayer player: MusicPlayer, playbackStateChanged playbackState: MusicPlaybackState, atPosition position: TimeInterval) {
        self.position = position
        switch playbackState {
        case .playing, .fastForwarding, .rewinding, .reposition:
            self.isPlaying = true
        default:
            self.isPlaying = false
        }
        updateInfo(track: player.currentTrack)
        updateButton(state: playbackState)
    }
    
    func manager(_ manager: MusicPlayerManager, trackingPlayerDidQuit player: MusicPlayer) {
        updateInfo(track: nil)
    }
    
    func manager(_ manager: MusicPlayerManager, trackingPlayerDidChange player: MusicPlayer) {
    }
    
}

// MARK: - NSImageView image download

extension NSImageView {
    
    private func getDataFromUrl(url: URL, completion: @escaping (_ data: Data?, _  response: URLResponse?, _ error: Error?) -> Void) {
        URLSession.shared.dataTask(with: url) {
            (data, response, error) in
            completion(data, response, error)
            }.resume()
    }
    
    func downloadImage(url: URL) {
        
        getDataFromUrl(url: url) { (data, response, error)  in
            DispatchQueue.main.sync() { () -> Void in
                guard let data = data, error == nil else { return }
                self.image = NSImage(data: data)
            }
        }
    }
    
}
