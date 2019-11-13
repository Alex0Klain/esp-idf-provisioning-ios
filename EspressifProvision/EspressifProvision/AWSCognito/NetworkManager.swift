//
//  APIClient.swift
//  EspressifProvision
//
//  Created by Vikas Chandra on 01/07/19.
//  Copyright © 2019 Espressif. All rights reserved.
//

import Alamofire
import Foundation

class NetworkManager {
    /// A singleton class that manages Network call of the entire application
    static let shared = NetworkManager()

    private init() {}

    func getUserId(completionHandler: @escaping (String?, Error?) -> Void) {
        if let userID = User.shared.userID {
            completionHandler(userID, nil)
        } else {
            User.shared.getAccessToken(completionHandler: { idToken in
                if idToken != nil {
                    User.shared.idToken = idToken
                    let headers: HTTPHeaders = ["Content-Type": "application/json", "Authorization": idToken!]
                    Alamofire.request(Constants.getUserId + "?user_name=" + User.shared.username, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                        if let json = response.result.value as? [String: String] {
                            print("JSON: \(json)")
                            if let userid = json[Constants.userID] {
                                User.shared.userID = userid
                                UserDefaults.standard.set(userid, forKey: Constants.userIDKey)
                                completionHandler(userid, nil)
                                return
                            }
                        }
                        completionHandler(nil, NetworkError.keyNotPresent)
                    }
                } else {
                    completionHandler(nil, NetworkError.emptyToken)
                }
            })
        }
    }

    func addDeviceToUser(parameter: [String: String], completionHandler: @escaping (String?, Error?) -> Void) {
        User.shared.getAccessToken(completionHandler: { idToken in
            if idToken != nil {
                let headers: HTTPHeaders = ["Content-Type": "application/json", "Authorization": idToken!]
                Alamofire.request(Constants.addDevice, method: .put, parameters: parameter, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                    if let error = response.result.error {
                        completionHandler(nil, error)
                        return
                    }
                    if let json = response.result.value as? [String: String] {
                        print("JSON: \(json)")
                        if let requestId = json[Constants.requestID] {
                            completionHandler(requestId, nil)
                            return
                        }
                    }
                    completionHandler(nil, NetworkError.keyNotPresent)
                }
            } else {
                completionHandler(nil, NetworkError.emptyToken)
            }
        })
    }

    func getDeviceList(completionHandler: @escaping ([Device]?, Error?) -> Void) {
        NetworkManager.shared.getUserId { userID, _ in
            if userID != nil {
                User.shared.getAccessToken(completionHandler: { idToken in
                    if idToken != nil {
                        let headers: HTTPHeaders = ["Content-Type": "application/json", "Authorization": idToken!]
                        let url = Constants.getNodes + "?userid=" + userID!
                        Alamofire.request(url, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                            print(response)
                            if let json = response.result.value as? [String: Any], let tempArray = json["nodes"] as? [String] {
                                var deviceList: [Device] = []
                                var nodeList: [Node] = []
                                let serviceGroup = DispatchGroup()
                                for item in tempArray {
                                    var node = Node()
                                    node.node_id = item
                                    nodeList.append(node)
                                    User.shared.associatedNodes = nodeList
                                    serviceGroup.enter()
                                    self.getNodeConfig(nodeID: item, headers: headers, completionHandler: { device, _ in
                                        if let devices = device {
                                            deviceList.append(contentsOf: devices)
                                        }
                                        serviceGroup.leave()
                                    })
                                }
                                serviceGroup.notify(queue: .main) {
                                    completionHandler(deviceList, nil)
                                }
                            } else {
                                completionHandler(nil, NetworkError.keyNotPresent)
                            }
                        }
                    } else {
                        completionHandler(nil, NetworkError.emptyToken)
                    }
                })
            } else {
                completionHandler(nil, CustomError.userIDNotPresent)
            }
        }
    }

    func getNodeConfig(nodeID: String, headers: HTTPHeaders, completionHandler: @escaping ([Device]?, Error?) -> Void) {
        let url = Constants.getNodeConfig + "?nodeid=" + nodeID
        Alamofire.request(url, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            print(response)
            if let json = response.result.value as? [String: Any] {
                completionHandler(JSONParser.parseNodeData(data: json, nodeID: nodeID), nil)
            } else {
                completionHandler(nil, NetworkError.keyNotPresent)
            }
        }
    }

    func deviceAssociationStatus(deviceID: String, requestID: String, completionHandler: @escaping (Bool) -> Void) {
        NetworkManager.shared.getUserId { userID, _ in
            if userID != nil {
                User.shared.getAccessToken(completionHandler: { idToken in
                    if idToken != nil {
                        let url = Constants.checkStatus + "?userid=" + userID! + "&node_id=" + deviceID
                        let headers: HTTPHeaders = ["Content-Type": "application/json", "Authorization": idToken!]
                        Alamofire.request(url + "&request_id=" + requestID + "&user_request=true", method: .get, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                            if let json = response.result.value as? [String: String], let status = json["request_status"] as? String {
                                print(json)
                                if status == "confirmed" {
                                    completionHandler(true)
                                    return
                                }
                            }
                            completionHandler(false)
                        }
                    } else {
                        completionHandler(false)
                    }
                })
            } else {
                completionHandler(false)
            }
        }
    }

    func updateThingShadow(nodeID: String, parameter: [String: Any]) {
        NetworkManager.shared.getUserId { userID, _ in
            if userID != nil {
                User.shared.getAccessToken(completionHandler: { idToken in
                    if idToken != nil {
                        let url = Constants.updateThingsShadow + "?nodeid=" + nodeID
                        let headers: HTTPHeaders = ["Content-Type": "application/json", "Authorization": idToken!]
                        Alamofire.request(url, method: .put, parameters: parameter, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                            print(parameter)
                            print(response.result.value)
                        }
                    } else {}
                })
            }
        }
    }

    func getDeviceThingShadow(nodeID: String, completionHandler: @escaping ([String: Any]?) -> Void) {
        NetworkManager.shared.getUserId { userID, _ in
            if userID != nil {
                User.shared.getAccessToken(completionHandler: { idToken in
                    if idToken != nil {
                        let url = Constants.getDeviceShadow + "?nodeid=" + nodeID
                        let headers: HTTPHeaders = ["Content-Type": "application/json", "Authorization": idToken!]
                        Alamofire.request(url, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
                            if let json = response.result.value as? [String: Any] {
                                completionHandler(json)
                            }
                            print(response.result.value)
                            completionHandler(nil)
                        }
                    } else {
                        completionHandler(nil)
                    }
                })
            } else {
                completionHandler(nil)
            }
        }
    }
}
