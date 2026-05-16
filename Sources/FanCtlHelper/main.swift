import Darwin
import FanCtlCore
import Foundation

private let socketPath = "/var/run/io.github.jinnyday0719.mfanctl.helper.sock"
private let consolePath = "/dev/console"

final class FanCtlHelper {
    private var listener: Int32 = -1

    func run() throws -> Never {
        listener = try makeListener()
        while true {
            let client = accept(listener, nil, nil)
            guard client >= 0 else {
                continue
            }
            handle(client: client)
            close(client)
        }
    }

    private func makeListener() throws -> Int32 {
        unlink(socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = Array(socketPath.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            close(fd)
            throw POSIXError(.ENAMETOOLONG)
        }

        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: pathBytes.count + 1) { buffer in
                for (index, byte) in pathBytes.enumerated() {
                    buffer[index] = CChar(bitPattern: byte)
                }
                buffer[pathBytes.count] = 0
            }
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            let error = POSIXError(.init(rawValue: errno) ?? .EIO)
            close(fd)
            throw error
        }

        try restrictSocketPermissions()

        guard listen(fd, 8) == 0 else {
            let error = POSIXError(.init(rawValue: errno) ?? .EIO)
            close(fd)
            throw error
        }

        return fd
    }

    private func handle(client: Int32) {
        do {
            try authorize(client: client)
            let command = try readCommand(from: client)
            let response = try execute(command)
            writeResponse("OK \(response)\n", to: client)
        } catch {
            writeResponse("ERROR \(error.localizedDescription)\n", to: client)
        }
    }

    private func restrictSocketPermissions() throws {
        let group = staffGroupID()
        guard chown(socketPath, 0, group) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        guard chmod(socketPath, 0o660) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }

    private func authorize(client: Int32) throws {
        var peerUID = uid_t()
        var peerGID = gid_t()
        guard getpeereid(client, &peerUID, &peerGID) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        if peerUID == 0 {
            return
        }

        guard let consoleUID = currentConsoleUserID(), peerUID == consoleUID else {
            throw FanCtlHelperError.unauthorizedClient
        }
    }

    private func currentConsoleUserID() -> uid_t? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: consolePath),
              let ownerID = attributes[.ownerAccountID] as? NSNumber else {
            return nil
        }
        let uid = uid_t(ownerID.uint32Value)
        return uid == 0 ? nil : uid
    }

    private func staffGroupID() -> gid_t {
        guard let group = getgrnam("staff") else {
            return 20
        }
        return group.pointee.gr_gid
    }

    private func readCommand(from client: Int32) throws -> String {
        var buffer = [UInt8](repeating: 0, count: 512)
        let count = Darwin.read(client, &buffer, buffer.count)
        guard count > 0 else {
            throw FanCtlHelperError.emptyCommand
        }

        return String(decoding: buffer.prefix(Int(count)), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func execute(_ command: String) throws -> String {
        switch command {
        case "PING":
            return "pong"
        case "SET_AUTOMATIC":
            try setAutomatic()
            return "automatic"
        case "SET_MAXIMUM":
            try setMaximum()
            return "maximum"
        default:
            if command.hasPrefix("SET_RPM ") {
                let rawRPM = String(command.dropFirst("SET_RPM ".count))
                guard let rpm = Double(rawRPM), rpm.isFinite, rpm >= 0 else {
                    throw FanCtlHelperError.invalidRPM(rawRPM)
                }
                try setRPM(rpm)
                return "rpm \(Int(rpm.rounded()))"
            }
            throw FanCtlHelperError.unknownCommand(command)
        }
    }

    private func setAutomatic() throws {
        let smc = try SMCConnection()
        let reader = SensorReader(smc: smc)
        let controller = FanController(smc: smc)

        for fan in reader.snapshot().fans {
            try controller.setAutomatic(fanIndex: fan.index)
        }
    }

    private func setMaximum() throws {
        let smc = try SMCConnection()
        let reader = SensorReader(smc: smc)
        let controller = FanController(smc: smc)

        for fan in reader.snapshot().fans {
            guard let maximumRPM = fan.maximumRPM else {
                continue
            }
            _ = try controller.setManual(fanIndex: fan.index, rpm: maximumRPM)
        }
    }

    private func setRPM(_ rpm: Double) throws {
        let smc = try SMCConnection()
        let reader = SensorReader(smc: smc)
        let controller = FanController(smc: smc)

        for fan in reader.snapshot().fans {
            _ = try controller.setManual(fanIndex: fan.index, rpm: rpm)
        }
    }

    private func writeResponse(_ response: String, to client: Int32) {
        let bytes = Array(response.utf8)
        _ = bytes.withUnsafeBytes { rawBuffer in
            Darwin.write(client, rawBuffer.baseAddress, rawBuffer.count)
        }
    }
}

private enum FanCtlHelperError: LocalizedError {
    case emptyCommand
    case unauthorizedClient
    case invalidRPM(String)
    case unknownCommand(String)

    var errorDescription: String? {
        switch self {
        case .emptyCommand:
            "empty command"
        case .unauthorizedClient:
            "unauthorized client"
        case .invalidRPM(let value):
            "invalid RPM: \(value)"
        case .unknownCommand(let command):
            "unknown command: \(command)"
        }
    }
}

do {
    try FanCtlHelper().run()
} catch {
    fputs("mfanctl-helper error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
