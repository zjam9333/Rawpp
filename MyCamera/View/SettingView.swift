//
//  SettingView.swift
//  MyCamera
//
//  Created by zjj on 2023/12/11.
//

import SwiftUI

struct SettingView: View {
    private let rawImage: Data?
    
    @Binding var presenting: Bool
    
    init(rawImage: Data?, presenting: Binding<Bool>) {
        self.rawImage = rawImage
        self._presenting = presenting
    }
    
//    @State private var rawToUIImage: UIImage?
    @State private var outputUIImage: UIImage?
    
    @State private var rawProperties = SharedRawFilterProperties()
    
    var body: some View {
        NavigationView {
            VStack {
                previewView
                List {
                    Section("Basic") {
                        sliderCell(title: "Boost", property: $rawProperties.boostAmount)
                        sliderCell(title: "Boost Shadow", property: $rawProperties.boostShadowAmount)
                        sliderCell(title: "Exposure", property: $rawProperties.exposure)
                        sliderCell(title: "Baseline", property: $rawProperties.baselineExposure)
                        sliderCell(title: "Shadow Bias", property: $rawProperties.shadowBias)
                        sliderCell(title: "Local Tone", property: $rawProperties.localToneMapAmount)
                        sliderCell(title: "Extended Dynamic Range", property: $rawProperties.extendedDynamicRangeAmount)
                    }
                    
                    Section("Heif") {
                        sliderCell(title: "Heif Quality", property: $rawProperties.heifLossyCompressionQuality)
                    }
                    
                    Section("Detail") {
                        sliderCell(title: "Detail", property: $rawProperties.detailAmount)
                        sliderCell(title: "Color Noise Reduction", property: $rawProperties.colorNoiseReductionAmount)
                        sliderCell(title: "Luminance Noise Reduction", property: $rawProperties.luminanceNoiseReductionAmount)
                        sliderCell(title: "Moire Reduction", property: $rawProperties.moireReductionAmount)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(Text("Setting"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
//                await createRawOriginalPreview()
//                await createRawOutputPreview()
            }
        }
    }
    
    @ViewBuilder var previewView: some View {
        if let outputUIImage = outputUIImage {
            let rate = outputUIImage.size.width / outputUIImage.size.height
            ZoomView(presenting: true, contentAspectRatio: rate) {
                Image(uiImage: outputUIImage)
                    .resizable()
            }
            .id(UUID())
            .frame(height: 250)
            .overlay(alignment: .bottomLeading) {
                Button {
                    Task {
                        await createRawOutputPreview()
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20))
                        .padding()
                }
            }
        }
    }
    
    @ViewBuilder func sliderCell(title: String, property: Binding<CustomizeValue<Float>>) -> some View {
        let old = property.wrappedValue
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text("\(title))")
                    .font(.system(size: 13))
                Text(String(format: "%.02f", property.value.wrappedValue))
                    .font(.system(size: 13))
                    .foregroundColor(.yellow)
            }
            
            Spacer()
            
            Slider(value: .init(get: {
                return property.wrappedValue.value
            }, set: { ne in
                property.wrappedValue.value = ne
            }), in: old.minValue...old.maxValue)
            .frame(width: 200)
        }
    }
    
//    func createRawOriginalPreview() async {
//        guard let rawData = rawImage else {
//            return
//        }
//        let rawToUIImage = UIImage(data: rawData)
//        await MainActor.run {
//            self.rawToUIImage = rawToUIImage
//        }
//    }
    
    func createRawOutputPreview() async {
        print("createRawOutputPreview", "start")
        guard let rawData = rawImage else {
            return
        }
        guard let filt = rawProperties.customizedRawFilter(photoData: rawData) else {
            return
        }
        filt.isDraftModeEnabled = true
        filt.scaleFactor = 0.3
        guard let ciimg = filt.outputImage else {
            return
        }
        let ddata = rawProperties.heifData(ciimage: ciimg)
        guard let ddata = ddata else {
            return
        }
        let outputUIImage = UIImage(data: ddata)
        print("createRawOutputPreview", "end")
        await MainActor.run {
            self.outputUIImage = outputUIImage
        }
    }
}
