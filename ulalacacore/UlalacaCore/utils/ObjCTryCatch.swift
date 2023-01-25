//
//  ULObjCTryCatch.swift
//  UlalacaCore
//
//  Created by Gyuhwan Park on 2023/01/25.
//

import Foundation

public struct NestedNSExceptionError: Swift.Error {
    
    public let exception: NSException
       
    public init(exception: NSException) {
        self.exception = exception
    }
}

extension NestedNSExceptionError: LocalizedError {
    public var errorDescription: String? {
        get {
            return "[NestedNSExceptionError] \(exception.description)"
        }
    }
}

public struct ObjC {
    public static func evaluate(_ block: () -> Void) throws {
        let exception = ULObjCTryCatch {
            block()
        }
        
        if let exception = exception {
            throw NestedNSExceptionError(exception: exception)
        }
    }
}
