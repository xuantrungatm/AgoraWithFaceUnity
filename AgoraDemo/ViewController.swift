//
//  ViewController.swift
//  AgoraDemo
//
//  Created by Xuan Trung on 30/11/2022.
//

import AVFoundation
import UIKit
import AgoraRtcKit
import AGMCapturer
import AGMRenderer

class ViewController: UIViewController {
    
    var beautyViewManager: FUDemoManager!
    var localView: UIView!
    var remoteView: UIView!
    var joinButton: UIButton!
    var switchCameraButton: UIButton!
    
    let appID = ""
    var token = "Your temp access token"
    var channelName = "iOS_test"
    
    var glVideoView: AGMEAGLVideoView!
    var videoFilter: FUManager!
    var capturerManager: CapturerManager!
    var processingManager: VideoProcessingManager!
    var agoraEngine: AgoraRtcEngineKit!
    var joined: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initViews()
        initializeAgoraEngine()
        initFaceUnity()
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
        joinButton.frame = CGRect(x: 140, y: UIScreen.main.bounds.height - 100, width: 100, height: 50)
        joinButton.layer.cornerRadius = 25
        joinButton.clipsToBounds = true
        joinButton.backgroundColor = .blue
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.setTitle("Join", for: .normal)
        joinButton.addTarget(self, action: #selector(joinAction), for: .touchUpInside)
        view.addSubview(joinButton)
        
        switchCameraButton = UIButton(type: .custom)
        switchCameraButton.frame = CGRect(x: 16, y: 50, width: 80, height: 40)
        switchCameraButton.layer.cornerRadius = 20
        switchCameraButton.clipsToBounds = true
        switchCameraButton.backgroundColor = .blue
        switchCameraButton.setTitleColor(.white, for: .normal)
        switchCameraButton.setTitle("Camera", for: .normal)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        view.addSubview(switchCameraButton)
    }
    
    func initializeAgoraEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = appID
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
        let resolution = AgoraVideoDimension1280x720
        let fps = AgoraVideoFrameRate.fps30
        let orientation = AgoraVideoOutputOrientationMode.fixedPortrait
        let encoderConfig = AgoraVideoEncoderConfiguration(size: resolution, frameRate: fps, bitrate: AgoraVideoBitrateStandard, orientationMode: orientation)
        agoraEngine.setVideoEncoderConfiguration(encoderConfig)
        
        // set up local video to render your local camera preview
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = UserInfo.userId
        // the view to be binded
        videoCanvas.view = localView
        videoCanvas.renderMode = .hidden
        agoraEngine.setupLocalVideo(videoCanvas)
        agoraEngine.startPreview()
        
        // Set audio route to speaker
        agoraEngine.setDefaultAudioRouteToSpeakerphone(true)
        
    }
    
    private func initFaceUnity() {
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
        // self.processingManager.enableFilter = NO;
        
        capturerManager.startCapture()

        glVideoView = AGMEAGLVideoView(frame: localView.frame)
        localView.addSubview(glVideoView)
        capturerManager.videoView = glVideoView
        // set custom capturer as video source
        agoraEngine.setVideoSource(capturerManager)
    }
    
    @objc func switchCamera(sender: UIButton!) {
        capturerManager.switchCamera()
        FUManager.share().onCameraChange()
    }
    
    @objc func joinAction(sender: UIButton!) {
        if !joined {
            joinChannel()
        } else {
            leaveChannel()
        }
        
        joinButton.setTitle(joined ? "Leave" : "Join", for: .normal)
    }
    
    func joinChannel() {
        
        // start joining channel
        // 1. Users can only see each other after they join the
        // same channel successfully using the same app id.
        // 2. If app certificate is turned on at dashboard, token is needed
        // when joining channel. The channel name and uid used to calculate
        // the token has to match the ones used for channel join
        let option = AgoraRtcChannelMediaOptions()
        let result = agoraEngine.joinChannel(byToken: token, channelId: channelName, info: nil, uid: UserInfo.userId, options: option)
        if result == 0 {
            joined = true
            showMessage(title: "Success", text: "Successfully joined the channel")
        }
    }
    
    func leaveChannel() {
        let result = agoraEngine.leaveChannel(nil)
        if (result == 0) { joined = false }
    }
    
    func checkForPermissions() -> Bool {
        var hasPermissions = false
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: hasPermissions = true
        default: hasPermissions = requestCameraAccess()
        }
        // Break out, because camera permissions have been denied or restricted.
        if !hasPermissions { return false }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: hasPermissions = true
        default: hasPermissions = requestAudioAccess()
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
    // Callback called when a new host joins the channel
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.renderMode = .hidden
        videoCanvas.view = remoteView
        agoraEngine.setupRemoteVideo(videoCanvas)
    }
}
