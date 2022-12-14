//
//  NetworkManager.swift
//  Scene-Examples
//
//  Created by zhaoyongqiang on 2021/11/19.
//

import UIKit

class NetworkManager {
    enum HTTPMethods: String {
        case GET = "GET"
        case POST = "POST"
    }
        
    typealias SuccessClosure = ([String: Any]) -> Void
    typealias FailClosure = (String) -> Void
    
    private lazy var sessionConfig: URLSessionConfiguration = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Content-Type": "application/json"]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return config
    }()
    
    static let shared = NetworkManager()
    private init() { }
    private let baseUrl = "https://toolbox.bj2.agoralab.co/v1/token/generate"
    
    
    func generateToken(channelName: String, uid: UInt = UserInfo.userId, success: @escaping () -> Void) {
        generateToken(channelName: channelName, uid: uid) { _ in
            success()
        }
    }
    
    func generateToken(channelName: String, uid: UInt = UserInfo.userId, success: @escaping (String?) -> Void) {
        if KeyCenter.Certificate == nil || KeyCenter.Certificate?.isEmpty == true {
            success(nil)
            return
        }
        let params = ["appCertificate": KeyCenter.Certificate ?? "",
                      "appId": KeyCenter.AppId,
                      "channelName": channelName,
                      "expire": 90000,
                      "src": "iOS",
                      "ts": "".timeStamp,
                      "type": 1,
                      "role": 1,
                      "uid": "\(uid)"] as [String : Any]
        NetworkManager.shared.postRequest(urlString: "https://test-toolbox.bj2.agoralab.co/v1/token/generate", params: params, success: { response in
            let data = response["data"] as? [String: String]
            let token = data?["token"]
            KeyCenter.Token = token
            print(response)
            success(token)
        }, failure: { error in
            print(error)
            success(nil)
        })
    }
    
    func getRequest(urlString: String, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: nil, method: .GET, success: success, failure: failure)
        }
    }
    func postRequest(urlString: String, params: [String: Any]?, success: SuccessClosure?, failure: FailClosure?) {
        DispatchQueue.global().async {
            self.request(urlString: urlString, params: params, method: .POST, success: success, failure: failure)
        }
    }
    
    private func request(urlString: String,
                         params: [String: Any]?,
                         method: HTTPMethods,
                         success: SuccessClosure?,
                         failure: FailClosure?) {
        let session = URLSession(configuration: sessionConfig)
        guard let request = getRequest(urlString: urlString,
                                       params: params,
                                       method: method,
                                       success: success,
                                       failure: failure) else { return }
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.checkResponse(response: response, data: data, success: success, failure: failure)
            }
        }.resume()
    }
    
    private func getRequest(urlString: String,
                            params: [String: Any]?,
                            method: HTTPMethods,
                            success: SuccessClosure?,
                            failure: FailClosure?) -> URLRequest? {
        
        let string = urlString.hasPrefix("http") ? urlString : baseUrl.appending(urlString)
        guard let url = URL(string: string) else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if method == .POST {
            request.httpBody = try? JSONSerialization.data(withJSONObject: params ?? [], options: .sortedKeys)//convertParams(params: params).data(using: .utf8)
        }
        let curl = request.cURL(pretty: true)
        debugPrint("curl == \(curl)")
        return request
    }
    
    private func convertParams(params: [String: Any]?) -> String {
        guard let params = params else { return "" }
        let value = params.map({ String(format: "%@=%@", $0.key, "\($0.value)") }).joined(separator: "&")
        return value
    }
    
    private func checkResponse(response: URLResponse?, data: Data?, success: SuccessClosure?, failure: FailClosure?) {
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...201:
                if let resultData = data {
                    let result = String(data: resultData, encoding: .utf8)
                    print(result ?? "")
                    success?(JSONObject.toDictionary(jsonString: result ?? ""))
                } else {
                    failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
                }
            default:
                failure?("Error in the request status code \(httpResponse.statusCode), response: \(String(describing: response))")
            }
        }
    }
}

