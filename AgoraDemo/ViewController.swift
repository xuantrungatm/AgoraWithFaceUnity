//
//  ViewController.swift
//  AgoraDemo
//
//  Created by Xuan Trung on 30/11/2022.
//

import AVFoundation
import UIKit
import AgoraRtcKit
import AgoraReplayKitExtension

class ViewController: UIViewController {
    
    var beautyViewManager: FUDemoManager!
    var localView: UIView!
    var remoteView: UIView!
    var joinButton: UIButton!
    var publishButton: UIButton!
    var switchCameraButton: UIButton!
    var pkButton: UIButton!
    var nameLabel: UILabel!
    var copyButton: UIButton!
    
    // a ben
//    let channelName = "test"
//    let rtmpURL = "rtmp://entrypoint-app.evgcdn.net/live/f177bf9c"
    
    // user 2
    let channelName = "test1"
    let rtmpURL = "rtmp://entrypoint-app.evgcdn.net/live/12aa5ffd"
    
    var glVideoView: AGMEAGLVideoView!
    var videoFilter: FUManager!
    var capturerManager: CapturerManager!
    var processingManager: VideoProcessingManager!
    var agoraEngine: AgoraRtcEngineKit!
    var encoderConfig: AgoraVideoEncoderConfiguration!
    
    var isJoined: Bool = false {
        didSet {
            joinButton.setTitle(isJoined ? "Leave" : "Join", for: .normal)
            publishButton.isEnabled = isJoined
            publishButton.alpha = isJoined ? 1 : 0.5
        }
    }
    
    var isPublished: Bool = false {
        didSet {
            publishButton.setTitle(isPublished ? "Stop" : "Push", for: .normal)
            joinButton.isEnabled = !isPublished
            joinButton.alpha = (!isPublished) ? 1 : 0.5
        }
    }
    
