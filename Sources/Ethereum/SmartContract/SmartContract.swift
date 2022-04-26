import Foundation
import SwiftKeccak
import BigInt

protocol SmartContractProtocol {
    
    init(abi: String, address: String)
    
    // MARK: - write an extension with default realisation
    func method<T: Codable>(name: String, params: T) -> Transaction
    
    var allMethods: [String] { get }
    
    var allEvents: [String] { get }
    
}

extension SmartContractProtocol {
    // base realisation of smart contracts (call method)
}


public struct SmartContractMethod {
    let name: String
    let params: [SmartContractParam]
    
    var abiData: Data? {
        return try? ABIEncoder.encode(method: self)
    }
}

public struct SmartContractParam {
    let name: String
    let value: SmartContractValue
}

public enum SmartContractValue {
    
    case address(_ value: String)
    
    case uint(bits: UInt16 = 256, _ value: BigUInt)
    
    case int(bits: UInt16 = 256, _ value: BigInt)
    
    case bool(_ value: Bool)
    
    case bytes(_ value: Data)
    
    case string(_ value: String)
    
    case array(_ values: [SmartContractValue])
    
    var stringValue: String {
        switch self {
        case .address(_):
            return "address"
        case .uint(bits: let bits, _: _):
            return "uint\(bits)"
        case .int(bits: let bits, _: _):
            return "int\(bits)"
        case .bool(_):
            return "bool"
        case .bytes(_):
            return "bytes"
        case .string(_):
            return "string"
        case .array(let values):
            return !values.isEmpty ? values[0].stringValue + "[]" : "emptyArray"
        }
    }
    
    var isDynamic: Bool {
        switch self {
        case .address(_):
            return false
        case .uint(_, _):
            return false
        case .int(_, _):
            return false
        case .bool(_):
            return false
        case .bytes(_):
            return true
        case .string(_):
            return true
        case .array(_):
            return true
        }
    }
}

