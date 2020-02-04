//
//  Device.swift
//  EspressifProvision
//
//  Created by Vikas Chandra on 13/09/19.
//  Copyright © 2019 Espressif. All rights reserved.
//

import Foundation

import Foundation

class Device: Equatable {
    static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.attributes == rhs.attributes && lhs.params == rhs.params && lhs.name == rhs.name
    }

    var name: String?
    var type: String?
    var node_id: String?
    var attributes: [Attribute]?
    var params: [Params]?
    var isConnected = false
    weak var node: Node?
}
