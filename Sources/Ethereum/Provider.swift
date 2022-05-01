import Foundation

public protocol ProviderProtocol {
    
    init(node: Node, sessionConfiguration: URLSessionConfiguration)
    init(node: Node)
    func sendRequest<E: Encodable, D: Decodable>(method: JSONRPCMethod, params: E, decodeTo: D.Type, completion: @escaping (D?, JSONRPCError?) -> Void)
}

public final class Provider: ProviderProtocol {
    
    public let node: Node
    
    private let session: URLSession
    
    private let encoder = JSONEncoder()
    
    private let decoder = JSONDecoder()
    
    private let queue = DispatchQueue(label: "com.swift-ethereum.provider", attributes: .concurrent)
    
    public init(node: Node, sessionConfiguration: URLSessionConfiguration) {
        self.node = node
        self.session = URLSession(configuration: sessionConfiguration, delegate: nil, delegateQueue: nil)
    }
    
    public convenience init(node: Node) {
        self.init(node: node, sessionConfiguration: URLSession.shared.configuration)
    }
    
    deinit {
        self.session.finishTasksAndInvalidate()
    }
    
    /*
     Method that is called from Service to send a request
     */
    public func sendRequest<E: Encodable, D: Decodable>(method: JSONRPCMethod, params: E, decodeTo: D.Type, completion: @escaping (D?, JSONRPCError?) -> Void) {
        
        queue.async { [weak self] in
            
            guard let self = self else {
                completion(nil, .providerIsNil)
                return
            }
            
            var request = URLRequest(url: self.node.url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            
            let jsonRPC = JSONRPCRequest(jsonrpc: "2.0", method: method, params: params, id: 1)
            
            guard let jsonRPCData = try? JSONEncoder().encode(jsonRPC) else {
                completion(nil, .errorEncodingJSONRPC)
                return
            }
            
            request.httpBody = jsonRPCData
            
            let task = self.session.dataTask(with: request) { data, response, error in
                
                guard let data = data, error == nil else {
                    completion(nil, .nilResponse)
                    return
                }
                
                if let ethereumError = try? JSONDecoder().decode(JSONRPCResponseError.self, from: data) {
                    completion(nil, .ethereumError(ethereumError.error))
                    return
                }
                
                guard let jsonRPCResponse = try? JSONDecoder().decode(JSONRPCResponse<D>.self, from: data) else {
                    completion(nil, .errorDecodingJSONRPC)
                    return
                }
                
                completion(jsonRPCResponse.result, nil)
            }
            
            task.resume()
        }
        
    }
    
}
