//
//  ViewController.swift
//  AgoraDemo
//
//  Created by Xuan Trung on 30/11/2022.
//

import AVFoundation
import UIKit
import AgoraRtcKit

class ViewController: UIViewController {
    
    var beautyViewManager: FUDemoManager!
    var localView: UIView!
    var remoteView: UIView!
    var joinButton: UIButton!
    var publishButton: UIButton!
    var switchCameraButton: UIButton!
    
    let channelName = "agora_42434"
    let rtmpURL = "rtmp://entrypoint-app.evgcdn.net/live/f8477470"
    
    var glVideoView: AGMEAGLVideoView!
    var videoFilter: FUManager!
    var capturerManager: CapturerManager!
    var processingManager: VideoProcessingManager!
    var agoraEngine: AgoraRtcEngineKit!
    
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
        agoraEngine.setVideoSource(nil)
        leaveChannel()
        AgoraRtcEngineKit.destroy()
    }
    
    func initViews() {
        localView = UIView(frame: UIScreen.main.bounds)
        view.addSubview(localView)
        
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
        
        isJoined = false
        isPublished = false
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
        let encoderConfig = AgoraVideoEncoderConfiguration(size: AgoraVideoDimension1280x720, frameRate: .fps30, bitrate: 3420, orientationMode: .fixedPortrait)
        encoderConfig.minFrameRate = 15
        encoderConfig.minBitrate = 1710
        agoraEngine.setVideoEncoderConfiguration(encoderConfig)
       
        setupLocalVideo()
       // setupFaceUnity() // use camera capture
        
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
        capturerManager.switchCamera()
       // FUManager.share().onCameraChange()
    }
    
    @objc func publish(sender: UIButton!) {
        if(isPublished) {
            // stop rtmp streaming
            unpublishing = true
            agoraEngine.stopRtmpStream(rtmpURL)
        } else {
            startRtmpStreaming(isTranscoding: true, rtmpURL: rtmpURL)
        }
    }
    
    func startRtmpStreaming(isTranscoding: Bool, rtmpURL: String) {
        if isTranscoding {
            transcoding.size = CGSize(width: 720, height: 1280)
            agoraEngine.startRtmpStream(withTranscoding: rtmpURL, transcoding: transcoding)
        }
        else{
            agoraEngine.startRtmpStreamWithoutTranscoding(rtmpURL)
        }
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
        let result = agoraEngine.joinChannel(byToken: KeyCenter.Token, channelId: channelName, info: nil, uid: UserInfo.userId, options: option)
        if result == 0 {
            isJoined = true
            showMessage(title: "Success", text: "Successfully joined the channel")
        }
    }
    
    func leaveChannel() {
        let result = agoraEngine.leaveChannel(nil)
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
        
    }
    
    /// callback when a remote user is joinning the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
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
        let transcodingEnabled = true
        if(transcodingEnabled){
            // add new user onto the canvas
            let user = AgoraLiveTranscodingUser()
            user.rect = CGRect(origin: .zero, size: AgoraVideoDimension1280x720)
            user.uid = uid
            self.transcoding.add(user)
            // remember you need to call setLiveTranscoding again if you changed the layout
            agoraEngine.updateRtmpTranscoding(transcoding)
        }
    }
    
    /// callback when the local user joins a specified channel.
    /// @param channel
    /// @param uid uid of local user
    /// @param elapsed time elapse since current sdk instance join the channel in ms
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        isJoined = true
        
        // add transcoding user so the video stream will be involved
        // in future RTMP Stream
        let user = AgoraLiveTranscodingUser()
        user.rect = CGRect(origin: .zero, size: CGSize(width: 720, height: 1280))
        user.uid = uid
        transcoding.add(user)
    }
    
    /// callback when a remote user is leaving the channel, note audience in live broadcast mode will NOT trigger this event
    /// @param uid uid of remote joined user
    /// @param reason reason why this user left, note this event may be triggered when the remote user
    /// become an audience in live broadcasting profile
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        // to unlink your view from sdk, so that your view reference will be released
        // note the video will stay at its last frame, to completely remove it
        // you will need to remove the EAGL sublayer from your binded view
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        // the view to be binded
        videoCanvas.view = nil
        videoCanvas.renderMode = .hidden
        agoraEngine.setupRemoteVideo(videoCanvas)
        
        // check whether we have enabled transcoding
        let transcodingEnabled = true
        if(transcodingEnabled){
            // remove user from canvas if current cohost left channel
            if let existingUid = remoteUid {
                transcoding.removeUser(existingUid)
            }
            remoteUid = nil
            // remember you need to call setLiveTranscoding again if you changed the layout
            agoraEngine.updateRtmpTranscoding(transcoding)
        }
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
            if errorCode == .streamingErrorCodeInternalServerError
                || errorCode == .streamingErrorCodeStreamNotFound
                || errorCode == .streamPublishErrorNetDown
                || errorCode == .streamingErrorCodeRtmpServerError
                || errorCode == .streamingErrorCodeConnectionTimeout {
                showMessage(title: "Error", text: "RTMP Publish Failed: \(errorCode.rawValue)")
            }
            else{
                unpublishing = true
            }
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
    
    /// callback when live transcoding is properly updated
    func rtcEngineTranscodingUpdated(_ engine: AgoraRtcEngineKit) {
        
    }
}
