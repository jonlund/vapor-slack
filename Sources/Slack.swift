import Vapor

public struct Slack {
    
    private let request: Request
    private let baseURL: String = "https://slack.com/api/"
    
    /**
     Initializer of Slack.
     
    - Parameters:
        - request: client request
     */
    init(_ request: Request) {
        self.request = request
    }
}

struct SlackResponse: Codable {
	let ok: Bool
	let error: String?
	let warning: String?
	// OTHER STUFF
}

// MARK: -
// Documentation: https://api.slack.com/web
extension Slack {
    
    // MARK: message api by Slack bot
    /**
     Send message to specify channel through Slack bot.
     
     - Parameters:
        - payload: Slack message content
     
     # Reference
     
     [Post Message | Slack Web API](https://api.slack.com/methods/chat.postMessage)
     */
    public func message(_ payload: SlackMessagePayload) -> EventLoopFuture<ClientResponse> {
        let api: String = self.baseURL + SlackChat.postMessage.api
        let headers: HTTPHeaders = self.request.application.slack.header
        
        let futureResponse = self.request.client.post(URI(string: api), headers: headers) { request in
            let body = try JSONEncoder().encode(payload)
			self.request.logger.info("[ Slack.payload ] \(String(decoding: body, as: UTF8.self))")
            try request.content.encode(payload)
        }
		
		return futureResponse.flatMapThrowing { response in

			guard response.status == .ok else {
				throw "[ Slack.response ] \(response.status.code) \(response.status)"
			}

			let body = try response.content.decode(SlackResponse.self)
			if let error = body.error {
				self.request.logger.error("[ Slack.error ] \(error)")
				throw "Slack responded with error: \(error)"
			}
			if let warning = body.warning {
				self.request.logger.warning("[ Slack.warning ] \(warning)")
			}
			if body.ok != true {
				self.request.logger.error("[ Slack.error ] ok != true")
			}

			if let fullBody = response.body {
                let res = Data(fullBody.readableBytesView)
				self.request.logger.info("[ Slack.response ] \(String(decoding: res, as: UTF8.self))")
            }

            return response
        }
    }
}


struct Empty: Codable {}

extension String: Error { }		// makes it so I can throw a string as an error
extension String: LocalizedError {
	public var errorDescription: String? { return self }
	
	/// for convenience: so we can use in a nil-coalescing operation
	public func doThrow<T>() throws -> T {
		throw self
	}
}

/// allows a nil-coalescing toss
public func toss<T> (_ message: String? = nil) throws -> T {
	throw(message ?? "Error")
}

public extension Error {
	func toss(_ prefix: String? = nil) throws {
		if let p = prefix { throw p.appending(self.localizedDescription) }
		throw self
	}
}
