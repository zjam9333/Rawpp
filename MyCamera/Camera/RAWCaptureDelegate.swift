//
//  RAWCaptureDelegate.swift
//  MyCamera
//
//  Created by zjj on 2023/9/18.
//

import AVFoundation
import Photos

enum RAWSaveOption: Int {
    case rawOnly
    case jpegOnly
    case rawAndJpeg
    
    var saveRAW: Bool {
        switch self {
        case .rawOnly, .rawAndJpeg:
            return true
        default:
            return false
        }
    }
    
    var saveJpeg: Bool {
        switch self {
        case .jpegOnly, .rawAndJpeg:
            return true
        default:
            return false
        }
    }
}

class RAWCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    init(option: RAWSaveOption) {
        self.saveOption = option
        super.init()
    }
    
    let saveOption: RAWSaveOption
    
    private var rawData: Data?
    private var compressedData: Data?
    
    var didFinish: ((Photo?) -> Void)?
    
    // Store the RAW file and compressed photo data until the capture finishes.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        
        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }
        
        if photo.isRawPhoto {
            // Access the file data representation of this photo.
            guard let photoData = photo.fileDataRepresentation() else {
                return
            }
            rawData = photoData
        } else {
            defer {
                if compressedData == nil {
                    // compressed的另一个data
                    // 锐化过度的版本
                    compressedData = photo.fileDataRepresentation()
                }
            }
            // 优先使用raw转的jpeg data，避免苹果默认的处理
            guard let rawData = rawData else {
                return
            }
            let rawFilter = CIRAWFilter(imageData: rawData)
            guard let ciimg = rawFilter?.outputImage else {
                return
            }
            ciimg.settingProperties(photo.metadata)
            let option = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.6]
            compressedData = CIContext().heifRepresentation(of: ciimg, format: .BGRA8, colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, options: option)
        }
    }
    
    // After both RAW and compressed versions are complete, add them to the Photos library.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        
        // Call the "finished" closure, if you set it.
        defer {
            if let compressedData = compressedData {
                didFinish?(Photo(originalData: compressedData))
            } else {
                didFinish?(nil)
            }
        }
        
        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }
        
        // Ensure the RAW and processed photo data exists.
        if saveOption.saveRAW, let rawData = rawData {
            // Request add-only access to the user's Photos library (if the user hasn't already granted that access).
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                
                // Don't continue unless the user granted access.
                guard status == .authorized else { return }
                
                PHPhotoLibrary.shared().performChanges {
                    // Save the RAW (DNG) file as the main resource for the Photos asset.
                    let options = PHAssetResourceCreationOptions()
                    
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: rawData, options: options)
                } completionHandler: { success, error in
                    // Process the Photos library error.
                }
            }
        }
        if saveOption.saveJpeg, let compressedData = compressedData {
            // Request add-only access to the user's Photos library (if the user hasn't already granted that access).
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                
                // Don't continue unless the user granted access.
                guard status == .authorized else { return }
                
                PHPhotoLibrary.shared().performChanges {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: compressedData, options: nil)
                } completionHandler: { success, error in
                    // Process the Photos library error.
                }
            }
        }
        
    }
}