extension URLRequest {
    public func cURL(pretty: Bool = false) -> String {
        let newLine = pretty ? "\\\n" : ""
        let method = (pretty ? "--request " : "-X ") + "\(httpMethod ?? "GET") \(newLine)"
        let url: String = (pretty ? "--url " : "") + "\'\(url?.absoluteString ?? "")\' \(newLine)"
        
        var cURL = "curl "
        var header = ""
        var data: String = ""
        
        if let httpHeaders = allHTTPHeaderFields, httpHeaders.keys.count > 0 {
            for (key,value) in httpHeaders {
                header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
            }
        }
        
        if let bodyData = httpBody, let bodyString = String(data: bodyData, encoding: .utf8), !bodyString.isEmpty {
            data = "--data '\(bodyString)'"
        }
        
        cURL += method + url + header + data
        
        return cURL
    }
}

extension String {
    var timeStamp: String {
        let date = Date()
        let timeInterval = date.timeIntervalSince1970
        let millisecond = CLongLong(timeInterval * 1000)
        return "\(millisecond)"
    }
}

class JSONObject {
    /// ???????????????
    static func toModel<T: Codable>(_ type: T.Type, value: Any?) -> T? {
        guard let value = value else { return nil }
        return toModel(type, value: value)
    }
    /// ???????????????
    static func toModel<T: Codable>(_ type: T.Type, value: Any) -> T? {
        guard let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try? decoder.decode(type, from: data)
    }
    /// JSON??????????????????
    static func toModel<T: Codable>(_ type: T.Type, value: String?) -> T? {
        guard let value = value else { return nil }
        return toModel(type, value: value)
    }
    /// JSON??????????????????
    static func toModel<T: Codable>(_ type: T.Type, value: String) -> T? {
        let decoder = JSONDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "+Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        guard let t = try? decoder.decode(T.self, from: value.data(using: .utf8)!) else { return nil }
        return t
    }
    /// ?????????JSON?????????
    static func toJson<T: Codable>(_ model: T) -> [String: Any] {
        let jsonString = toJsonString(model) ?? ""
        return toDictionary(jsonString: jsonString)
    }
    /// ?????????JSON???????????????
    static func toJsonArray<T: Codable>(_ model: T) -> [[String: Any]]? {
        let jsonString = toJsonString(model) ?? ""
        return toArray(jsonString: jsonString)
    }
    /// ?????????JSON?????????
    static func toJsonString<T: Codable>(_ model: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(model) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    /// JSON??????????????????
    static func toDictionary(jsonString: String) -> [String: Any] {
        guard let jsonData = jsonString.data(using: .utf8) else { return [:] }
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers), let result = dict as? [String: Any] else { return [:] }
        return result
    }
    /// JSON??????????????????
    static func toDictionary(jsonStr: String) -> [String: String] {
        guard let jsonData = jsonStr.data(using: .utf8) else { return [:] }
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers), let result = dict as? [String: Any] else { return [:] }
        var data = [String: String]()
        for item in result {
            data[item.key] = "\(item.value)"
        }
        return data
    }
    /// JSON??????????????????
    static func toArray(jsonString: String) -> [[String: Any]]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        guard let array = try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers), let result = array as? [[String: Any]] else { return nil }
        return result
    }
    /// ?????????JSON?????????
    static func toJsonString(dict: [String: Any]?) -> String? {
        guard let dict = dict else { return nil }
        if (!JSONSerialization.isValidJSONObject(dict)) {
            print("????????????????????????")
            return nil
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else { return nil }
        guard let jsonString = String(data: data, encoding: .utf8) else { return nil }
        return jsonString
    }
    /// ???????????????JSON?????????
    static func toJsonString(array: [[String: Any]?]?) -> String? {
        guard let array = array else { return nil }
        var jsonString = "["
        var i = 0
        let count = array.count
        for dict in array {
            guard let dict = dict else { return nil }
            if (!JSONSerialization.isValidJSONObject(dict)) {
                print("????????????????????????")
                return nil
            }
            guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else { return nil }
            guard let tmp = String(data: data, encoding: .utf8) else { return nil }
            jsonString.append(tmp)
            if i < count - 1 {
                jsonString.append(",")
            }
            i = i + 1
        }
        jsonString.append("]")
        return jsonString
    }
}

extension String {
    func toArray() -> [[String: Any]]? {
        JSONObject.toArray(jsonString: self)
    }
    func toDictionary() -> [String : String] {
       JSONObject.toDictionary(jsonStr: self)
    }
}
