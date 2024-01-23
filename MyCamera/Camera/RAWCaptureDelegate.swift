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
    
    init(option: RAWSaveOption, didFinish: @escaping (Photo?) -> Void) {
        self.saveOption = option
        self.didFinish = didFinish
        super.init()
    }
    
    let saveOption: RAWSaveOption
    
    let didFinish: (Photo?) -> Void
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // dispose system shutter sound
        AudioServicesDisposeSystemSoundID(1108)
    }
    
    // Store the RAW file and compressed photo data until the capture finishes.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        Task(priority: .high) {
            let output = await processPhoto(photo, error: error)
            let photo = output.map { o in
                return Photo(data: o)
            }
            didFinish(photo)
        }
    }
    
    func processPhoto(_ photo: AVCapturePhoto, error: Error?) async -> Data? {
        guard let rawData = photo.fileDataRepresentation(), error == nil else {
            return nil
        }
        guard photo.isRawPhoto else {
            // apple处理的heic版本
            let notRawData = rawData
            savePhotoData(notRawData)
            return notRawData
        }
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
        Task {
            try? await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
        }
    }
    
    func handleRawOutput(photoData: Data) async -> Data? {
        // Access the file data representation of this photo.
        // 优先使用raw转的jpeg data，避免苹果默认的处理
        print("RAW", "begin")
        let customProperties = RawFilterProperties.shared
        print("RAW", "read properties")
        guard let rawFilter = ImageTool.rawFilter(photoData: photoData, boostAmount: customProperties.raw.boostAmount.value) else {
            return nil
        }
        print("RAW", "filter created")
        guard var ciimg = rawFilter.outputImage else {
            return nil
        }
        print("RAW", "outputed Image")
//        ciimg = ciimg.settingProperties(photo.metadata)
        let autoOptions: [CIImageAutoAdjustmentOption: Any] = [
            // 只使用最基本的enhance
            .enhance: true,
            .redEye: false,
            .features: [],
            .level: false,
            .crop: false,
        ]
        let adjustments = ciimg.autoAdjustmentFilters(options: autoOptions)
        print("RAW", "autoAdjustmentFilters created", adjustments)
        for fil in adjustments {
            fil.setValue(ciimg, forKey: kCIInputImageKey)
            ciimg = fil.outputImage ?? ciimg
        }
        print("RAW", "autoAdjustmentFilters used")
        let heif = ImageTool.heifData(ciimage: ciimg, quality: customProperties.output.heifLossyCompressionQuality.value)
        print("RAW", "heif")
        return heif
    }
}
