//
//  ExposureValue.swift
//  MyCamera
//
//  Created by zjj on 2023/10/10.
//

import AVFoundation

struct Photo: Identifiable, Equatable {
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        return lhs.id == rhs.id
    }
    
    //    The ID of the captured photo
    var id: String
    //    Data representation of the captured photo
    var data: Data
    
    init(id: String = UUID().uuidString, data: Data) {
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
        var ints = [32, 64]
        var curr = 100
        let maxISO = 1600
        while curr < maxISO {
            ints.append(curr)
            let step = curr / 3
            ints.append(curr + step)
            ints.append(curr + step + step)
            curr += curr
        }
        ints.append(maxISO)
        let pres = ints.map { i in
            return ISOValue(rawValue: i)
        }
        return pres
    }()
}

struct ShutterSpeed: Equatable, Hashable, CustomStringConvertible {
    private let rawValue: Int
    
    init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    var floatValue: Float {
        if rawValue >= 0 {
            return Float(rawValue)
        }
        return 1 / Float(-rawValue)
    }
    
    var description: String {
        if rawValue >= 0 {
            return "\(rawValue)"
        }
        return "1/\(-rawValue)"
    }
    
    var cmTime: CMTime {
        if rawValue >= 0 {
            return .init(value: .init(rawValue), timescale: 1)
        }
        return .init(value: .init(1), timescale: .init(-rawValue))
    }
    
    static let percent100: ShutterSpeed = .init(rawValue: -100)
    
    static let presetShutterSpeeds: [ShutterSpeed] = {
//        let maxS = -10
        let minS = -4096
        var ints: [Int] = []
//        do {
//            var curr = 1
//            while curr < maxS {
//                ints.append(curr)
//                let step = curr / 3
//                if step != 0 {
//                    ints.append(curr + step)
//                    ints.append(curr + step + step)
//                }
//                curr += curr
//            }
//            ints.append(maxS)
//        }
        // 最大只能0.3333秒。。。
        // 从0.25开始遍历
        do {
            var curr = -4
            while curr > minS {
                ints.append(curr)
                let step = curr / 3
                if step != 0 {
                    ints.append(curr + step)
                    ints.append(curr + step + step)
                }
                curr += curr
            }
            ints.append(minS)
        }
        let pres = ints.map { rawValue in
            var rawValue = rawValue
            if rawValue <= -1000 {
                rawValue = rawValue / 100 * 100
            } else if rawValue <= -100 {
                rawValue = rawValue / 10 * 10
            }
            return ShutterSpeed(rawValue: rawValue)
        }.sorted { s1, s2 in
            return s1.rawValue < s2.rawValue
        }
        return pres
    }()
}
