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
                    megaPixelPickerCell()
                }
                
                Section("Format") {
                    let currentSaveOption = sharedPropertyies.raw.rawOption.value
                    clickCell(title: "APPLE Style", isSelected: currentSaveOption.contains(.apple)) {
                        sharedPropertyies.raw.rawOption.value.insert(.apple)
                    }
                    
                    let allSaveOptions: [RAWSaveOption] = [
                        .heif,
                        .raw,
                        [.heif, .raw],
                    ]
                    
                    ForEach(allSaveOptions, id: \.rawValue) { the in
                        var title: String {
                            if the.contains([.heif, .raw]) {
                                return "RAW + HEIF"
                            } else if the.contains(.raw) {
                                return "RAW"
                            } else if the.contains(.heif) {
                                return "HEIF"
                            }
                            return ""
                        }
                        var isSelected: Bool {
                            if currentSaveOption.contains(.apple) {
                                return false
                            }
                            return currentSaveOption == the
                        }
                        clickCell(title: title, isSelected: isSelected) {
                            sharedPropertyies.raw.rawOption.value = the
                        }
                    }
                }
                
                if !sharedPropertyies.raw.rawOption.value.contains(.apple) {
                    Section("Raw Filter") {
                        sliderCell(title: "Boost", property: $sharedPropertyies.raw.boostAmount)
                    }
                }
                
                Section("Theme Color") {
                    let allCases: [ThemeColor] = [.system, .light, .dark]
                    ForEach(allCases, id: \.self) { the in
                        clickCell(title: the.title, isSelected: sharedPropertyies.color.themeColor.value == the) {
                            sharedPropertyies.color.themeColor.value = the
                        }
                    }
                }
            }
            .listStyle(.grouped)
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeColor.foreground)
                Text(String(format: "%.02f", property.value.wrappedValue))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeColor.highlightedYellow)
            }
            .gesture(
                TapGesture(count: 2).onEnded { t in
                    property.wrappedValue.reset()
                }
            )
            
            Spacer()
            
            BoundSlider(value: property.value, range: old.minValue...old.maxValue, foregroundColor: ThemeColor.highlightedYellow, backgroundColor: .gray.opacity(0.2)) { i in
                
            }
            .frame(width: 200, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
    
    @ViewBuilder func megaPixelPickerCell() -> some View {
        let bindMega = $sharedPropertyies.output.maxMegaPixel
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text("Max Megapixels")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeColor.foreground)
                Text(String(format: "%d mp", bindMega.wrappedValue.value.rawValue))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeColor.highlightedYellow)
            }
            .gesture(
                TapGesture(count: 2).onEnded { t in
                    bindMega.wrappedValue.reset()
                }
            )
            
            Spacer()
            
            PickerSlider(value: bindMega.value, items: MegaPixel.allCases, foregroundColor: ThemeColor.highlightedYellow, backgroundColor: .gray.opacity(0.2)) { i in
                
            }
            .frame(width: 200, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }
        
    @ViewBuilder func clickCell(title: String, isSelected: Bool, click: @escaping () -> Void) -> some View {
        Button {
            if !isSelected {
                click()
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeColor.foreground)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(ThemeColor.highlightedYellow)
                }
            }
        }
    }
}


struct SettingViewPreview: PreviewProvider {
    static var previews: some View {
        return SettingView(presenting: .constant(true))
    }
}
