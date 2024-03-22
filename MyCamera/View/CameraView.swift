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
                    .font(.system(size: 20))
            }
            .accentColor(viewModel.isFlashOn ? ThemeColor.highlightedYellow : ThemeColor.foreground)
            .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            
            Button {
                viewModel.touchFeedback()
                viewModel.toggleTimer()
            } label: {
                let t = Int(viewModel.shutterTimer)
                let hi = t > 1
                Image(systemName: "timer")
                    .font(.system(size: 20))
                    .accentColor(hi ? ThemeColor.highlightedYellow : ThemeColor.foreground)
                    .overlay {
                        if hi {
                            Text("\(t)")
                                .font(.system(size: 12))
                                .foregroundStyle(ThemeColor.highlightedYellow)
                                .padding(.horizontal, 2)
                                .background(ThemeColor.background)
                                .offset(x: 10, y: -10)
                        }
                    }
            }
            
            Button {
                viewModel.touchFeedback()
                viewModel.toggleBurst()
            } label: {
                let t = Int(viewModel.burstCount)
                let hi = t > 1
                Image(systemName: "repeat")
                    .font(.system(size: 20))
                    .accentColor(hi ? ThemeColor.highlightedYellow : ThemeColor.foreground)
                    .overlay {
                        if hi {
                            Text("\(t)")
                                .font(.system(size: 12))
                                .foregroundStyle(ThemeColor.highlightedYellow)
                                .padding(.horizontal, 2)
                                .background(ThemeColor.background)
                                .offset(x: 10, y: -10)
                        }
                    }
            }
            
            Spacer()
            
            rawOptionView
            
            Button {
                viewModel.touchFeedback()
                switch viewModel.exposureMode {
                case .auto:
                    viewModel.exposureMode = .manual
                case .manual:
                    viewModel.exposureMode = .program
                case .program:
                    viewModel.exposureMode = .auto
                }
            } label: {
                Group {
                    switch viewModel.exposureMode {
                    case .auto:
                        Text("AUTO")
                            .foregroundStyle(ThemeColor.highlightedGreen)
                    case .program:
                        Text("PROG")
                            .foregroundStyle(ThemeColor.highlightedGreen)
                    case .manual:
                        Text("MANU")
                            .foregroundStyle(ThemeColor.highlightedRed)
                    }
                }
                .font(.system(size: 12))
                .padding(5)
                .frame(height: 24)
                .border(ThemeColor.foreground, width: 1)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .background()
    }
    
    @ViewBuilder private var rawOptionView: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.touchFeedback()
                if viewModel.rawOption.value.contains(.apple) {
                    viewModel.rawOption.value.remove(.apple)
                } else {
                    viewModel.rawOption.value.insert(.apple)
                }
            } label: {
                Text("APPLE")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColor.foreground)
                    .strikethrough(viewModel.rawOption.value.contains(.apple) == false, color: ThemeColor.highlightedYellow)
                    .padding(.vertical, 5)
                    .frame(height: 24)
            }
            
            Button {
                viewModel.touchFeedback()
                switch viewModel.rawOption.value {
                case .heif:
                    viewModel.rawOption.value = .raw
                case .raw:
                    viewModel.rawOption.value = [.raw, .heif]
                default:
                    viewModel.rawOption.value = .heif
                }
            } label: {
                var title: String {
                    if viewModel.rawOption.value.contains([.heif, .raw]) {
                        return "R+H"
                    } else if viewModel.rawOption.value.contains(.raw) {
                        return "RAW"
                    } else if viewModel.rawOption.value.contains(.heif) {
                        return "HEIF"
                    }
                    return ""
                }
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColor.foreground)
                    .strikethrough(viewModel.rawOption.value.contains(.apple), color: ThemeColor.highlightedYellow)
                    .padding(.vertical, 5)
                    .frame(height: 24)
            }
        }
        .padding(.horizontal, 5)
        .border(ThemeColor.foreground, width: 1)
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
            
                Group {
                    Group {
                        Color.white.frame(width: 1, height: 20)
                        Color.white.frame(width: 10, height: 1)
                    }
                    .opacity(!viewModel.showingEVIndicators ? 1 : 0)
                    
                    VStack {
                        switch viewModel.exposureMode {
                        case .auto:
                            valuesIndicator(currentValue: viewModel.exposureValue, values: ExposureValue.presets) { va in
                                return ExposureValue.integers.contains(va)
                            }
                            Text(String(format: "EV %.1f", viewModel.exposureValue.floatValue))
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        case .program:
                            HStack(alignment: .bottom) {
                                VStack {
                                    Text(String(format: "ISO %.0f", viewModel.manualExposure.iso.floatValue))
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white)
                                    valuesIndicator(currentValue: viewModel.manualExposure, values: viewModel.programExposureAdvices) { va in
                                        return false
                                    }
                                    Text(String(format: "SS %@", viewModel.manualExposure.ss.description))
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white)
                                }
                                VStack {
                                    valuesIndicator(currentValue: viewModel.exposureValue, values: ExposureValue.presets) { va in
                                        return ExposureValue.integers.contains(va)
                                    }
                                    Text(String(format: "EV %.1f", viewModel.exposureValue.floatValue))
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white)
                                }
                            }
                        case .manual:
                            HStack {
                                VStack {
                                    valuesIndicator(currentValue: viewModel.manualExposure.iso, values: ISOValue.presets) { va in
                                        return ISOValue.integers.contains(va)
                                    }
                                    Text(String(format: "ISO %.0f", viewModel.manualExposure.iso.floatValue))
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white)
                                }
                                
                                VStack {
                                    valuesIndicator(currentValue: viewModel.manualExposure.ss, values: ShutterSpeed.presets) { va in
                                        return ShutterSpeed.integers.contains(va)
                                    }
                                    Text(String(format: "SS %@", viewModel.manualExposure.ss.description))
                                        .font(.system(size: 24))
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
                
                gestureContainer(size: size)
                
                if viewModel.allLenses.count > 0 {
                    Color.clear.overlay(alignment: .bottom) {
                        lensesSelection
                    }
                }
                
                Color.clear.overlay(alignment: .top) {
                    exposureInfo
                }
            }
    }
    
    
    @ViewBuilder private var exposureInfo: some View {
        Button {
            viewModel.showSetting = true
        } label: {
            HStack(alignment: .top, spacing: 8) {
                switch viewModel.exposureMode {
                case .auto:
                    valuesIndicator(currentValue: viewModel.currentExposureInfo.offset, center: .zero, preferValue: viewModel.exposureValue, values: ExposureValue.presets) { va in
                        return ExposureValue.integers.contains(va)
                    }
                case .manual:
                    Text(String(format: "ISO %.0f", viewModel.manualExposure.iso.floatValue))
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColor.highlightedRed)
                    Text("SS \(viewModel.manualExposure.ss.description)")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColor.highlightedRed)
                    valuesIndicator(currentValue: viewModel.currentExposureInfo.offset, center: .zero, preferValue: viewModel.exposureValue, values: ExposureValue.presets) { va in
                        return ExposureValue.integers.contains(va)
                    }
                case .program:
                    Text(String(format: "ISO %.0f", viewModel.manualExposure.iso.floatValue))
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColor.highlightedGreen)
                    Text("SS \(viewModel.manualExposure.ss.description)")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColor.highlightedGreen)
                    if viewModel.programExposureShift != 0 {
                        Text(viewModel.programExposureShift < 0 ? "←" : "→")
                            .font(.system(size: 12))
                            .foregroundStyle(ThemeColor.highlightedGreen)
                    }
                    valuesIndicator(currentValue: viewModel.currentExposureInfo.offset, center: .zero, preferValue: viewModel.exposureValue, values: ExposureValue.presets) { va in
                        return ExposureValue.integers.contains(va)
                    }
                }
                Text("\(sharedPropertyies.output.maxMegaPixel.value.rawValue)MP")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColor.highlightedYellow)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.black.opacity(0.5))
            )
        }
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
                                .font(.system(size: 12))
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
                                    .font(.system(size: 12))
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
                    .font(.system(size: 72))
            } else if let burst = viewModel.burstObject {
                Text("\(burst.current)/\(burst.total)")
                    .foregroundStyle(.foreground)
                    .font(.system(size: 72))
            } else {
                Button {
                    viewModel.touchFeedback()
                    viewModel.capturePhoto()
                } label: {
                    let buttonSiz: CGFloat = 74
                    let circleSiz = buttonSiz - 36
                    Circle()
                        .stroke(viewModel.isCapturing ? .gray : ThemeColor.foreground, lineWidth: 1)
                        .frame(width: buttonSiz, height: buttonSiz, alignment: .center)
                        .overlay(alignment: .center) {
                            Circle()
                                .stroke(ThemeColor.foreground, lineWidth: 1)
                                .frame(width: circleSiz, height: circleSiz, alignment: .center)
                        }
                }
            }
        }
        .overlay(alignment: .trailing) {
            Button {
                viewModel.touchFeedback()
                viewModel.toggleFrontCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 30, weight: .thin))
                    .rotateWithVideoOrientation(videoOrientation: viewModel.videoOrientation)
            }
            .accentColor(ThemeColor.foreground)
        }
        .padding(.horizontal, 20)
        .background()
    }
    
    @ViewBuilder func valuesIndicator<Element>(currentValue: Element, center: Element? = nil, preferValue: Element? = nil, values: [Element], isInteger: @escaping (Element) -> Bool) -> some View where Element: Hashable {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(values, id: \.self) { ev in
                let isSelected = currentValue == ev
                Color.clear
                    .frame(width: isSelected ? 2 : 1, height: 12)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(isSelected ? ThemeColor.highlightedRed : Color.white)
                            .frame(height: isInteger(ev) ? 12 : 8)
                    }
                    .overlay(alignment: .top) {
                        if isSelected {
                            Image(systemName: "triangle.fill")
                                .resizable()
                                .rotationEffect(.degrees(180))
                                .accentColor(ThemeColor.highlightedRed)
                                .frame(width: 4, height: 4)
                                .offset(y: -8)
                        }
                        if ev == center {
                            Image(systemName: "triangle.fill")
                                .resizable()
                                .rotationEffect(.degrees(180))
                                .accentColor(ThemeColor.highlightedGreen)
                                .frame(width: 4, height: 4)
                                .offset(y: -8)
                        }
                        if ev == preferValue {
                            Image(systemName: "triangle.fill")
                                .resizable()
                                .accentColor(ThemeColor.highlightedYellow)
                                .frame(width: 4, height: 4)
                                .offset(y: 12)
                        }
                    }
            }
        }
    }
    
    @ViewBuilder func gestureContainer(size: CGSize) -> some View {
        
        Group {
            switch viewModel.exposureMode {
            case .auto:
                StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.exposureValue, items: ExposureValue.presets) {
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
                    StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.programExposureShift, items: Array(ProgramShift.range)) {
                        viewModel.touchFeedback()
                        viewModel.toggleProgramExposureMaunalShift()
                    }
                    StepDragView(isDragging: $viewModel.showingEVIndicators, value: $viewModel.exposureValue, items: ExposureValue.presets) {
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
            viewModel.focus(pointOfInterest: .init(x: 0.5, y: 0.5))
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
            .ignoresSafeArea()
            .border(ThemeColor.highlightedRed, width: 1)
            .background(.black)
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
