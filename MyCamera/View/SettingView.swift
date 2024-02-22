//
//  SettingView.swift
//  MyCamera
//
//  Created by zjj on 2023/12/11.
//

import SwiftUI

struct SettingView: View {
    
    @Binding var presenting: Bool
    
    init(presenting: Binding<Bool>) {
        self._presenting = presenting
    }
    @StateObject private var sharedPropertyies = RawFilterProperties.shared
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Output") {
                        sliderCell(title: "Heif Quality", property: $sharedPropertyies.output.heifLossyCompressionQuality)
                        megaPixelPickerCell(title: "Max Mega Pixel")
                    }
                    /*
                    Section("Post Progress") {
                        /*
                        sliderCell(title: "Vibrance", property: $sharedPropertyies.post.vibrance)
                         */
                        sliderCell(title: "Curve Point 0", property: $sharedPropertyies.post.curvePoint0)
                        sliderCell(title: "Curve Point 1", property: $sharedPropertyies.post.curvePoint1)
                        sliderCell(title: "Curve Point 2", property: $sharedPropertyies.post.curvePoint2)
                        sliderCell(title: "Curve Point 3", property: $sharedPropertyies.post.curvePoint3)
                        sliderCell(title: "Curve Point 4", property: $sharedPropertyies.post.curvePoint4)
                    }
                     */
                    Section("Raw Filter") {
                        sliderCell(title: "Boost", property: $sharedPropertyies.raw.boostAmount)
                        /*
                        sliderCell(title: "Boost Shadow", property: $sharedPropertyies.raw.boostShadowAmount)
                        sliderCell(title: "Exposure", property: $sharedPropertyies.raw.exposure)
                        sliderCell(title: "Baseline", property: $sharedPropertyies.raw.baselineExposure)
                        sliderCell(title: "Shadow Bias", property: $sharedPropertyies.raw.shadowBias)
                        sliderCell(title: "Local Tone", property: $sharedPropertyies.raw.localToneMapAmount)
                        sliderCell(title: "Extended Dynamic Range", property: $sharedPropertyies.raw.extendedDynamicRangeAmount)
                        sliderCell(title: "Detail", property: $sharedPropertyies.raw.detailAmount)
                        sliderCell(title: "Sharpness", property: $sharedPropertyies.raw.sharpnessAmount)
                        sliderCell(title: "Contrast", property: $sharedPropertyies.raw.contrastAmount)
                        sliderCell(title: "Color Noise Reduction", property: $sharedPropertyies.raw.colorNoiseReductionAmount)
                        sliderCell(title: "Luminance Noise Reduction", property: $sharedPropertyies.raw.luminanceNoiseReductionAmount)
                        sliderCell(title: "Moire Reduction", property: $sharedPropertyies.raw.moireReductionAmount)
                         */
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(Text("Setting"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
    
    @ViewBuilder func sliderCell(title: String, property: Binding<CustomizeValue<Float>>) -> some View {
        let old = property.wrappedValue
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text("\(title)")
                    .font(.system(size: 13))
                Text(String(format: "%.02f", property.value.wrappedValue))
                    .font(.system(size: 13))
                    .foregroundColor(.yellow)
            }
            .gesture(
                TapGesture(count: 2).onEnded { t in
                    property.wrappedValue.value = property.wrappedValue.default
                }
            )
            
            Spacer()
            
            BoundSlider(value: property.value, range: old.minValue...old.maxValue, foregroundColor: .yellow, backgroundColor: .gray.opacity(0.2)) { i in
                
            }
            .frame(width: 200, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
    
    @ViewBuilder func megaPixelPickerCell(title: String) -> some View {
        let bindMega = $sharedPropertyies.output.maxMegaPixel
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text("\(title)")
                    .font(.system(size: 13))
                Text(String(format: "%dMP", bindMega.wrappedValue.value.rawValue))
                    .font(.system(size: 13))
                    .foregroundColor(.yellow)
            }
            .gesture(
                TapGesture(count: 2).onEnded { t in
                    bindMega.wrappedValue.value = bindMega.wrappedValue.default
                }
            )
            
            Spacer()
            
            PickerSlider(value: bindMega.value, items: MegaPixel.allCases, foregroundColor: .yellow, backgroundColor: .gray.opacity(0.2)) { i in
                
            }
            .frame(width: 200, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
    
    /*
    func createRawOutputPreview() async {
        print("createRawOutputPreview", "start")
        guard let rawData = rawImage else {
            return
        }
        guard let filt = sharedPropertyies.customizedRawFilter(photoData: rawData) else {
            return
        }
        filt.isDraftModeEnabled = true
        filt.scaleFactor = 0.3
        guard let ciimg = filt.outputImage else {
            return
        }
        guard let tonedCiimage = sharedPropertyies.toneCurvedImage(ciimage: ciimg) else {
            return
        }
        let ddata = sharedPropertyies.heifData(ciimage: tonedCiimage)
        guard let ddata = ddata else {
            return
        }
        let outputUIImage = UIImage(data: ddata)
        print("createRawOutputPreview", "end")
        await MainActor.run {
            self.outputUIImage = outputUIImage
        }
    }
     */
}