    var transcoding = AgoraLiveTranscoding()
    var retried: UInt = 0
    var unpublishing: Bool = false
    let MAX_RETRY_TIMES = 3
    var remoteUid: UInt?
    var isCameraFront = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initViews()
        initializeAgoraEngine()
        startPreview()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        FUManager.share().destoryItems()
        capturerManager.stopCapture()
        agoraEngine.disableVideo()
        agoraEngine.disableAudio()
        agoraEngine.stopPreview()
        agoraEngine.stopChannelMediaRelay()
        agoraEngine.setVideoSource(nil)
        leaveChannel()
        AgoraRtcEngineKit.destroy()
    }
    
    func initViews() {
        localView = UIView(frame: UIScreen.main.bounds)
        view.addSubview(localView)
        
        remoteView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2, y: 100, width: UIScreen.main.bounds.width/2, height: 320))
        view.insertSubview(remoteView, belowSubview: localView)
        
        joinButton = UIButton(type: .custom)
        joinButton.frame = CGRect(x: 100, y: UIScreen.main.bounds.height - 100, width: 100, height: 50)
        joinButton.layer.cornerRadius = 25
        joinButton.clipsToBounds = true
        joinButton.backgroundColor = .blue
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.addTarget(self, action: #selector(joinAction), for: .touchUpInside)
        view.addSubview(joinButton)

        publishButton = UIButton(type: .custom)
        publishButton.frame = CGRect(x: 220, y: UIScreen.main.bounds.height - 100, width: 100, height: 50)
        publishButton.layer.cornerRadius = 25
        publishButton.clipsToBounds = true
        publishButton.backgroundColor = .blue
        publishButton.setTitleColor(.white, for: .normal)
        publishButton.addTarget(self, action: #selector(publish), for: .touchUpInside)
        view.addSubview(publishButton)
        
        switchCameraButton = UIButton(type: .custom)
        switchCameraButton.frame = CGRect(x: 16, y: 50, width: 80, height: 40)
        switchCameraButton.layer.cornerRadius = 20
        switchCameraButton.clipsToBounds = true
        switchCameraButton.backgroundColor = .blue
        switchCameraButton.setTitleColor(.white, for: .normal)
        switchCameraButton.setTitle("Camera", for: .normal)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        view.addSubview(switchCameraButton)
        
        pkButton = UIButton(type: .custom)
        pkButton.frame = CGRect(x: UIScreen.main.bounds.width - 96, y: 50, width: 80, height: 40)
        pkButton.layer.cornerRadius = 20
        pkButton.clipsToBounds = true
        pkButton.backgroundColor = .blue
        pkButton.setTitleColor(.white, for: .normal)
        pkButton.setTitle("PK", for: .normal)
        pkButton.addTarget(self, action: #selector(pkAction), for: .touchUpInside)
        view.addSubview(pkButton)
        
        nameLabel = UILabel(frame: CGRect(x: UIScreen.main.bounds.width - 86, y: 100, width: 70, height: 40))
        nameLabel.text = channelName == "test" ? "a ben" : "a ho"
        nameLabel.textAlignment = .center
        view.addSubview(nameLabel)
        
        copyButton = UIButton(type: .custom)
        copyButton.frame = CGRect(x: UIScreen.main.bounds.width - 136, y: 160, width: 120, height: 40)
        copyButton.layer.cornerRadius = 20
        copyButton.clipsToBounds = true
        copyButton.backgroundColor = .blue
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.setTitle("Copy token", for: .normal)
        copyButton.addTarget(self, action: #selector(copyToken), for: .touchUpInside)
        view.addSubview(copyButton)
        
        isJoined = false
        isPublished = false
    }
    
    @objc
    private func copyToken() {
        UIPasteboard.general.string = KeyCenter.Token
    }
    
    func initializeAgoraEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AppId
        agoraEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
    }
    
    private func startPreview() {
        if !checkForPermissions() {
            showMessage(title: "Error", text: "Permissions were not granted")
            return
        }
        
        // make myself a broadcaster
        agoraEngine.setChannelProfile(.liveBroadcasting)
        agoraEngine.setClientRole(.broadcaster)
        
        // enable video module
        agoraEngine.enableVideo()
        agoraEngine.enableAudio()
        // set up video encoding configs
        // https://docs.agora.io/en/3.x/video-calling/basic-features/video-profiles?platform=ios
        encoderConfig = AgoraVideoEncoderConfiguration(size: AgoraVideoDimension1280x720, frameRate: .fps30, bitrate: 2500, orientationMode: .fixedPortrait)
        encoderConfig.minBitrate = 1200
        encoderConfig.mirrorMode = .enabled
        agoraEngine.setVideoEncoderConfiguration(encoderConfig)
       
       // setupLocalVideo()
        setupFaceUnity() // use camera capture
        
        // Set audio route to speaker
        agoraEngine.setDefaultAudioRouteToSpeakerphone(true)
        NetworkManager.shared.generateToken(channelName: channelName) {
        }
    }
    
    // set up local video to render your local camera preview
    private func setupLocalVideo() {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = UserInfo.userId
        // the view to be binded
        videoCanvas.view = localView
        videoCanvas.renderMode = .hidden
        videoCanvas.mirrorMode = .auto
        agoraEngine.setupLocalVideo(videoCanvas)
        agoraEngine.startPreview()
    }
    
    private func setupFaceUnity() {
        beautyViewManager = FUDemoManager.setupFaceUnityDemo(in: self, originY: view.frame.height - 250)
        
        // init process manager
        processingManager = VideoProcessingManager()
        
        // init capturer, it will push pixelbuffer to rtc channel
        let videoConfig = AGMCapturerVideoConfig()
        videoConfig.sessionPreset = AVCaptureSession.Preset.hd1280x720 as NSString
        videoConfig.fps = 30;
        videoConfig.pixelFormat = AGMVideoPixelFormat.NV12
        videoConfig.cameraPosition = .front
        videoConfig.autoRotateBuffers = true
        
        capturerManager = CapturerManager(videoConfig: videoConfig, delegate: processingManager)
        
        // add FaceUnity filter and add to process manager
        videoFilter = FUManager.share()
        processingManager.addVideoFilter(videoFilter)
        capturerManager.startCapture()

        glVideoView = AGMEAGLVideoView(frame: localView.frame)
        glVideoView.renderMode = .hidden
        glVideoView.mirror = true
        localView.addSubview(glVideoView)
        capturerManager.videoView = glVideoView
        // set custom capturer as video source
        agoraEngine.setVideoSource(capturerManager)
    }
    
    @objc func switchCamera(sender: UIButton!) {
        isCameraFront.toggle()
        encoderConfig.mirrorMode = isCameraFront ? .enabled : .auto
        agoraEngine.setVideoEncoderConfiguration(encoderConfig)
        if let capturerManager = capturerManager {
            glVideoView.mirror = isCameraFront
            capturerManager.switchCamera()
            FUManager.share().onCameraChange()
        } else {
            //videoCanvas.mirrorMode =
            agoraEngine.switchCamera()
        }
    }
    
    @objc func publish(sender: UIButton!) {
        if(isPublished) {
            // stop rtmp streaming
            unpublishing = true
            agoraEngine.stopRtmpStream(rtmpURL)
            agoraEngine.stopChannelMediaRelay()
        } else {
            startRtmpStreaming(isTranscoding: true, rtmpURL: rtmpURL)
        }
    }
    
    func startRtmpStreaming(isTranscoding: Bool, rtmpURL: String) {
        if isTranscoding {
            transcoding.videoCodecProfile = .high
            transcoding.videoFramerate = 30
            transcoding.videoBitrate = 2500
            transcoding.size = CGSize(width: 720, height: 1280)
            agoraEngine.startRtmpStream(withTranscoding: rtmpURL, transcoding: transcoding)
        }
        else{
            agoraEngine.startRtmpStreamWithoutTranscoding(rtmpURL)
        }
    }
    
    @objc func pkAction(sender: UIButton!) {
        let alertController = UIAlertController(title: "Join PK", message: "", preferredStyle: .alert)
        alertController.addTextField() { textField -> Void in
            textField.placeholder = "Channel name"
        }
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            let textField = alertController.textFields![0] as UITextField
            let pkChannel = textField.text ?? ""
            self.startPKByChannelMediaRelay(destinationName: pkChannel)
        }
        let cancelAction = UIAlertAction(title: "Cannel", style: .cancel)
        
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    private func startPKByChannelMediaRelay(destinationName: String) {
        // configure source info, channel name defaults to current, and uid defaults to local
        let config = AgoraChannelMediaRelayConfiguration()
        let sourceInfo = AgoraChannelMediaRelayInfo(token: "00690e14a940e56495bbc87423395be503cIAAs7ME0u5eEwJDbhESK42jq1KBj2GjU7DVk8/fMhJDPReLcsooAAAAAIgCDGwMAQ/KvYwQAAQBjLa9jAgBjLa9jAwBjLa9jBABjLa9j")
        sourceInfo.uid = 0
        config.sourceInfo = sourceInfo
        
        // configure target channel info
        let destinationInfo = AgoraChannelMediaRelayInfo(token: "00690e14a940e56495bbc87423395be503cIABSCiRZqi9ZJFog/DK7ohpqwypr9hH1PwfPaGu4rUJicgx+f9gAAAAAIgDM5I8ENPKvYwQAAQBULa9jAgBULa9jAwBULa9jBABULa9j")
        destinationInfo.uid = 0
        config.setDestinationInfo(destinationInfo, forChannelName: destinationName)
        agoraEngine.startChannelMediaRelay(config)
    }
    
    @objc func joinAction(sender: UIButton!) {
        if !isJoined {
            joinChannel()
        } else {
            leaveChannel()
        }
    }
    
    func joinChannel() {
        let option = AgoraRtcChannelMediaOptions()
        option.autoSubscribeAudio = true
        option.autoSubscribeVideo = true
        option.publishLocalAudio = true
        option.publishLocalVideo = true
        agoraEngine.joinChannel(byToken: "00690e14a940e56495bbc87423395be503cIAAs7ME0u5eEwJDbhESK42jq1KBj2GjU7DVk8/fMhJDPReLcsooAAAAAIgCDGwMAQ/KvYwQAAQBjLa9jAgBjLa9jAwBjLa9jBABjLa9j", channelId: channelName, info: nil, uid: 0, options: option)
        
    }
    
    func leaveChannel() {
        let result = agoraEngine.leaveChannel(nil)
        agoraEngine.stopChannelMediaRelay()
        if (result == 0) { isJoined = false }
    }
    
    func checkForPermissions() -> Bool {
        var hasPermissions = false
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermissions = true
        default:
            hasPermissions = requestCameraAccess()
        }
        
        if !hasPermissions {
            return false
        }
        
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasPermissions = true
        default:
            hasPermissions = requestAudioAccess()
        }
        
        return hasPermissions
    }
    
    func requestCameraAccess() -> Bool {
        var hasCameraPermission = false
        let semaphore = DispatchSemaphore(value: 0)
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
            hasCameraPermission = granted
            semaphore.signal()
        })
        semaphore.wait()
        return hasCameraPermission
    }
    
    func requestAudioAccess() -> Bool {
        var hasAudioPermission = false
        let semaphore = DispatchSemaphore(value: 0)
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: { granted in
            hasAudioPermission = granted
            semaphore.signal()
        })
        semaphore.wait()
        return hasAudioPermission
    }
    
    func showMessage(title: String, text: String, delay: Int = 2) -> Void {
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        self.present(alert, animated: true)
        let deadlineTime = DispatchTime.now() + .seconds(delay)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
            alert.dismiss(animated: true, completion: nil)
        })
    }
}

