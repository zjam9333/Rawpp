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
    @StateObject private var sharedPropertyies = CustomSettingProperties.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Output") {
                    sliderCell(title: "Heif Quality", property: $sharedPropertyies.output.heifLossyCompressionQuality)
                    megaPixelPickerCell(title: "Max Mega Pixel")
                }
                
                Section("Raw Filter") {
                    sliderCell(title: "Boost", property: $sharedPropertyies.raw.boostAmount)
                }
                
                Section("Theme Color") {
                    let allCases: [ThemeColor] = [.system, .light, .dark]
                    ForEach(allCases, id: \.self) { the in
                        Button {
                            sharedPropertyies.color.themeColor.value = the
                        } label: {
                            HStack {
                                Text(the.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(ThemeColor.foreground)
                                Spacer()
                                if sharedPropertyies.color.themeColor.value == the {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(ThemeColor.highlightedYellow)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .preferredColorScheme(sharedPropertyies.color.themeColor.value.colorScheme)
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
                    .foregroundStyle(ThemeColor.foreground)
                Text(String(format: "%.02f", property.value.wrappedValue))
                    .font(.system(size: 13))
                    .foregroundStyle(ThemeColor.highlightedYellow)
            }
            .gesture(
                TapGesture(count: 2).onEnded { t in
                    property.wrappedValue.value = property.wrappedValue.default
                }
            )
            
            Spacer()
            
            BoundSlider(value: property.value, range: old.minValue...old.maxValue, foregroundColor: ThemeColor.highlightedYellow, backgroundColor: .gray.opacity(0.2)) { i in
                
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
                    .foregroundStyle(ThemeColor.foreground)
                Text(String(format: "%dMP", bindMega.wrappedValue.value.rawValue))
                    .font(.system(size: 13))
                    .foregroundStyle(ThemeColor.highlightedYellow)
            }
            .gesture(
                TapGesture(count: 2).onEnded { t in
                    bindMega.wrappedValue.value = bindMega.wrappedValue.default
                }
            )
            
            Spacer()
            
            PickerSlider(value: bindMega.value, items: MegaPixel.allCases, foregroundColor: ThemeColor.highlightedYellow, backgroundColor: .gray.opacity(0.2)) { i in
                
            }
            .frame(width: 200, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
}


struct SettingViewPreview: PreviewProvider {
    static var previews: some View {
        return SettingView(presenting: .constant(true))
            .ignoresSafeArea()
            .border(.white, width: 1)
            .background(.black)
    }
}
