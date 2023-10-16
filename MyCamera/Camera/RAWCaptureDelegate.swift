//
//  RAWCaptureDelegate.swift
//  MyCamera
//
//  Created by zjj on 2023/9/18.
//

import AVFoundation
import Photos

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
}

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
        
        guard error == nil else {
            print("Error capturing photo: \(error!)")
            savePhotoToAlbum()
            return
        }
        
        if photo.isRawPhoto {
            Task {
                await handleRawOutput(photo: photo)
            }
        } else {
            if compressedData == nil {
                // compressed的另一个data
                // 锐化过度的版本
                compressedData = photo.fileDataRepresentation()
                savePhotoToAlbum()
            }
        }
    }
    
    func handleRawOutput(photo: AVCapturePhoto) async {
        
        defer {
            savePhotoToAlbum()
        }
        
        // Access the file data representation of this photo.
        guard let photoData = photo.fileDataRepresentation() else {
            return
        }
        rawData = photoData
        // 优先使用raw转的jpeg data，避免苹果默认的处理
        guard let rawFilter = CIRAWFilter(imageData: photoData, identifierHint: "raw") else {
            return
        }
        //            rawFilter.boostAmount = 0.5
        //            if rawFilter.isColorNoiseReductionSupported {
        //                rawFilter.colorNoiseReductionAmount = 0.2
        //            }
        //            if rawFilter.isLuminanceNoiseReductionSupported {
        //                rawFilter.luminanceNoiseReductionAmount = 0.2
        //            }
        guard let ciimg = rawFilter.outputImage else {
            return
        }
        ciimg.settingProperties(photo.metadata)
        let option = [CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.6]
        compressedData = CIContext().heifRepresentation(of: ciimg, format: .BGRA8, colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!, options: option)
    }
    
    func savePhotoToAlbum() {
        
        // Call the "finished" closure, if you set it.
        defer {
            if let photoData = compressedData ?? rawData {
                didFinish(Photo(data: photoData))
            } else {
                didFinish(nil)
            }
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
