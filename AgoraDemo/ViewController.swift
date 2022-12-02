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
    
    var beautyViewManager: FUContainerManager!
    var localView: UIView!
    var remoteView: UIView!
    var joinButton: UIButton!
    
    // Choose to be broadcaster or audience
    var role: UISegmentedControl!
    var joined: Bool = false
    
    // The main entry point for Video SDK
    var agoraEngine: AgoraRtcEngineKit!
    // By default, set the current user role to broadcaster to both send and receive streams.
    var userRole: AgoraClientRole = .broadcaster
    
    let appID = "Your app ID"
    var token = "Your temp access token"
    var channelName = "Your channel name"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initViews()
        initializeAgoraEngine()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        remoteView.frame = CGRect(x: 20, y: 50, width: 350, height: 330)
        localView.frame = CGRect(x: 20, y: 400, width: 350, height: 330)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        leaveChannel()
        DispatchQueue.global(qos: .userInitiated).async {AgoraRtcEngineKit.destroy()}
    }
    
    func initViews() {
        remoteView = UIView()
        self.view.addSubview(remoteView)
        
        localView = UIView()
        self.view.addSubview(localView)
        
        
        joinButton = UIButton(type: .custom)
        joinButton.frame = CGRect(x: 140, y: 700, width: 100, height: 50)
        joinButton.layer.cornerRadius = 25
        joinButton.clipsToBounds = true
        joinButton.backgroundColor = .blue
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.setTitle("Join", for: .normal)
        
        joinButton.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        self.view.addSubview(joinButton)
        
        // Selector to be the host or the audience
        role = UISegmentedControl(items: ["Broadcast", "Audience"])
        role.frame = CGRect(x: 20, y: 740, width: 350, height: 40)
        role.selectedSegmentIndex = 0
        role.addTarget(self, action: #selector(roleAction), for: .valueChanged)
        self.view.addSubview(role)
        
        // FaceUnity UI
        beautyViewManager = FUContainerManager(targetController: self, originY: view.frame.height - 250)
        
    }
    
    func initializeAgoraEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = appID
        agoraEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
    }
    
    func setupLocalVideo() {
        // Enable the video module
        agoraEngine.enableVideo()
        // Start the local video preview
        agoraEngine.startPreview()
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.renderMode = .hidden
        videoCanvas.view = localView
        // Set the local video view
        agoraEngine.setupLocalVideo(videoCanvas)
    }
    
    @objc func buttonAction(sender: UIButton!) {
        if !joined {
            joinChannel()
        } else {
            leaveChannel()
        }
        
        joinButton.setTitle(joined ? "Leave" : "Join", for: .normal)
    }
    
    func joinChannel() {
        if !checkForPermissions() {
            showMessage(title: "Error", text: "Permissions were not granted")
            return
        }
        
        if self.userRole == .broadcaster {
            agoraEngine.setClientRole(.broadcaster)
            setupLocalVideo()
        } else {
            agoraEngine.setClientRole(.audience)
        }
        
        agoraEngine.setChannelProfile(.liveBroadcasting)
        
        // Join the channel with a temp token. Pass in your token and channel name here
        let result = agoraEngine.join .joinChannel(
            byToken: token, channelId: channelName, uid: 0, mediaOptions: option,
            joinSuccess: { (channel, uid, elapsed) in }
        )
        
        if result == 0 {
            joined = true
            showMessage(title: "Success", text: "Successfully joined the channel as \(userRole)")
        }
    }
    
    func leaveChannel() {
        agoraEngine.stopPreview()
        let result = agoraEngine.leaveChannel(nil)
        // Check if leaving the channel was successful and set joined Bool accordingly
        if (result == 0) { joined = false }
    }
    
    @objc func roleAction(sender: UISegmentedControl!) {
        self.userRole = sender.selectedSegmentIndex == 0 ? .broadcaster : .audience
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
