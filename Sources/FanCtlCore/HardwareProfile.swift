import Foundation

public enum AppleSiliconFamily: String, Sendable {
    case m1
    case m2
    case m3
    case m4
    case m4ProOrMax
    case m5
    case unknown
}

public struct HardwareProfile: Sendable {
    public let modelIdentifier: String
    public let canonicalModelIdentifier: String
    public let chipName: String
    public let family: AppleSiliconFamily

    public init(modelIdentifier: String, chipName: String, family: AppleSiliconFamily) {
        self.modelIdentifier = modelIdentifier
        self.canonicalModelIdentifier = canonicalMacModelIdentifier(modelIdentifier)
        self.chipName = chipName
        self.family = family
    }

    public static var current: HardwareProfile {
        let chip = sysctlString("machdep.cpu.brand_string") ?? ""
        let model = sysctlString("hw.model") ?? ""

        return HardwareProfile(
            modelIdentifier: model,
            chipName: chip,
            family: family(chipName: chip)
        )
    }

    private static func family(chipName: String) -> AppleSiliconFamily {
        if chipName.localizedCaseInsensitiveContains("M5") {
            return .m5
        }
        if chipName.localizedCaseInsensitiveContains("M4 Pro") ||
            chipName.localizedCaseInsensitiveContains("M4 Max") ||
            chipName.localizedCaseInsensitiveContains("M4 Ultra") {
            return .m4ProOrMax
        }
        if chipName.localizedCaseInsensitiveContains("M4") {
            return .m4
        }
        if chipName.localizedCaseInsensitiveContains("M3") {
            return .m3
        }
        if chipName.localizedCaseInsensitiveContains("M2") {
            return .m2
        }
        if chipName.localizedCaseInsensitiveContains("M1") {
            return .m1
        }
        return .unknown
    }
}

public func canonicalMacModelIdentifier(_ modelIdentifier: String) -> String {
    macModelAliases[modelIdentifier] ?? modelIdentifier
}

private let macModelAliases: [String: String] = [
    "Mac13,1": "MacStudio1,1",
    "Mac13,2": "MacStudio1,2",
    "Mac14,3": "Macmini10,1",
    "Mac14,12": "Macmini10,2",
    "Mac14,7": "MacBookPro17,2",
    "Mac14,5": "MacBookPro19,3",
    "Mac14,6": "MacBookPro19,4",
    "Mac14,9": "MacBookPro19,1",
    "Mac14,10": "MacBookPro19,2",
    "Mac14,8": "MacPro8,1",
    "Mac14,13": "MacStudio2,1",
    "Mac14,14": "MacStudio2,2",
    "Mac14,2": "MacBookAir11,1",
    "Mac14,15": "MacBookAir11,2",
    "Mac15,3": "MacBookPro20,1",
    "Mac15,6": "MacBookPro20,2",
    "Mac15,8": "MacBookPro20,3",
    "Mac15,10": "MacBookPro20,4",
    "Mac15,7": "MacBookPro20,5",
    "Mac15,11": "MacBookPro20,6",
    "Mac15,9": "MacBookPro20,7",
    "Mac15,4": "iMac22,1",
    "Mac15,5": "iMac22,2",
    "Mac15,2": "MacBookAir12,1",
    "Mac15,13": "MacBookAir12,2",
    "Mac15,14": "MacStudio3,2",
    "Mac16,10": "Macmini11,1",
    "Mac16,11": "Macmini11,2",
    "Mac16,12": "MacBookAir13,1",
    "Mac16,13": "MacBookAir13,2",
    "Mac16,3": "iMac23,1",
    "Mac16,2": "iMac23,2",
    "Mac16,1": "MacBookPro21,1",
    "Mac16,8": "MacBookPro21,2",
    "Mac16,6": "MacBookPro21,3",
    "Mac16,7": "MacBookPro21,4",
    "Mac16,5": "MacBookPro21,5",
    "Mac16,9": "MacStudio3,1",
    "Mac17,2": "MacBookPro22,1",
    "Mac17,9": "MacBookPro22,2",
    "Mac17,7": "MacBookPro22,3",
    "Mac17,8": "MacBookPro22,4",
    "Mac17,6": "MacBookPro22,5",
    "Mac17,3": "MacBookAir14,1",
    "Mac17,4": "MacBookAir14,2",
    "Mac17,5": "MacBookNeo1,1"
]

private func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
        return nil
    }

    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
        return nil
    }

    if let terminator = buffer.firstIndex(of: 0) {
        buffer.removeSubrange(terminator..<buffer.endIndex)
    }
    return String(decoding: buffer.map { UInt8(bitPattern: $0) }, as: UTF8.self)
}
