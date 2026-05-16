import Foundation

public struct SensorProfile: Equatable, Sendable {
    public let identifier: String
    public let modelPatterns: [String]
    public let gpuClusterKeys: [String]
}

public func sensorProfile(for hardware: HardwareProfile) -> SensorProfile {
    sensorProfile(
        modelIdentifier: hardware.modelIdentifier,
        family: hardware.family
    )
}

public func sensorProfile(modelIdentifier: String, family: AppleSiliconFamily) -> SensorProfile {
    let canonicalModel = canonicalMacModelIdentifier(modelIdentifier)
    if let exactProfile = knownSensorProfiles.first(where: { $0.matches(modelIdentifier: canonicalModel) }) {
        return exactProfile
    }

    return fallbackSensorProfile(for: family)
}

public func gpuClusterTemperatureKeys(for hardware: HardwareProfile) -> [String] {
    sensorProfile(for: hardware).gpuClusterKeys
}

public func gpuClusterTemperatureKeys(modelIdentifier: String, family: AppleSiliconFamily) -> [String] {
    sensorProfile(modelIdentifier: modelIdentifier, family: family).gpuClusterKeys
}

private let knownSensorProfiles: [SensorProfile] = [
    SensorProfile(
        identifier: "m1-base-gpu-clusters",
        modelPatterns: ["MacBookAir10,1", "MacBookPro17,1", "Macmini9,1", "iMac21,1", "iMac21,2"],
        gpuClusterKeys: ["Tg05", "Tg0D", "Tg0L", "Tg0T"]
    ),
    SensorProfile(
        identifier: "m1-pro-max-ultra-gpu-clusters",
        modelPatterns: ["MacBookPro18,1", "MacBookPro18,2", "MacBookPro18,3", "MacBookPro18,4", "MacStudio1,1", "MacStudio1,2"],
        gpuClusterKeys: ["Tg05", "Tg0D", "Tg0L", "Tg0T", "Tg0b", "Tg0j", "Tg0r", "Tg0z"]
    ),
    SensorProfile(
        identifier: "m2-base-gpu-clusters",
        modelPatterns: ["MacBookAir11,1", "MacBookAir11,2", "MacBookPro17,2", "Macmini10,1", "Macmini10,2"],
        gpuClusterKeys: ["Tg0f", "Tg0n", "Tg0r"]
    ),
    SensorProfile(
        identifier: "m2-ultra-gpu-clusters",
        modelPatterns: ["MacStudio2,1", "MacStudio2,2"],
        gpuClusterKeys: ["Tg0f", "Tg0j", "Tg1h", "Tg1l", "Tg2f"]
    ),
    SensorProfile(
        identifier: "m3-base-gpu-clusters",
        modelPatterns: ["MacBookPro20,1", "iMac22,1", "iMac22,2", "MacBookAir12,1", "MacBookAir12,2"],
        gpuClusterKeys: ["Tg0D", "Tg0P", "Tg0X", "Tg0b", "Tg0j", "Tg0v"]
    ),
    SensorProfile(
        identifier: "m3-pro-gpu-clusters",
        modelPatterns: ["MacBookPro20,2", "MacBookPro20,5"],
        gpuClusterKeys: ["Tg05", "Tg0D", "Tg0v", "Tg1B"]
    ),
    SensorProfile(
        identifier: "m3-max-gpu-clusters",
        modelPatterns: ["MacBookPro20,3", "MacBookPro20,4", "MacBookPro20,6", "MacBookPro20,7"],
        gpuClusterKeys: ["Tg05", "Tg0z", "Tg34", "Tg3y"]
    ),
    SensorProfile(
        identifier: "m4-base-gpu-clusters",
        modelPatterns: ["Macmini11,1", "MacBookPro21,1", "iMac23,1", "iMac23,2", "MacBookAir13,1", "MacBookAir13,2"],
        gpuClusterKeys: ["Tg04", "Tg12"]
    ),
    SensorProfile(
        identifier: "m4-pro-max-gpu-clusters",
        modelPatterns: ["MacStudio3,1", "Macmini11,2", "MacBookPro21,2", "MacBookPro21,3", "MacBookPro21,4", "MacBookPro21,5"],
        gpuClusterKeys: ["Tg05", "Tg0S", "Tg0Y", "Tg0k", "Tg0z"]
    ),
    SensorProfile(
        identifier: "m4-ultra-gpu-clusters",
        modelPatterns: ["MacStudio3,2"],
        gpuClusterKeys: ["Tg05", "Tg0z", "Tg22", "Tg2I", "Tg34", "Tg3K"]
    ),
    SensorProfile(
        identifier: "m5-base-gpu-clusters",
        modelPatterns: ["MacBookPro22,1", "MacBookAir14,1", "MacBookAir14,2"],
        gpuClusterKeys: ["Tg04", "Tg12"]
    ),
    SensorProfile(
        identifier: "m5-pro-max-gpu-clusters",
        modelPatterns: ["MacBookPro22,2+"],
        gpuClusterKeys: ["Tg08", "Tg12", "Tg1x", "Tg29"]
    ),
    SensorProfile(
        identifier: "macbook-neo-gpu-clusters",
        modelPatterns: ["MacBookNeo1,1"],
        gpuClusterKeys: ["Tg05", "Tg0D"]
    )
]

