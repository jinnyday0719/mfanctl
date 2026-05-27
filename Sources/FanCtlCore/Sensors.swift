import Foundation

public struct TemperatureSensorReading: Sendable {
    public let key: String
    public let celsius: Double
}

public struct GPUTemperatureSnapshot: Sendable {
    public let averageCelsius: Double
    public let sensors: [TemperatureSensorReading]
    public let profileIdentifier: String
}

public struct FanSnapshot: Sendable {
    public let index: Int
    public let actualRPM: Double
    public let targetRPM: Double?
    public let minimumRPM: Double?
    public let maximumRPM: Double?
    public let mode: Int?
}

public struct SensorSnapshot: Sendable {
    public let hardware: HardwareProfile
    public let gpuTemperature: GPUTemperatureSnapshot?
    public let fans: [FanSnapshot]
}

public final class SensorReader: Sendable {
    private static let plausibleGPUTemperatureRange = 10.0..<130.0

    private let smc: SMCConnection
    private let hardware: HardwareProfile

    public init(smc: SMCConnection, hardware: HardwareProfile = .current) {
        self.smc = smc
        self.hardware = hardware
    }

    public convenience init(hardware: HardwareProfile = .current) throws {
        try self.init(smc: SMCConnection(), hardware: hardware)
    }

    public func snapshot() -> SensorSnapshot {
        SensorSnapshot(
            hardware: hardware,
            gpuTemperature: readGPUTemperature(),
            fans: readFans()
        )
    }

    public func readGPUTemperature() -> GPUTemperatureSnapshot? {
        let profile = sensorProfile(for: hardware)
        let readings = profile.gpuClusterKeys.compactMap { key -> TemperatureSensorReading? in
            guard let value = smc.numericValue(for: key),
                  Self.plausibleGPUTemperatureRange.contains(value) else {
                return nil
            }
            return TemperatureSensorReading(key: key, celsius: value)
        }

        guard !readings.isEmpty else {
            return nil
        }

        let average = readings.map(\.celsius).reduce(0, +) / Double(readings.count)
        return GPUTemperatureSnapshot(
            averageCelsius: average,
            sensors: readings,
            profileIdentifier: profile.identifier
        )
    }

    public func readFans() -> [FanSnapshot] {
        guard let count = smc.numericValue(for: "FNum"), count > 0 else {
            return []
        }

        return (0..<Int(count)).compactMap { index in
            guard let actual = smc.numericValue(for: "F\(index)Ac") else {
                return nil
            }

            return FanSnapshot(
                index: index,
                actualRPM: actual,
                targetRPM: smc.numericValue(for: "F\(index)Tg"),
                minimumRPM: smc.numericValue(for: "F\(index)Mn"),
                maximumRPM: smc.numericValue(for: "F\(index)Mx"),
                mode: readFanMode(index: index)
            )
        }
    }

    private func readFanMode(index: Int) -> Int? {
        if let lower = smc.numericValue(for: "F\(index)md") {
            return Int(lower)
        }
        if let upper = smc.numericValue(for: "F\(index)Md") {
            return Int(upper)
        }
        return nil
    }
}
