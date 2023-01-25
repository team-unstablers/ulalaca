//
//  Encodable+toJSON.swift
//  sessionprojector
//
//  Created by Gyuhwan Park on 2023/01/25.
//

import Foundation

public extension Encodable {
    /**
     serializes Encodable object to JSON
     */
    func toJSON() throws -> String {
        let json = try JSONEncoder().encode(self)
        return String(data: json, encoding: .utf8)!
    }
}