private func fallbackSensorProfile(for family: AppleSiliconFamily) -> SensorProfile {
    let keys: [String]
    switch family {
    case .m1:
        keys = ["Tg05", "Tg0D", "Tg0L", "Tg0T", "Tg0b", "Tg0j", "Tg0r", "Tg0z"]
    case .m2:
        keys = ["Tg0f", "Tg0n", "Tg0r", "Tg0j", "Tg1h", "Tg1l", "Tg2f"]
    case .m3:
        keys = ["Tg0D", "Tg0P", "Tg0X", "Tg0b", "Tg0j", "Tg0v", "Tg05", "Tg1B", "Tg0z", "Tg34", "Tg3y"]
    case .m4, .m4ProOrMax:
        keys = ["Tg04", "Tg12", "Tg05", "Tg0S", "Tg0Y", "Tg0k", "Tg0z", "Tg22", "Tg2I", "Tg34", "Tg3K"]
    case .m5:
        keys = ["Tg04", "Tg12", "Tg08", "Tg1x", "Tg29", "Tg05", "Tg0D"]
    case .unknown:
        keys = knownSensorProfiles.flatMap(\.gpuClusterKeys)
    }

    return SensorProfile(
        identifier: "fallback-\(family.rawValue)-gpu-clusters",
        modelPatterns: [],
        gpuClusterKeys: unique(keys)
    )
}

private extension SensorProfile {
    func matches(modelIdentifier: String) -> Bool {
        modelPatterns.contains { pattern in
            if pattern.hasSuffix("+") {
                return isModelIdentifier(modelIdentifier, atLeast: String(pattern.dropLast()))
            }
            return pattern == modelIdentifier
        }
    }
}

private func isModelIdentifier(_ modelIdentifier: String, atLeast lowerBound: String) -> Bool {
    guard let model = ParsedModelIdentifier(modelIdentifier),
          let lowerBound = ParsedModelIdentifier(lowerBound),
          model.family == lowerBound.family else {
        return false
    }

    return (model.major, model.minor) >= (lowerBound.major, lowerBound.minor)
}

private struct ParsedModelIdentifier {
    let family: String
    let major: Int
    let minor: Int

    init?(_ rawValue: String) {
        guard let commaIndex = rawValue.lastIndex(of: ",") else {
            return nil
        }

        let beforeComma = rawValue[..<commaIndex]
        let minorText = rawValue[rawValue.index(after: commaIndex)...]
        guard let digitStart = beforeComma.firstIndex(where: { $0.isNumber }),
              let major = Int(beforeComma[digitStart...]),
              let minor = Int(minorText) else {
            return nil
        }

        self.family = String(beforeComma[..<digitStart])
        self.major = major
        self.minor = minor
    }
}

private func unique(_ keys: [String]) -> [String] {
    var seen = Set<String>()
    return keys.filter { seen.insert($0).inserted }
}
