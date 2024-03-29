//
//  RAWCaptureDelegate.swift
//  MyCamera
//
//  Created by zjj on 2023/9/18.
//

import AVFoundation
import Photos
import CoreImage.CIFilterBuiltins

class RAWCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    init(custom: Custom, didFinish: @escaping (Data?) -> Void) {
        self.custom = custom
        self.didFinish = didFinish
        super.init()
    }
    
    private var custom: Custom
    
    struct Custom {
        var captureFormat: CaptureFormat
        var cropFactor: CGFloat
        var location: CLLocation?
        fileprivate let customProperties = CustomSettingProperties.shared
    }
    
    private let didFinish: (Data?) -> Void
    
    var photo: (AVCapturePhoto, Error?)?
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // dispose system shutter sound
        AudioServicesDisposeSystemSoundID(1108)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        self.photo = (photo, error)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        Task {
            let output = await processPhoto(photo?.0, error: error)
            didFinish(output)
        }
    }
    
    private func processPhoto(_ photo: AVCapturePhoto?, error: Error?) async -> Data? {
        guard let rawData = photo?.fileDataRepresentation(), error == nil else {
            return nil
        }
        guard photo?.isRawPhoto == true else {
            // apple处理的heic版本
            let notRawData = await handleNotRawOutput(photoData: rawData) ?? rawData
            savePhotoData(notRawData)
            return notRawData
        }
        let saveOption = custom.captureFormat
        if saveOption.saveRAW {
            savePhotoData(rawData)
        }
        guard let processedHeic = await handleRawOutput(photoData: rawData) else {
            // 返回nil都不要返回rawData，会卡
            return nil
        }
        if saveOption.saveJpeg {
            savePhotoData(processedHeic)
        }
        return processedHeic
    }
    
    func savePhotoData(_ data: Data) {
        let location = custom.location
        Task {
            try? await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
                request.location = location
            }
        }
    }
    
    private func handleNotRawOutput(photoData: Data) async -> Data? {
        guard let ciimg = CIImage(data: photoData) else {
            return nil
        }
        return await basicCIImageAdjustmentOutput(ciimg: ciimg)
    }
    
    private func handleRawOutput(photoData: Data) async -> Data? {
        // Access the file data representation of this photo.
        // 优先使用raw转的jpeg data，避免苹果默认的处理
        print("RAW", "begin")
        print("RAW", "read properties")
        guard let rawFilter = ImageTool.rawFilter(photoData: photoData, boostAmount: custom.customProperties.raw.boostAmount.value) else {
            return nil
        }
        print("RAW", "filter created")
        guard var ciimg = rawFilter.outputImage else {
            return nil
        }
        print("RAW", "outputed Image")
        
        if (custom.customProperties.output.autoAdjustment.value) {
            ciimg = autoAdjust(ciimg: ciimg)
        }
        
        return await basicCIImageAdjustmentOutput(ciimg: ciimg)
    }
    
    private func autoAdjust(ciimg: CIImage) -> CIImage {
        var ciimg = ciimg
        // 自动调整
        let autoOptions: [CIImageAutoAdjustmentOption: Any] = [
            // 只使用最基本的enhance
            .enhance: true,
            .redEye: false,
            .features: [],
            .level: false,
            .crop: false,
        ]
        let adjustments = ciimg.autoAdjustmentFilters(options: autoOptions)
        print("CIImage", "autoAdjustmentFilters created", adjustments)
        for fil in adjustments {
            fil.setValue(ciimg, forKey: kCIInputImageKey)
            ciimg = fil.outputImage ?? ciimg
        }
        print("CIImage", "autoAdjustmentFilters used")
        return ciimg
    }
    
    private func basicCIImageAdjustmentOutput(ciimg: CIImage) async -> Data? {
        var ciimg = ciimg
        
        // 裁切
        let cropFactor = custom.cropFactor
        if cropFactor > 1 {
            print("CIImage", "cropFactor", cropFactor)
            let insetFac = (1 - 1 / cropFactor) / 2
            let extent = ciimg.extent
            let croppedRect = extent.insetBy(dx: extent.width * insetFac, dy: extent.height * insetFac)
            ciimg = ciimg.cropped(to: croppedRect) // 直接裁了会损失原始数据，有其他办法？
        }
        
        let megaPixelScale = custom.customProperties.output.maxMegaPixel.value.scaleFrom(originalSize: ciimg.extent.size)
        if megaPixelScale < 0.90 && megaPixelScale > 0 {
            let method = ScaleInterpolation.linear
            switch method {
            case .linear:
                ciimg = ciimg.samplingLinear()
                    .transformed(by: .init(scaleX: megaPixelScale, y: megaPixelScale))
            case .nearest:
                ciimg = ciimg.samplingNearest()
                    .transformed(by: .init(scaleX: megaPixelScale, y: megaPixelScale))
            case .lanczos:
                let scaleFilter = CIFilter.lanczosScaleTransform()
                scaleFilter.scale = .init(megaPixelScale)
                scaleFilter.inputImage = ciimg
                ciimg = scaleFilter.outputImage ?? ciimg
            case .bicubic:
                let scaleFilter = CIFilter.bicubicScaleTransform()
                scaleFilter.scale = .init(megaPixelScale)
                scaleFilter.inputImage = ciimg
                ciimg = scaleFilter.outputImage ?? ciimg
            }
        }
        
        // 输出heif
        let customProperties = custom.customProperties
        let heif = ImageTool.heifData(ciimage: ciimg, quality: customProperties.output.heifLossyCompressionQuality.value)
        print("CIImage", "output heif")
        return heif
    }
    
    func print(_ item: Any..., separator: String = " ", terminator: String = "\n") {
        var strings = item.map { an in
            return String(describing: an)
        }
        strings.insert("RAWCaptureDelegate", at: 0)
        let p = strings.joined(separator: separator)
        Rawpp.print(p, terminator: terminator)
    }
}
