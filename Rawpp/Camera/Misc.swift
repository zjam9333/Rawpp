//
//  ExposureValue.swift
//  MyCamera
//
//  Created by zjj on 2023/10/10.
//

import AVFoundation
import CoreImage
import SwiftUI

var isXcodeDebugging: Bool {
    return CommandLine.arguments.contains("IS_XCODE_DEBUGGING")
}

/// "DEBUGGING LOG"
func print(_ item: Any..., separator: String = " ", terminator: String = "\n") {
    guard isXcodeDebugging else {
        return
    }
    Task {
        let date = Date()
        var strings = item.map { an in
            return String(describing: an)
        }
        strings.insert(date.description, at: 0)
        strings.insert("DEBUGGING LOG", at: 0)
        let p = strings.joined(separator: separator)
        Swift.print(p, terminator: terminator)
    }
}

enum SessionSetupResult {
    case success
    case configurationFailed
    case notAuthorized
}

struct Photo: Identifiable, Equatable {
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        return lhs.id == rhs.id
    }
    
    //    The ID of the captured photo
    let id: String
    //    Data representation of the captured photo
    
    var data: Data?
    var count: Int = 0
    
    init(id: String = UUID().uuidString, data: Data?) {
        self.id = id
        self.data = data
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

enum ExposureMode: UInt8 {
    case auto = 0
    case manual = 1
    case program = 2
}

struct ExposureValue: Equatable, Hashable {
    let rawValue: Int
    
    var floatValue: Float {
        return Float(rawValue) / 1000
    }
    
    var description: String {
        return "\(floatValue)"
    }
    
    static let zero = ExposureValue(rawValue: 0)
    
    static let presets: [ExposureValue] = {
        let ints = integers.sorted { v1, v2 in
            return v1.rawValue < v2.rawValue
        }
        var steps = [ExposureValue]()
        let max = ints.last
        for f in ints {
            steps.append(f)
            if f != max {
                steps.append(.init(rawValue: f.rawValue + 333))
                steps.append(.init(rawValue: f.rawValue + 666))
            }
        }
        return steps
    }()
    
    static let integers: Set<ExposureValue> = {
        let floats: [ExposureValue] = (-3...3).map { r in
            return ExposureValue(rawValue: r * 1000)
        }
        return Set(floats)
    }()
}

struct CaptureFormat: OptionSet {
    let rawValue: UInt8
    
    static let raw = CaptureFormat(rawValue: 1 << 1)
    static let heif = CaptureFormat(rawValue: 1)
    static let apple = CaptureFormat(rawValue: 1 << 7)
    
    var saveRAW: Bool {
        return contains(.raw)
    }
    
    var saveJpeg: Bool {
        return contains(.apple) || contains(.heif)
    }
    
    var title: String {
        if contains(.apple) {
            return "APPLE HDR"
        }
        if contains([.heif, .raw]) {
            return "RAW + HEIF"
        } else if contains(.raw) {
            return "RAW"
        } else if contains(.heif) {
            return "HEIF"
        }
        return ""
    }
}

struct ISOValue: Equatable, Hashable, CustomStringConvertible {
    private let rawValue: Int
    
    static let keyValues: [Int: Float] = [
        25: 25,
        30: 31.50,
        40: 39.68,
        
        50: 50,
        64: 63,
        80: 79.38,
        
        100: 100,
        125: 126, 
        160: 158.76,
        
        200: 200,
        250: 252,
        320: 317.52,
        
        400: 400,
        500: 504,
        640: 635.05,
        
        800: 800,
        1000: 1008,
        1280: 1270.08,
        
        1600: 1600,
    ]
    
    var floatValue: Float {
        return Self.keyValues[rawValue] ?? Float(rawValue)
    }
    
    var description: String {
        return "\(rawValue)"
    }
    
    static let iso400: ISOValue = .init(rawValue: 400)
    
    static let presets: [ISOValue] = {
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
    
    static let integers: Set<ISOValue> = [
        ISOValue(rawValue: 25),
        ISOValue(rawValue: 50),
        ISOValue(rawValue: 100),
        ISOValue(rawValue: 200),
        ISOValue(rawValue: 400),
        ISOValue(rawValue: 800),
        ISOValue(rawValue: 1600),
    ]
}

struct ShutterSpeed: Equatable, Hashable, CustomStringConvertible, Comparable {
    static func < (lhs: ShutterSpeed, rhs: ShutterSpeed) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    private let rawValue: UInt
    
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    static let keyValues: [UInt: Float] = [
        3: 3.125,
        4: 3.94,
        5: 4.96,
        
        6: 6.25,
        8: 7.87,
        10: 9.92,
        
        12: 12.5,
        15: 15.75,
        20: 19.84,
        
        25: 25,
        30: 31.50,
        40: 39.68,
        
        50: 50,
        64: 63,
        80: 79.38,
        
        100: 100,
        125: 126,
        160: 158.76,
        
        200: 200,
        250: 252,
        320: 317.52,
        
        400: 400,
        500: 504,
        640: 635.05,
        
        800: 800,
        1000: 1008,
        1280: 1270.08,
        
        1600: 1600,
        2000: 2016,
        2500: 2540.16,
        
        3200: 3200,
        4000: 4032,
        5000: 5080.32,
        
        6400: 6400,
        8000: 8064,
    ]
    
    var description: String {
        return "1/\(rawValue)"
    }
    
    var cmTime: CMTime {
        let f = Self.keyValues[rawValue] ?? Float(rawValue)
        return .init(value: .init(1), timescale: .init(f))
    }
    
    static let percent100: ShutterSpeed = .init(rawValue: 100)
    
    static let presets: [ShutterSpeed] = {
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
            3200, 4000, 5000,
            6400, 8000,
        ]
        let pres = ints.map { t in
            return ShutterSpeed(rawValue: t)
        }
        return pres
    }()
    
    static let integers: Set<ShutterSpeed> = [
        ShutterSpeed(rawValue: 4),
        ShutterSpeed(rawValue: 8),
        ShutterSpeed(rawValue: 15),
        ShutterSpeed(rawValue: 30),
        ShutterSpeed(rawValue: 60),
        ShutterSpeed(rawValue: 100),
        ShutterSpeed(rawValue: 125),
        ShutterSpeed(rawValue: 250),
        ShutterSpeed(rawValue: 500),
        ShutterSpeed(rawValue: 1000),
        ShutterSpeed(rawValue: 2000),
        ShutterSpeed(rawValue: 4000),
    ]
}

struct TimerObject {
    let startTime: Date
    var value: TimeInterval
}

struct BurstObject {
    let total: Int
    var current: Int
}

extension AVCaptureVideoOrientation {
    var isLandscape: Bool {
        return self == .landscapeLeft || self == .landscapeRight
    }
}

protocol CustomizeBasicValue: Equatable {
    
}

extension Float: CustomizeBasicValue {
    
}

extension Int: CustomizeBasicValue {
    
}

extension UInt8: CustomizeBasicValue {
    
}

extension CGFloat: CustomizeBasicValue {
    
}

extension Bool: CustomizeBasicValue {
    
}

struct CustomizeValue<Value> where Value: CustomizeBasicValue {
    
    let name: String
    
    var value: Value {
        set {
            if checkInRange?(newValue) == false {
                return
            }
            internalValue = newValue
        }
        get {
            return internalValue
        }
    }
    
    private var internalValue: Value {
        didSet {
            UserDefaults.standard[customCacheKey] = internalValue
        }
    }
    
    let `default`: Value
    let maxValue: Value
    let minValue: Value
    
    private let checkInRange: ((Value) -> Bool)?
    
    var customCacheKey: String {
        return "CustomizeValue_\(name)"
    }
    
    mutating func reset() {
        value = `default`
    }
    
    init(name: String, default: Value) {
        self.name = name
        self.default = `default`
        self.internalValue = UserDefaults.standard["CustomizeValue_\(name)"] as? Value ?? `default`
        self.maxValue = `default`
        self.minValue = `default`
        self.checkInRange = nil
    }
    
    init(name: String, default: Value, minValue: Value, maxValue: Value) where Value: Comparable {
        assert(minValue <= `default` && `default` <= maxValue, "value \(`default`) must in range \(minValue)...\(maxValue)")
        self.name = name
        self.default = `default`
        self.internalValue = UserDefaults.standard["CustomizeValue_\(name)"] as? Value ?? `default`
        self.maxValue = maxValue
        self.minValue = minValue
        self.checkInRange = { val in
            guard minValue <= val && val <= maxValue else {
                return false
            }
            return true
        }
    }
}

extension UserDefaults {
    subscript(_ key: String) -> Any? {
        set {
            setValue(newValue, forKey: key)
        }
        get {
            return value(forKey: key)
        }
    }
}

struct MappedCustomizeValue<Value, MappedValue> where Value: Equatable, MappedValue: CustomizeBasicValue {
    
    private let mapSetter: (Value) -> MappedValue
    private let mapGetter: (MappedValue) -> Value
    
    init(name: String, default: Value, set: @escaping (Value) -> MappedValue, get: @escaping (MappedValue) -> Value) {
        self.mapSetter = set
        self.mapGetter = get
        self.wrapObject = .init(name: name, default: set(`default`))
    }
    
    init(name: String, default: Value, minValue: Value, maxValue: Value, set: @escaping (Value) -> MappedValue, get: @escaping (MappedValue) -> Value) where Value: Comparable, MappedValue: Comparable {
        self.mapSetter = set
        self.mapGetter = get
        self.wrapObject = .init(name: name, default: set(`default`), minValue: set(minValue), maxValue: set(maxValue))
    }
    
    var value: Value {
        set {
            wrapObject.value = mapSetter(newValue)
        }
        get {
            return mapGetter(wrapObject.value)
        }
    }
    
    var `default`: Value {
        return mapGetter(wrapObject.default)
    }
    
    private var wrapObject: CustomizeValue<MappedValue>
    
    mutating func reset() {
        value = `default`
    }
}

class CustomSettingProperties: ObservableObject {
    
    @Published var raw = Raw()
    @Published var output = Output()
    @Published var color = Color()
    
    struct Raw {
        var boostAmount = CustomizeValue<Float>(name: "RawFilterProperties_boostAmount", default: 1, minValue: 0, maxValue: 1)
        
        var captureFormat = MappedCustomizeValue<CaptureFormat, CaptureFormat.RawValue>(name: "CameraViewModelCachedCaptureFormat", default: .heif) { op in
            return op.rawValue
        } get: { va in
            guard va > 0 else {
                return .heif
            }
            return .init(rawValue: va)
        }
    }
    
    struct Output {
        var heifLossyCompressionQuality = CustomizeValue<Float>(name: "RawFilterProperties_heifLossyCompressionQuality", default: 0.7, minValue: 0.1, maxValue: 1)
        
        var autoAdjustment = CustomizeValue<Bool>(name: "RawFilterProperties_autoAdjustment", default: true)
        
        var maxMegaPixel = MappedCustomizeValue<MegaPixel, MegaPixel.RawValue>(name: "RawFilterProperties_maxMegaPixel", default: .m12, minValue: .lowest, maxValue: .highest) { p in
            return p.rawValue
        } get: { v in
            return .init(rawValue: v) ?? .m12
        }
    }
    
    struct Color {
        var themeColor = MappedCustomizeValue<ThemeColor, ThemeColor.RawValue>(name: "RawFilterProperties_themeColor", default: .system) { se in
            return se.rawValue
        } get: { ge in
            return .init(rawValue: ge) ?? .system
        }
    }
    
    private init() { }
    
    static let shared = CustomSettingProperties()
}

enum ImageTool {
    static func rawFilter(photoData: Data, boostAmount: Float = 1) -> CIRAWFilter? {
        guard let filter = CIRAWFilter(imageData: photoData, identifierHint: nil) else {
            return nil
        }
        filter.boostAmount = boostAmount
        return filter
    }
    
    static func heifData(ciimage: CIImage, quality: Float) -> Data? {
        let options = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): quality]
        let heic = CIContext().heifRepresentation(of: ciimage, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, options: options)
        return heic
    }
}

