//
//  UserInfo.swift
//  AgoraDemo
//
//  Created by Xuan Trung on 05/12/2022.
//

import Foundation

struct UserInfo {
    static var userId: UInt {
        let id = UserDefaults.standard.integer(forKey: "UserId")
        if id > 0 {
            return UInt(id)
        }
        let user = UInt(arc4random_uniform(8999999) + 1000000)
        UserDefaults.standard.set(user, forKey: "UserId")
        UserDefaults.standard.synchronize()
        return user
    }
    static var uid: String {
        "\(userId)"
    }
}
