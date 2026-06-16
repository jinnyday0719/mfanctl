import FanCtlHelperXPC
import Foundation
import ServiceManagement

enum FanCtlHelperClient {
    enum Error: LocalizedError {
        case unavailable
        case rejected(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .unavailable:
                L10n.helperUnavailable
            case .rejected(let message):
                message
            case .invalidResponse:
                L10n.invalidHelperResponse
            }
        }
    }

    static func waitUntilAvailable(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Swift.Error = Error.unavailable

        while Date() < deadline {
            do {
                _ = try await send("PING")
                return
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        throw lastError
    }

    static func send(_ command: String, timeout: TimeInterval = 5.0) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await sendWithoutTimeout(command)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw Error.unavailable
            }

            guard let result = try await group.next() else {
                throw Error.unavailable
            }
            group.cancelAll()
            return result
        }
    }

    private static func sendWithoutTimeout(_ command: String) async throws -> String {
        let connection = NSXPCConnection(
            machServiceName: FanCtlHelperConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: FanCtlHelperXPCProtocol.self)

        let connectionHandle = XPCConnectionHandle(connection)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let state = XPCReplyState(connectionHandle: connectionHandle, continuation: continuation)
                let reply: (NSString?, NSString?) -> Void = { response, errorMessage in
                    if let response {
                        state.finish(.success(response as String))
                    } else if let errorMessage {
                        state.finish(.failure(Error.rejected(errorMessage as String)))
                    } else {
                        state.finish(.failure(Error.invalidResponse))
                    }
                }

                connection.resume()
                guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                    state.finish(.failure(Error.rejected(error.localizedDescription)))
                }) as? FanCtlHelperXPCProtocol else {
                    state.finish(.failure(Error.unavailable))
                    return
                }

                do {
                    switch command {
                    case "PING":
                        proxy.ping(withReply: reply)
                    case "SET_AUTOMATIC":
                        proxy.setAutomatic(withReply: reply)
                    case "SET_MAXIMUM":
                        proxy.setMaximum(withReply: reply)
                    default:
                        if command.hasPrefix("SET_RPM ") {
                            let rawRPM = String(command.dropFirst("SET_RPM ".count))
                            guard let rpm = Double(rawRPM), rpm.isFinite else {
                                throw Error.rejected(L10n.invalidHelperResponse)
                            }
                            proxy.setRPM(NSNumber(value: rpm), withReply: reply)
                        } else {
                            throw Error.rejected(L10n.invalidHelperResponse)
                        }
                    }
                } catch {
                    state.finish(.failure(error))
                }
            }
        } onCancel: {
            connectionHandle.invalidate()
        }
    }
}

private final class XPCConnectionHandle: @unchecked Sendable {
    private let lock = NSLock()
    private let connection: NSXPCConnection

    init(_ connection: NSXPCConnection) {
        self.connection = connection
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        connection.invalidate()
    }
}

private final class XPCReplyState: @unchecked Sendable {
    private let lock = NSLock()
    private let connectionHandle: XPCConnectionHandle
    private let continuation: CheckedContinuation<String, Swift.Error>
    private var didFinish = false

    init(connectionHandle: XPCConnectionHandle, continuation: CheckedContinuation<String, Swift.Error>) {
        self.connectionHandle = connectionHandle
        self.continuation = continuation
    }

    func finish(_ result: Result<String, Swift.Error>) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()

        switch result {
        case .success(let response):
            continuation.resume(returning: response)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
        connectionHandle.invalidate()
    }
}

enum FanCtlHelperInstaller {
    static func install() throws {
        let service = SMAppService.daemon(plistName: FanCtlHelperConstants.daemonPlistName)
        switch service.status {
        case .enabled:
            return
        case .requiresApproval:
            throw InstallError.requiresApproval
        case .notRegistered, .notFound:
            try service.register()
            if service.status == .requiresApproval {
                throw InstallError.requiresApproval
            }
        @unknown default:
            try service.register()
        }
    }
}

enum InstallError: LocalizedError {
    case requiresApproval

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            L10n.helperRequiresApproval
        }
    }
}
