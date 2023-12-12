//
//  ExposureValue.swift
//  MyCamera
//
//  Created by zjj on 2023/10/10.
//

import AVFoundation
import CoreImage

private let log = true

/// 覆盖print
func print(_ items: Any..., separator: String = " ") {
    guard log else {
        return
    }
    let str = items.map { any in
        return String(describing: any)
    }.joined(separator: separator)
    Swift.print(str)
}

struct Photo: Identifiable, Equatable {
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        return lhs.id == rhs.id
    }
    
    //    The ID of the captured photo
    let id: String
    //    Data representation of the captured photo
    
    let data: Data
    let raw: Data?
    
    init(id: String = UUID().uuidString, data: Data, raw: Data?) {
        self.id = id
        self.data = data
        self.raw = raw
    }
}

struct AlertError {
    var title: String = ""
    var message: String = ""
    var primaryButtonTitle = "Accept"
    var secondaryButtonTitle: String?
    var primaryAction: (() -> ())?
    var secondaryAction: (() -> ())?
    
    init(title: String = "", message: String = "", primaryButtonTitle: String = "Accept", secondaryButtonTitle: String? = nil, primaryAction: (() -> ())? = nil, secondaryAction: (() -> ())? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}

enum ExposureMode {
    case auto
    case manual
}

struct ExposureValue: Equatable, Hashable {
    private let rawValue: Int
    
    var floatValue: Float {
        return Float(rawValue) / 100
    }
    
    var text: String {
        return String(format: "%.1f", rawValue)
    }
    
    static let zero = ExposureValue(rawValue: 0)
    
    static let presetExposureValues: [ExposureValue] = {
        let ints = integerValues.sorted { v1, v2 in
            return v1.rawValue < v2.rawValue
        }
        var steps = [ExposureValue]()
        let max = ints.last
        for f in ints {
            steps.append(f)
            if f != max {
                steps.append(.init(rawValue: f.rawValue + 33))
                steps.append(.init(rawValue: f.rawValue + 66))
            }
        }
        return steps
    }()
    
    static let integerValues: Set<ExposureValue> = {
        let floats: [ExposureValue] = (-5...5).map { r in
            return ExposureValue(rawValue: r * 100)
        }
        return Set(floats)
    }()
    
    static var cachedExposureValue: ExposureValue {
        get {
            guard let value = UserDefaults.standard.value(forKey: "CameraViewModelCachedExposureValue") as? Int else {
                return .zero
            }
            let oldV = ExposureValue(rawValue: value)
            guard presetExposureValues.contains(oldV) else {
                return .zero
            }
            return oldV
        }
        set {
            let value = newValue.rawValue
            UserDefaults.standard.setValue(value, forKey: "CameraViewModelCachedExposureValue")
        }
    }
}

enum RAWSaveOption: Int {
    case raw
    case heif
    case rawAndHeif
    
    var saveRAW: Bool {
        switch self {
        case .raw, .rawAndHeif:
            return true
        default:
            return false
        }
    }
    
    var saveJpeg: Bool {
        switch self {
        case .heif, .rawAndHeif:
            return true
        default:
            return false
        }
    }
    
    static var cachedRawOption: RAWSaveOption {
        get {
            guard let value = UserDefaults.standard.value(forKey: "CameraViewModelCachedRawOption") as? Int else {
                return .heif
            }
            return RAWSaveOption(rawValue: value) ?? .heif
        }
        set {
            let value = newValue.rawValue
            UserDefaults.standard.setValue(value, forKey: "CameraViewModelCachedRawOption")
        }
    }
}

struct ISOValue: Equatable, Hashable {
    private let rawValue: Int
    
    var floatValue: Float {
        return Float(rawValue)
    }
    
    static let iso100: ISOValue = .init(rawValue: 100)
    
    static let presetISOs: [ISOValue] = {
        // step: 1/3 = 1.26
        let ints = [
            25, 32, 40,
            50, 64, 80,
            100, 125, 160,
            200, 250, 320,
            400, 500, 640,
            800, 1000, 1280,
            1600,
        ]
        let pres = ints.map { i in
            return ISOValue(rawValue: i)
        }
        return pres
    }()
}

struct ShutterSpeed: Equatable, Hashable, CustomStringConvertible {
    private let rawValue: UInt
    
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    var floatValue: Float {
        return 1 / Float(rawValue)
    }
    
    var description: String {
        return "1/\(rawValue)"
    }
    
    var cmTime: CMTime {
        return .init(value: .init(1), timescale: .init(rawValue))
    }
    
    static let percent100: ShutterSpeed = .init(rawValue: 100)
    
    static let presetShutterSpeeds: [ShutterSpeed] = {
        // MARK: iphone不支持慢速快门
        //let ints = [-2, -4, -8, -15, -30, -60, -125, -250, -500, -1000, -4000]
        let ints: [UInt] = [
            3, 4, 5,
            6, 8, 10,
            12, 15, 20,
            25, 30, 40,
            50, 60, 80,
            100, 125, 160,
            200, 250, 320,
            400, 500, 640,
            800, 1000, 1280,
            1600, 2000, 2500,
            3200, 4000, 8000,
        ]
        let pres = ints.map { t in
            return ShutterSpeed(rawValue: t)
        }
        return pres
    }()
}

struct ShutterTimer {
    let rawValue: TimeInterval
    private init(rawValue: TimeInterval) {
        self.rawValue = rawValue
    }
    