extension ViewController: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurWarning warningCode: AgoraWarningCode) {
        
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        showMessage(title: "Failed", text: "\(errorCode)")
    }
    
    /// callback when a remote user is joinning the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        
        localView.frame = CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width/2, height: 320)
        glVideoView.frame = localView.bounds
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.renderMode = .hidden
        videoCanvas.view = remoteView
        agoraEngine.setupRemoteVideo(videoCanvas)
        
        // remove preivous user from the canvas
        if let existingUid = remoteUid {
            transcoding.removeUser(existingUid)
        }
        remoteUid = uid
        
        // check whether we have enabled transcoding
        // add new user onto the canvas
        let user = AgoraLiveTranscodingUser()
        user.rect = CGRect(x: 720, y: 0, width: 720, height: 1280)
        user.uid = uid
        user.zOrder = 1
        transcoding.add(user)
        
        transcoding.videoFramerate = 30
        transcoding.videoBitrate = 2500
        transcoding.size = CGSize(width: 720 * 2, height: 1280)
        
        agoraEngine.updateRtmpTranscoding(transcoding)
    }
    
    /// callback when the local user joins a specified channel.
    /// @param channel
    /// @param uid uid of local user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        
        isJoined = true
        showMessage(title: "Success", text: "Successfully joined the channel")
        
        // add transcoding user so the video stream will be involved
        // in future RTMP Stream
        let user = AgoraLiveTranscodingUser()
        user.rect = CGRect(origin: .zero, size: CGSize(width: 720, height: 1280))
        user.uid = uid
        user.zOrder = 1
        transcoding.add(user)
    }
    
    /// callback when a remote user is leaving the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param reason reason why this user left, note this event may be triggered when the remote user
    /// become an audience in live broadcasting profile
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = nil
        videoCanvas.renderMode = .hidden
        agoraEngine.setupRemoteVideo(videoCanvas)
        
        // remove user from canvas if current cohost left channel
        if let existingUid = remoteUid {
            transcoding.removeUser(existingUid)
        }
        remoteUid = nil
        
        transcoding.size = CGSize(width: 720, height: 1280)
        agoraEngine.updateRtmpTranscoding(transcoding)
        
        localView.frame = UIScreen.main.bounds
        glVideoView.frame = localView.bounds
    }
    
    /// callback for state of rtmp streaming, for both good and bad state
    /// @param url rtmp streaming url
    /// @param state state of rtmp streaming
    /// @param reason
    func rtcEngine(_ engine: AgoraRtcEngineKit, rtmpStreamingChangedToState url: String, state: AgoraRtmpStreamingState, errorCode: AgoraRtmpStreamingErrorCode) {
        if state == .running {
            if errorCode == .streamingErrorCodeOK {
                showMessage(title: "Notice", text: "RTMP Publish Success")
                isPublished = true
                retried = 0
            }
        } else if state == .failure {
            agoraEngine.stopRtmpStream(rtmpURL)
            isPublished = false
            showMessage(title: "Error", text: "RTMP Publish Failed: \(errorCode.rawValue)")
        } else if state == .idle {
            if unpublishing {
                unpublishing = false
                showMessage(title: "Notice", text: "RTMP Publish Stopped")
                isPublished = false
            }
            else if retried >= MAX_RETRY_TIMES{
                retried = 0
                showMessage(title: "Notice", text: "RTMP Publish Stopped")
                isPublished = false
            }
            else {
                retried += 1
                startRtmpStreaming(isTranscoding: true, rtmpURL: rtmpURL)
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, rtmpStreamingEventWithUrl url: String, eventCode: AgoraRtmpStreamingEvent) {
        if(eventCode == .urlAlreadyInUse) {
            showMessage(title: "Error", text: "The URL is already in Use.")
        }
    }
    
    /// callback when a media relay process state changed
    /// @param state state of media relay
    /// @param error error details if media relay reaches failure state
    func rtcEngine(_ engine: AgoraRtcEngineKit, channelMediaRelayStateDidChange state: AgoraChannelMediaRelayState, error: AgoraChannelMediaRelayError) {
        print("channelMediaRelayStateDidChange: \(state.rawValue) error \(error.rawValue)")
        switch(state){
        case .running:
            localView.frame = CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width/2, height: 320)
            glVideoView.frame = localView.bounds
        case .failure:
            showMessage(title: "Fail", text: "Media Relay Failed: \(error.rawValue)")
        case .idle:
            break
        default:
            break
        }
    }
    
    /// callback when a media relay event received
    /// @param event  event of media relay
    func rtcEngine(_ engine: AgoraRtcEngineKit, didReceive event: AgoraChannelMediaRelayEvent) {
        switch event {
        case .disconnect:
            showMessage(title: "Channel Media Relay Event", text: "User disconnected from the server due to a poor network connection.")
        case .connected:
            showMessage(title: "Channel Media Relay Event", text: "Network reconnected")
        case .joinedSourceChannel:
            showMessage(title: "Channel Media Relay Event", text: "User joined the source channel")
        case .joinedDestinationChannel:
            showMessage(title: "Channel Media Relay Event", text: "User joined the destination channel")
        default:
            break
        }
    }
}
