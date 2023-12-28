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
    
    private var rawData: Data?
    private var compressedData: Data?
    
    let didFinish: (Photo?) -> Void
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // dispose system shutter sound
        AudioServicesDisposeSystemSoundID(1108)
    }
    
    // Store the RAW file and compressed photo data until the capture finishes.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        Task {
            if let error = error {
                print("didFinishProcessingPhoto", error)
            } else if photo.isRawPhoto {
                await handleRawOutput(photo: photo)
            } else {
                if compressedData == nil {
                    // compressed的另一个data
                    // 锐化过度的版本
                    compressedData = photo.fileDataRepresentation()
                }
            }
            await savePhotoToAlbum()
        }
    }
    
    func handleRawOutput(photo: AVCapturePhoto) async {
        // Access the file data representation of this photo.
        guard let photoData = photo.fileDataRepresentation() else {
            return
        }
        rawData = photoData
        // 优先使用raw转的jpeg data，避免苹果默认的处理
        let customProperties = RawFilterProperties()
        guard let rawFilter = customProperties.customizedRawFilter(photoData: photoData) else {
            return
        }
        guard var ciimg = rawFilter.outputImage else {
            return
        }
//        ciimg = ciimg.settingProperties(photo.metadata)
        let autoOptions: [CIImageAutoAdjustmentOption: Any] = [
//            .enhance: true,
//            .redEye: true,
//            .features: true,
            .level: false,
            .crop: false,
        ]
        let adjustments = ciimg.autoAdjustmentFilters(options: autoOptions)
        for fil in adjustments {
            fil.setValue(ciimg, forKey: kCIInputImageKey)
            ciimg = fil.outputImage ?? ciimg
        }
        compressedData = customProperties.heifData(ciimage: ciimg)
    }
    
    func savePhotoToAlbum() async {
        if saveOption.saveRAW, let rawData = rawData  {
            try? await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: rawData, options: nil)
            }
        }
        if saveOption.saveJpeg, let compressedData = compressedData {
            try? await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: compressedData, options: nil)
            }
        }
        
        if let photoData = compressedData ?? rawData {
            didFinish(Photo(data: photoData, raw: rawData))
        } else {
            didFinish(nil)
        }
    }
}
