import Foundation
import BigInt
import SwiftKeccak
import secp256k1

public enum Utils { }

public extension Utils {
    
    enum KeyUtils {
        
        public static func getPublicKey(from privateKey: String) throws -> String {
            
            let privateKeyBytes = try privateKey.lowercased().removeHexPrefix().bytes
            
            let secp256k1PrivateKey = try secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes, format: .uncompressed)
            
            let publicKey = secp256k1PrivateKey.publicKey.rawRepresentation.subdata(in: 1..<65)
            
            return String(bytes: publicKey)
        }
        
        public static func getEthereumAddress(from publicKey: String) throws -> String {
            
            let publicKeyBytes = try publicKey.lowercased().bytes
            
            let publicKeyData = Data(bytes: publicKeyBytes, count: 64)
            
            let hash = publicKeyData.keccak()
            
            let address = hash.subdata(in: 12..<hash.count)
            
            let ethereumAddress = String(bytes: address).addHexPrefix()
            
            return ethereumAddress
        }
        
        public static func sign(data: Data, with privateKey: String) throws -> Signature {
            
            let privateKeyBytes = try privateKey.lowercased().removeHexPrefix().bytes
            
            let secp256k1PrivateKey = try secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes, format: .uncompressed)
            
            // MARK: - Make use of simplified syntax
            
            //        let keccakData = data.keccak()
            //
            //        let digests = SHA256.convert(keccakData.bytes)
            //
            //        let signature = try secp256k1PrivateKey.ecdsa.signature(for: digests)
            //
            
            guard let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY)) else {
                print("Failed to sign message: invalid context.")
                throw ResponseError.errorSigningTransaction
            }
            
            defer {
                secp256k1_context_destroy(context)
            }
            
            let keccakData = data.keccak()
            
            let keccakDataPointer = (keccakData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
            
            let privateKeyPointer = (secp256k1PrivateKey.rawRepresentation as NSData).bytes.assumingMemoryBound(to: UInt8.self)
            
            let signaturePointer = UnsafeMutablePointer<secp256k1_ecdsa_recoverable_signature>.allocate(capacity: 1)
            
            defer {
                signaturePointer.deallocate()
            }
            
            guard secp256k1_ecdsa_sign_recoverable(context, signaturePointer, keccakDataPointer, privateKeyPointer, nil, nil) == 1 else {
                print("Failed to sign message: recoverable ECDSA signature creation failed.")
                throw ResponseError.errorSigningTransaction
            }
            
            let outputDataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
            
            defer {
                outputDataPointer.deallocate()
            }
            
            var recoverableID: Int32 = 0
            
            secp256k1_ecdsa_recoverable_signature_serialize_compact(context, outputDataPointer, &recoverableID, signaturePointer)
            
            let outputWithRecoverableIDPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65)
            
            defer {
                outputWithRecoverableIDPointer.deallocate()
            }
            
            outputWithRecoverableIDPointer.assign(from: outputDataPointer, count: 64)
            outputWithRecoverableIDPointer.advanced(by: 64).pointee = UInt8(recoverableID)
            
            let signedData = Data(bytes: outputWithRecoverableIDPointer, count: 65)
            
            let signature = Signature(signedData)
            
            return signature
        }
    }
}

public extension Utils {
    
    enum Formatter {
        
        static var currencyFormatter: NumberFormatter {
            let currencyFormatter = NumberFormatter()
            currencyFormatter.usesGroupingSeparator = true
            currencyFormatter.numberStyle = .currency
            currencyFormatter.currencySymbol = "Ξ"
            currencyFormatter.locale = Locale.current
            return currencyFormatter
        }
        
    }
}

public extension Utils {
    
    enum Converter {
        
        public enum EthereumUnits {
            case eth
            case wei
            case gwei
        }
        
        public static func convert(value: String, from: EthereumUnits, to: EthereumUnits) -> String {
            
            switch from {
            case .eth:
                switch to {
                case .eth:
                    return value
                case .wei:
                    return transformDown(value: value, base: 18)
                case .gwei:
                    return transformDown(value: value, base: 9)
                }
            case .wei:
                switch to {
                case .eth:
                    return transformUp(value: value, base: 18)
                case .wei:
                    return value
                case .gwei:
                    return transformUp(value: value, base: 9)
                }
                
            case .gwei:
                switch to {
                case .eth:
                    return transformUp(value: value, base: 9)
                case .wei:
                    return transformDown(value: value, base: 9)
                case .gwei:
                    return value
                }
                
            }
        }
        
        private static func transformUp(value: String, base: Int) -> String {
            
            var result = "0."
            
            if value.count < base {
                let zerosLeft = String(repeating: "0", count: base - value.count)
                result.append(contentsOf: zerosLeft + value)
            } else {
                let integerPartIndex = value.index(value.startIndex, offsetBy: value.count - base)
                let integerPart = value[value.startIndex..<integerPartIndex]
                let other = String(value[integerPartIndex...])
                result.append(contentsOf: other)
                
                if integerPart != "" {
                    result.removeFirst()
                    result = integerPart + result
                }
            }
            
            while result.last == "0" {
                result.removeLast()
            }
            
            return result
            
        }
        
        private static func transformDown(value: String, base: Int) -> String {
            
            // check if value is integer
            if value.range(of: "[0-9]*[.]", options: [.regularExpression, .anchored]) == nil {
                return value + String(repeating: "0", count: base)
            } else if value.first == "0" { // if value is not integer and < 1
                let fractionalPartIndex = value.index(value.startIndex, offsetBy: 2)
                let fractionalPart = value[fractionalPartIndex...]
                let additionalZeros = String(repeating: "0", count: base - fractionalPart.count)
                return fractionalPart + additionalZeros
            } else { // if value is not integer and > 1
                let indexOfDot = value.firstIndex(of: ".")!
                let integerPart = value[value.startIndex..<indexOfDot]
                let fractionalPartIndex = value.index(after: indexOfDot)
                let fractionalPart = value[fractionalPartIndex...]
                let additionalZeros = String(repeating: "0", count: base - fractionalPart.count)
                return integerPart + fractionalPart + additionalZeros
            }
            
        }
        
    }
}