struct CameraDevice: Equatable {
    let device: AVCaptureDevice
    let fov: Float
    let focalLength: Float
    init(device: AVCaptureDevice, fov: Float) {
        self.device = device
        self.fov = fov
        guard fov > 1 else {
            focalLength = 0
            return
        }
        let fullFrame: Float = 36 // full frame 36*24, diagonal = 43
        let radianFov = fov / 180 * .pi
        let len = fullFrame / 2 / tan(radianFov / 2)
        focalLength = len
    }
    
    static func ==(left: CameraDevice, right: CameraDevice) -> Bool {
        return left.device == right.device
    }
}

struct SelectItem: Identifiable {
    var id: String = UUID().uuidString
    let isSelected: Bool
    let isMain: Bool
    let title: String
    let selectionHandler: () -> Void
}

enum Result<A, B> {
    case success(A)
    case failure(B)
}

enum MegaPixel: UInt8, Comparable, CaseIterable {
    static func < (lhs: MegaPixel, rhs: MegaPixel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    static let lowest: MegaPixel = .m5
    static let highest: MegaPixel = .m48
    
    case m5 = 5
    case m6 = 6
    case m8 = 8
    case m10 = 10
    case m12 = 12
    case m16 = 16
    case m20 = 20
    case m24 = 24
    case m32 = 32
    case m48 = 48
    
    func scaleFrom(originalSize: CGSize) -> CGFloat {
        // w * s * h * s = newPixel
        // w * h = oldPixel
        let oldPixels = originalSize.width * originalSize.height
        guard oldPixels > 0 else {
            return 1
        }
        let newPixels = CGFloat(rawValue) * 1_000_000
        let s = sqrt(newPixels / oldPixels)
        return s
    }
}

enum ScaleInterpolation {
    case linear
    case nearest
    case lanczos
    case bicubic
}

enum ThemeColor: UInt8 {
    case system = 0
    case light = 1
    case dark = 2
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    static let foreground = Color("foreground")
    static let background = Color("background")
    static let highlightedYellow = Color("highlighted_yellow")
    static let highlightedRed = Color("highlighted_red")
    static let highlightedGreen = Color("highlighted_green")
}

 func pickValueBetween<T>(minVal: T, maxVal: T, input: T, compareIsSmaller: (T, T) -> Bool) -> T {
    if compareIsSmaller(input, minVal) {
        return minVal
    } else if compareIsSmaller(maxVal, input) {
        return maxVal
    }
    return input
}

struct DeviceExposureInfo {
    
    static var unknown: DeviceExposureInfo {
        return .init(evOffset: 0, bia: 0)
    }
    
    init(evOffset: Float, bia: Float) {
        let evOffset = evOffset + bia
        
        self.offset = ExposureValue.presets.min { e1, e2 in
            let d1 = e1.floatValue - evOffset
            let d2 = e2.floatValue - evOffset
            return abs(d1) < abs(d2)
        } ?? .zero
    }
    
    let offset: ExposureValue
    
//    let ss: ShutterSpeed
//    
//    let iso: ISOValue
}

enum ProgramShift {
    static var range: ClosedRange<Int> {
        return -4...4
    }
}

struct ExposureAdvice: CustomStringConvertible, Hashable {
    static let `default` = ExposureAdvice(ss: .percent100, iso: .iso400)
    
    var ss: ShutterSpeed
    var iso: ISOValue
    
    var description: String {
        return "[\(ss),\(iso)]"
    }
}
