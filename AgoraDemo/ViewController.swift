//
//  ViewController.swift
//  AgoraDemo
//
//  Created by Xuan Trung on 30/11/2022.
//

import AVFoundation
import UIKit

class ViewController: UIViewController {
    
// The video feed for the local user is displayed here
    var localView: UIView!
    // The video feed for the remote user is displayed here
    var remoteView: UIView!
    // Click to join or leave a call
    var joinButton: UIButton!
    // Choose to be broadcaster or audience
    var role: UISegmentedControl!
    // Track if the local user is in a call
    var joined: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        initViews()
    }

    func joinChannel() -> Bool { return true }

    func leaveChannel() {}

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        remoteView.frame = CGRect(x: 20, y: 50, width: 350, height: 330)
        localView.frame = CGRect(x: 20, y: 400, width: 350, height: 330)
    }

    func initViews() {
        // Initializes the remote video view. This view displays video when a remote host joins the channel.
        remoteView = UIView()
        self.view.addSubview(remoteView)
        // Initializes the local video window. This view displays video when the local user is a host.
        localView = UIView()
        self.view.addSubview(localView)
        //  Button to join or leave a channel
        joinButton = UIButton(type: .system)
        joinButton.frame = CGRect(x: 140, y: 700, width: 100, height: 50)
        joinButton.setTitle("Join", for: .normal)

        joinButton.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        self.view.addSubview(joinButton)

        // Selector to be the host or the audience
        role = UISegmentedControl(items: ["Broadcast", "Audience"])
        role.frame = CGRect(x: 20, y: 740, width: 350, height: 40)
        role.selectedSegmentIndex = 0
        role.addTarget(self, action: #selector(roleAction), for: .valueChanged)
        self.view.addSubview(role)
    }

    @objc func buttonAction(sender: UIButton!) {
        if !joined {
            joinChannel()
            // Check if successfully joined the channel and set button title accordingly
            if joined { joinButton.setTitle("Leave", for: .normal) }
        } else {
            leaveChannel()
            // Check if successfully left the channel and set button title accordingly
            if !joined { joinButton.setTitle("Join", for: .normal) }
        }
    }

    @objc func roleAction(sender: UISegmentedControl!) {}
}

