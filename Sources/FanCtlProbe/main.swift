import FanCtlCore
import Foundation

do {
    let smc = try SMCConnection()
    let reader = SensorReader(smc: smc)
    let controller = FanController(smc: smc)

    if CommandLine.arguments.contains("--set-maximum") {
        for fan in reader.snapshot().fans {
            guard let maximumRPM = fan.maximumRPM else {
                continue
            }
            let result = try controller.setManual(fanIndex: fan.index, rpm: maximumRPM)
            print(String(format: "Set fan %d maximum: %.0f RPM", result.fanIndex, result.appliedRPM))
        }
    }

    if CommandLine.arguments.contains("--set-automatic") {
        for fan in reader.snapshot().fans {
            try controller.setAutomatic(fanIndex: fan.index)
            print("Set fan \(fan.index) automatic")
        }
    }

    let snapshot = reader.snapshot()

    print("Hardware")
    print("  Model: \(snapshot.hardware.modelIdentifier)")
    if snapshot.hardware.canonicalModelIdentifier != snapshot.hardware.modelIdentifier {
        print("  Canonical model: \(snapshot.hardware.canonicalModelIdentifier)")
    }
    print("  Chip: \(snapshot.hardware.chipName)")
    print("  Sensor family: \(snapshot.hardware.family.rawValue)")
    print("  SMC service: \(smc.serviceName)")
    print("  SMC struct size: \(SMCConnection.parameterStructSize)")
    print("")

    print("GPU cluster temperature")
    if let gpu = snapshot.gpuTemperature {
        print("  Profile: \(gpu.profileIdentifier)")
        print(String(format: "  Average: %.1f C", gpu.averageCelsius))
        for sensor in gpu.sensors {
            print(String(format: "  %@: %.1f C", sensor.key, sensor.celsius))
        }
    } else {
        print("  No GPU temperature sensors found")
    }
    print("")

    print("Fans")
    if snapshot.fans.isEmpty {
        print("  No fans found")
    } else {
        for fan in snapshot.fans {
            let target = fan.targetRPM.map { String(format: "%.0f", $0) } ?? "-"
            let minimum = fan.minimumRPM.map { String(format: "%.0f", $0) } ?? "-"
            let maximum = fan.maximumRPM.map { String(format: "%.0f", $0) } ?? "-"
            let mode = fan.mode.map(String.init) ?? "-"
            print(String(format: "  Fan %d: actual %.0f RPM, target %@, min %@, max %@, mode %@", fan.index, fan.actualRPM, target, minimum, maximum, mode))
        }
    }

    if CommandLine.arguments.contains("--diagnose") {
        print("")
        print("SMC diagnostics")
        let keys = [
            "FNum", "F0Ac", "F0Tg", "F0Mn", "F0Mx", "F0md", "F0Md", "F1Ac", "F1Tg", "F1Mn", "F1Mx", "F1md", "F1Md",
            "Tg05", "Tg0S", "Tg0Y", "Tg0k", "Tg0z",
            "Tg04", "Tg0R", "Tg0X", "Tg0y", "Tg1U", "Tg1V", "Tg1k", "Tg1l"
        ]
        for key in keys {
            do {
                let value = try smc.read(key)
                let bytes = value.bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
                let numeric = value.numericValue.map { String(format: "%.3f", $0) } ?? "-"
                print("  \(key): result=0x\(String(format: "%02x", value.resultCode)) type=\(value.dataType) size=\(value.dataSize) numeric=\(numeric) bytes=[\(bytes)]")
            } catch {
                print("  \(key): error=\(error.localizedDescription)")
            }
        }
    }
} catch {
    fputs("mfanctl-probe error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
