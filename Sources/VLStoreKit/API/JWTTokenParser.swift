//
//  JWTTokenParser.swift
//  VLStoreKit
//
//  Created by Gaurav Vig on 17/02/22.
//

import Foundation

struct JWTTokenParser {
    func jwtTokenParser(jwtToken:String) -> UserIdentity? {
        guard let data = JWTTokenDecoder().decode(jwtToken: jwtToken) else { return nil }
        do {
            let userIdentity = try JSONDecoder().decode(UserIdentity.self, from: data)
            return userIdentity
        }
        catch {
            return nil
        }
    }
}

struct JWTTokenDecoder {
    func decode(jwtToken jwt: String) -> Data? {
        if jwt.isEmpty { return nil }
        let segments = jwt.components(separatedBy: ".")
        return decodeJWTPart(segments.count > 0 ? segments[1] : segments[0])
    }
    
    private func decodeJWTPart(_ value: String) -> Data? {
        guard let bodyData = base64UrlDecode(value) else { return nil }
        return bodyData
    }
    
    private func base64UrlDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let length = Double(base64.lengthOfBytes(using: String.Encoding.utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
            base64 = base64 + padding
        }
        return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
    }
}
