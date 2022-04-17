import Foundation

public protocol ProviderProtocol {
    
    init(node: Node, sessionConfiguration: URLSessionConfiguration)
    init(node: Node)
    func sendRequest(jsonRPCData: Data, completion: @escaping (Data?, Error?) -> Void)
}

public final class Provider: ProviderProtocol {
    
    public let node: Node
    
    private let session: URLSession
    
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
    public func sendRequest(jsonRPCData: Data, completion: @escaping (Data?, Error?) -> Void) {
        
        var request = URLRequest(url: node.url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonRPCData
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil, error)
                return
            }
            completion(data, nil)
        }
        task.resume()
    }
}