    static let zero: ShutterTimer = .init(rawValue: 0)
    
    var next: ShutterTimer {
        let r = rawValue
        if r >= 10 {
            return .init(rawValue: 0)
        }
        if r >= 5 {
            return .init(rawValue: 10)
        }
        if r >= 2 {
            return .init(rawValue: 5)
        }
        return .init(rawValue: 2)
    }
    
    mutating func toggleNext() {
        self = next
    }
}

struct TimerObject {
    let startTime: Date
    var value: TimeInterval
}

extension AVCaptureVideoOrientation {
    var isLandscape: Bool {
        return self == .landscapeLeft || self == .landscapeRight
    }
}

struct CustomizeValue<Value> where Value: Comparable {
    
    let name: String
    let `default`: Value
    let minValue: Value
    let maxValue: Value
    var value: Value {
        didSet {
            cachedValue = value
        }
    }
    
    init(name: String, default: Value, minValue: Value, maxValue: Value) {
        self.name = name
        self.default = `default`
        self.minValue = minValue
        self.maxValue = maxValue
        self.value = UserDefaults.standard.value(forKey: "CustomizeValue_\(name)") as? Value ?? `default`
    }
    
    private var getCacheKey: String {
        return "CustomizeValue_\(name)"
    }
    
    private var cachedValue: Value {
        set {
            if newValue >= minValue && newValue <= maxValue {
                UserDefaults.standard.setValue(newValue, forKey: getCacheKey)
            }
        }
        get {
            let g = UserDefaults.standard.value(forKey: getCacheKey) as? Value
            return g ?? `default`
        }
    }
}

struct SharedRawFilterProperties {
    typealias Value = Float
    
    var exposure = CustomizeValue<Value>(name: "RawFilterProperties_exposure", default: 0, minValue: 0, maxValue: 1)
    
    var baselineExposure = CustomizeValue<Value>(name: "RawFilterProperties_baselineExposure", default: 0, minValue: 0, maxValue: 1)
    
    var shadowBias = CustomizeValue<Value>(name: "RawFilterProperties_shadowBias", default: 0, minValue: 0, maxValue: 1)
    
    var boostAmount = CustomizeValue<Value>(name: "RawFilterProperties_boostAmount", default: 0.5, minValue: 0, maxValue: 1)
    
    var boostShadowAmount = CustomizeValue<Value>(name: "RawFilterProperties_boostShadowAmount", default: 0, minValue: 0, maxValue: 2)
    
    var extendedDynamicRangeAmount = CustomizeValue<Value>(name: "RawFilterProperties_extendedDynamicRangeAmount", default: 0, minValue: 0, maxValue: 2)
    
    var luminanceNoiseReductionAmount = CustomizeValue<Value>(name: "RawFilterProperties_luminanceNoiseReductionAmount", default: 0, minValue: 0, maxValue: 1)
    
    var colorNoiseReductionAmount = CustomizeValue<Value>(name: "RawFilterProperties_colorNoiseReductionAmount", default: 0, minValue: 0, maxValue: 1)
    
    var detailAmount = CustomizeValue<Value>(name: "RawFilterProperties_detailAmount", default: 0, minValue: 0, maxValue: 3)
    
    var moireReductionAmount = CustomizeValue<Value>(name: "RawFilterProperties_moireReductionAmount", default: 0, minValue: 0, maxValue: 1)
    
    var localToneMapAmount = CustomizeValue<Value>(name: "RawFilterProperties_localToneMapAmount", default: 0, minValue: 0, maxValue: 1)
    
    var heifLossyCompressionQuality = CustomizeValue<Value>(name: "RawFilterProperties_heifLossyCompressionQuality", default: 0.6, minValue: 0.1, maxValue: 1)
    
    func customizedRawFilter(photoData: Data) -> CIRAWFilter? {
        guard let filter = CIRAWFilter(imageData: photoData, identifierHint: "raw") else {
            return nil
        }
        filter.exposure = exposure.value
        filter.baselineExposure = baselineExposure.value
        filter.shadowBias = shadowBias.value
        filter.boostAmount = boostAmount.value
        filter.boostShadowAmount = boostShadowAmount.value
        filter.extendedDynamicRangeAmount = extendedDynamicRangeAmount.value
        filter.isGamutMappingEnabled = false
        if filter.isLensCorrectionSupported {
            filter.isLensCorrectionEnabled = true
        }
        if filter.isLuminanceNoiseReductionSupported {
            filter.luminanceNoiseReductionAmount = luminanceNoiseReductionAmount.value
        }
        if filter.isColorNoiseReductionSupported {
            filter.colorNoiseReductionAmount = colorNoiseReductionAmount.value
        }
        if filter.isDetailSupported {
            filter.detailAmount = detailAmount.value
        }
        if filter.isMoireReductionSupported {
            filter.moireReductionAmount = moireReductionAmount.value
        }
        if filter.isLocalToneMapSupported {
            filter.localToneMapAmount = localToneMapAmount.value
        }
        return filter
    }
    
    func heifData(ciimage: CIImage) -> Data? {
        let option = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): heifLossyCompressionQuality.value]
        let heic = CIContext().heifRepresentation(of: ciimage, format: .BGRA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, options: option)
        return heic
    }
}
