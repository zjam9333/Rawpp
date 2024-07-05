//
//  File.swift
//  MyCamera
//
//  Created by zjj on 2021/9/15.
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI

struct CameraView: View {
    @StateObject var viewModel = CameraViewModel()
    
    @StateObject private var sharedPropertyies = CustomSettingProperties.shared
    
    var body: some View {
        
        VStack(spacing: 0) {
            centerPreview.zIndex(1)
            topActions.zIndex(10)
            bottomActions.zIndex(10)
        }
        .background(ThemeColor.background)
        .preferredColorScheme(sharedPropertyies.color.themeColor.value.colorScheme)
        .fullScreenCover(isPresented: $viewModel.showPhoto) {
            PhotoReview(photos: viewModel.photos, presenting: $viewModel.showPhoto)
        }
        .sheet(isPresented: $viewModel.showSetting) {
            SettingView(presenting: $viewModel.showSetting)
        }
        .onAppear {
            viewModel.configure()
        }
        .overlay {
            if let err = viewModel.alertError {
                ThemeColor.foreground.opacity(0.2)
                    .scaleEffect(y: 2)
                VStack(alignment: .center) {
                    Text(err.title)
                        .font(.title3)
                        .padding(.bottom, 10)
                        .padding(.top, 10)
                    Text(err.message)
                        .font(.body)
                        .padding(.bottom, 10)
                    Divider()
                    HStack {
                        Button {
                            err.primaryAction?()
                        } label: {
                            Text(err.primaryButtonTitle)
                                .font(.body)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        
                        if let secondaryButtonTitle = err.secondaryButtonTitle {
                            Button {
                                err.secondaryAction?()
                            } label: {
                                Text(secondaryButtonTitle)
                                    .font(.body)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity)
                        }
                    }
                    .frame(height: 44)
                }
                .foregroundStyle(ThemeColor.foreground)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ThemeColor.background)
                )
                .frame(width: 280)
            }
        }
    }
    
    @ViewBuilder private var topActions: some View {
        HStack(spacing: 20) {
            Button {
                viewModel.touchFeedback()
                viewModel.switchFlash()
            } label: {
                Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .foregroundStyle(viewModel.isFlashOn ? ThemeColor.highlightedYellow : ThemeColor.foreground)
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
            
            Button {
                viewModel.touchFeedback()
                viewModel.toggleTimer()
            } label: {
                let t = Int(viewModel.shutterTimer)
                let hi = t > 1
                Image(systemName: "timer")
                    .foregroundStyle(hi ? ThemeColor.highlightedYellow : ThemeColor.foreground)
                    .overlay {
                        if hi {
                            Text("\(t)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ThemeColor.highlightedYellow)
                                .padding(.horizontal, 2)
                                .background(ThemeColor.background)
                                .offset(x: 10, y: -10)
                        }
                    }
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
            
            Button {
                viewModel.touchFeedback()
                viewModel.toggleBurst()
            } label: {
                let t = Int(viewModel.burstCount)
                let hi = t > 1
                Image(systemName: "square.stack.3d.down.right")
                    .foregroundStyle(hi ? ThemeColor.highlightedYellow : ThemeColor.foreground)
                    .overlay {
                        if hi {
                            Text("\(t)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(ThemeColor.highlightedYellow)
                                .padding(.horizontal, 2)
                                .background(ThemeColor.background)
                                .offset(x: 10, y: -10)
                        }
                    }
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
            
            Button {
                viewModel.touchFeedback()
                viewModel.toggleFrontCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
            
            Spacer()
            
            Button {
                viewModel.touchFeedback()
                viewModel.showSetting = true
            } label: {
                Image(systemName: "gear")
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
        }
        .frame(height: 60)
        .padding(.horizontal, 20)
        .background()
        .foregroundStyle(ThemeColor.foreground)
        .font(.system(size: 20, weight: .semibold))
    }
    
    @ViewBuilder private var centerPreview: some View {
        let size = CGSize(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.width * 4 / 3)
        Rectangle()
            .fill(Color.clear)
            .frame(width: size.width, height: size.height)
            .overlay {
                CameraVideoLayerPreview(session: viewModel.session)
                    .scaleEffect(viewModel.cropFactor.value, anchor: .center) // cropFactor先放大view，拍摄后再裁切图片
                    .animation(.default, value: viewModel.cropFactor.value)
                    .clipped()
                    .border(.gray, width: 1)
                    .opacity(viewModel.isAppInBackground ? 0 : 1)
                    .animation(.default, value: viewModel.isAppInBackground)
                    .overlay {
                        if isXcodeDebugging {
                            Color.black.opacity(0.8)
                        }
                        if viewModel.isCapturing {
                            Color.black.opacity(0.5)
                        }
                    }
                
                centerExposureInfo
                
                gestureContainer(size: size)
            }
    }
    
    
    @ViewBuilder private var centerExposureInfo: some View {
        
        Group {
            Group {
                Color.white.frame(width: 1, height: 20)
                Color.white.frame(width: 10, height: 1)
            }
            .opacity(!viewModel.showingEVIndicators ? 1 : 0)
            
            VStack {
                switch viewModel.exposureMode.value {
                case .auto:
                    valuesIndicator(currentValue: viewModel.exposureValue.value, values: ExposureValue.presets) { va in
                        return ExposureValue.integers.contains(va)
                    }
                    
                    largeInfoText(title: "ev", value: String(format: "%.1f", viewModel.exposureValue.value.floatValue))
                        .foregroundStyle(.white)
                case .program:
                    HStack(alignment: .bottom) {
                        VStack {
                            largeInfoText(title: "iso", value: viewModel.manualExposure.iso.description)
                                .foregroundStyle(.white)
                            valuesIndicator(currentValue: viewModel.manualExposure, values: viewModel.programExposureAdvices) { va in
                                return false
                            }
                            largeInfoText(title: "ss", value: viewModel.manualExposure.ss.description)
                                .foregroundStyle(.white)
                        }
                        VStack {
                            valuesIndicator(currentValue: viewModel.exposureValue.value, values: ExposureValue.presets) { va in
                                return ExposureValue.integers.contains(va)
                            }
                            largeInfoText(title: "ev", value: String(format: "%.1f", viewModel.exposureValue.value.floatValue))
                                .foregroundStyle(.white)
                        }
                    }
                case .manual:
                    HStack {
                        VStack {
                            valuesIndicator(currentValue: viewModel.manualExposure.iso, values: ISOValue.presets) { va in
                                return ISOValue.integers.contains(va)
                            }
                            largeInfoText(title: "iso", value: viewModel.manualExposure.iso.description)
                                .foregroundStyle(.white)
                        }
                        
                        VStack {
                            valuesIndicator(currentValue: viewModel.manualExposure.ss, values: ShutterSpeed.presets) { va in
                                return ShutterSpeed.integers.contains(va)
                            }
                            largeInfoText(title: "ss", value: viewModel.manualExposure.ss.description)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.5))
            .opacity(viewModel.showingEVIndicators ? 1 : 0)
        }
        .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
        .animation(viewModel.showingEVIndicators ? .default : .default.delay(1), value: viewModel.showingEVIndicators)
    }
    
    @ViewBuilder private var exposureInfo: some View {
        HStack(alignment: .top, spacing: 8) {
            switch viewModel.exposureMode.value {
            case .auto:
                valuesIndicator(currentValue: viewModel.currentExposureInfo.offset, preferValue: viewModel.exposureValue.value, values: ExposureValue.presets) { va in
                    return ExposureValue.integers.contains(va)
                }
            case .manual:
                Group {
                    smallInfoText(title: "iso", value: viewModel.manualExposure.iso.description)
                    smallInfoText(title: "ss", value: viewModel.manualExposure.ss.description)
                }
                .foregroundStyle(ThemeColor.highlightedRed)
                
                valuesIndicator(currentValue: viewModel.currentExposureInfo.offset, preferValue: ExposureValue.zero, values: ExposureValue.presets) { va in
                    return ExposureValue.integers.contains(va)
                }
            case .program:
                Group {
                    smallInfoText(title: "iso", value: viewModel.manualExposure.iso.description)
                    smallInfoText(title: "ss", value: viewModel.manualExposure.ss.description)
                    if viewModel.programExposureShift.value != 0 {
                        Text(viewModel.programExposureShift.value < 0 ? "←" : "→")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundStyle(ThemeColor.highlightedYellow)
                
                valuesIndicator(currentValue: viewModel.currentExposureInfo.offset, preferValue: viewModel.exposureValue.value, values: ExposureValue.presets) { va in
                    return ExposureValue.integers.contains(va)
                }
            }
            smallInfoText(title: "\(sharedPropertyies.output.maxMegaPixel.value.rawValue)", value: "mp", smallFirst: false)
                .foregroundStyle(ThemeColor.highlightedYellow)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.black.opacity(0.5))
        )
        .padding()
    }
    
    @ViewBuilder private var lensesSelection: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.allLenses) { i in
                Button {
                    viewModel.touchFeedback()
                    i.selectionHandler()
                } label: {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.black.opacity(i.isSelected ? 0.5 : 0))
                        .frame(width: i.isSelected ? 40 : 36, height: 30, alignment: .center)
                        .overlay {
                            Text(i.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                            if i.isMain {
                                ThemeColor.highlightedYellow.frame(width: 10, height: 1).offset(y: 8)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.gray.opacity(0.5))
        )
        .padding()
    }
    
    @ViewBuilder private var bottomActions: some View {
        HStack {
            Spacer()
        }
        .frame(height: 100)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ThemeColor.background)
                .frame(width: 74, height: 74)
                .overlay(alignment: .center) {
                    let firstPhoto = viewModel.photos.first { p in
                        return p.data != nil
                    }
                    if let photo = firstPhoto, let data = photo.data, let img = UIImage(data: data) {
                        let isGroup = photo.count > 1
                        Button {
                            viewModel.touchFeedback()
                            viewModel.showPhoto = true
                        } label: {
                            ZStack {
                                let range = 0..<max(1, min(3, photo.count))
                                ForEach(range, id: \.self) { i in
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .border(.white, width: 1)
                                        .offset(x: CGFloat(i) * (-3), y: CGFloat(i) * (3))
                                }
                            }
                            .frame(width: 74, height: 74)
                        }.overlay(alignment: .bottomLeading) {
                            if isGroup {
                                Text("\(photo.count)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .background {
                                        Rectangle()
                                            .fill(.black)
                                            .border(.white, width: 1)
                                    }
                            }
                        }
                    }
                    if viewModel.isProcessing {
                        LoadingView()
                    }
                }
                
                .opacity(viewModel.isAppInBackground ? 0 : 1)
                .animation(.default, value: viewModel.isAppInBackground)
        }
        .overlay(alignment: .center) {
            
            if let timer = viewModel.timerSeconds {
                let seconds = Int(timer.value) + 1
                Text("\(seconds)")
                    .foregroundStyle(.foreground)
                    .font(.system(size: 72, weight: .semibold))
            } else if let burst = viewModel.burstObject {
                Text("\(burst.current)/\(burst.total)")
                    .foregroundStyle(.foreground)
                    .font(.system(size: 72, weight: .semibold))
            } else {
                Button {
                    guard viewModel.isCapturing == false else {
                        return
                    }
                    viewModel.touchFeedback()
                    viewModel.capturePhoto()
                } label: {
                    let buttonSiz: CGFloat = 74
                    let circleSiz = buttonSiz - 36
                    Circle()
                        .stroke(viewModel.isCapturing ? .gray : ThemeColor.foreground, lineWidth: 2)
                        .frame(width: buttonSiz, height: buttonSiz, alignment: .center)
                        .overlay(alignment: .center) {
                            Circle()
                                .stroke(ThemeColor.foreground, lineWidth: 2)
                                .frame(width: circleSiz, height: circleSiz, alignment: .center)
                        }
                }
            }
        }
        .overlay(alignment: .trailing) {
            
            VStack(alignment: .trailing) {
                
                Button {
                    viewModel.touchFeedback()
                    viewModel.toggleExposureMode()
                } label: {
                    Group {
                        switch viewModel.exposureMode.value {
                        case .auto:
                            Text("AUTO")
                                .foregroundStyle(ThemeColor.highlightedGreen)
                        case .program:
                            Text("PROGRAM")
                                .foregroundStyle(ThemeColor.highlightedYellow)
                        case .manual:
                            Text("MANUAL")
                                .foregroundStyle(ThemeColor.highlightedRed)
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(height: 24)
                }
                
                Text(sharedPropertyies.raw.captureFormat.value.title)
                    .foregroundStyle(ThemeColor.foreground)
            }
        }
        .padding(.horizontal, 20)
        .font(.system(size: 12, weight: .semibold))
        .background()
    }
    
    @ViewBuilder func largeInfoText(title: String, value: String) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            Text(value)
                .font(.system(size: 24, weight: .semibold))
        }
    }
    
    @ViewBuilder func smallInfoText(title: String, value: String, smallFirst: Bool = true) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(title)
                .font(.system(size: smallFirst ? 10 : 12, weight: .semibold))
            Text(value)
                .font(.system(size: smallFirst ? 12 : 10, weight: .semibold))
        }
    }
    
    @ViewBuilder func valuesIndicator<Element>(currentValue: Element, preferValue: Element? = nil, values: [Element], isInteger: @escaping (Element) -> Bool) -> some View where Element: Hashable {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(values, id: \.self) { ev in
                Color.clear
                    .frame(width: 1, height: 12)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(preferValue == ev ? ThemeColor.highlightedRed : Color.white)
                            .frame(height: isInteger(ev) ? 12 : 8)
                    }
                    .overlay(alignment: .bottom) {
                        if ev == currentValue {
                            Image(systemName: "triangle.fill")
                                .resizable()
                                .foregroundStyle(ThemeColor.highlightedYellow)
                                .frame(width: 4, height: 4)
                                .offset(y: 6)
                        }
                    }
            }
        }
    }
    
    @ViewBuilder func gestureContainer(size: CGSize) -> some View {
        
        Group {
            switch viewModel.exposureMode.value {
            case .auto:
                StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.exposureValue.value, items: ExposureValue.presets) {
                    viewModel.touchFeedback()
                }
            case .manual:
                HStack {
                    StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.manualExposure.iso, items: ISOValue.presets) {
                        viewModel.touchFeedback()
                    }
                    StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.manualExposure.ss, items: ShutterSpeed.presets) {
                        viewModel.touchFeedback()
                    }
                }
                
            case .program:
                HStack {
                    StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.programExposureShift.value, items: Array(ProgramShift.range)) {
                        viewModel.touchFeedback()
                        viewModel.toggleProgramExposureMaunalShift()
                    }
                    StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.exposureValue.value, items: ExposureValue.presets) {
                        viewModel.touchFeedback()
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            @MainActor func resetExposure() async {
                viewModel.resetExposure()
                viewModel.showingEVIndicators = true
                try? await Task.sleep(nanoseconds: 0_010_000_000)
                viewModel.showingEVIndicators = false
            }
            Task {
                await resetExposure()
            }
        }
        .onTapGesture {
            viewModel.focus()
        }
        .overlay(alignment: .bottom) {
            if viewModel.allLenses.count > 0 {
                lensesSelection
            }
        }
        .overlay(alignment: .top) {
            exposureInfo
        }
        .frame(width: viewModel.videoOrientation.isLandscape ? size.height : size.width, height: viewModel.videoOrientation.isLandscape ? size.width : size.height)
        .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
        .frame(width: size.width, height: size.height)
    }
}

struct CameraVideoLayerPreview: UIViewRepresentable {
    // 1.
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        view.contentMode = .scaleAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }
}

struct LoadingView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let ac = UIActivityIndicatorView(style: .medium)
        ac.isUserInteractionEnabled = false
        ac.hidesWhenStopped = false
        ac.startAnimating()
        return ac
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        
    }
}

struct CameraViewPreview: PreviewProvider {
    static var previews: some View {
        return CameraView()
    }
}

extension View {
    func rotateWithVideoOrientation(videoOrientation: AVCaptureVideoOrientation) -> some View {
        var degree: Angle {
            switch videoOrientation {
            case .portraitUpsideDown:
                return .degrees(180)
            case .landscapeLeft:
                return .degrees(-90)
            case .landscapeRight:
                return .degrees(90)
            default:
                return .zero
            }
        }
        return rotationEffect(degree).animation(.default, value: videoOrientation)
    }
}
