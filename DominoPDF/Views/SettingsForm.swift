//
//  SettingsForm.swift
//  DominoBuddy
//

import SwiftUI

struct SettingsForm: View {
    @Binding var config: DominoConfig

    // Stato di espansione dei gruppi (collassabili).
    @State private var showUnits = true
    @State private var showPage = true
    @State private var showMargins = false
    @State private var showLayout = false
    @State private var showOptions = true
    @State private var showScale = false

    private var u: String { config.unit.symbol }

    private var workW: Double { config.pageWidth - config.marginLeft - config.marginRight }
    private var workH: Double { config.pageHeight - config.marginTop - config.marginBottom }
    private var workArea: [Double] { [workW, workH] }

    /// Selezione formato carta derivata dalle dimensioni correnti (mostra "Custom" se non combacia).
    private var paperSelection: Binding<PaperSize> {
        Binding(
            get: { PaperSize.matching(width: config.pageWidth, height: config.pageHeight, unit: config.unit) },
            set: { newValue in
                guard let d = newValue.mm else { return }
                let w = config.unit.fromMillimeters(d.w)   // lato corto (verticale)
                let h = config.unit.fromMillimeters(d.h)   // lato lungo (verticale)
                let landscape = config.pageWidth > config.pageHeight
                config.pageWidth = landscape ? h : w
                config.pageHeight = landscape ? w : h
            }
        )
    }

    private var isLandscape: Bool { config.pageWidth > config.pageHeight }

    private func rotatePage() {
        let oldWidth = config.pageWidth
        config.pageWidth = config.pageHeight
        config.pageHeight = oldWidth
    }

    var body: some View {
        Form {
            Section("Units", isExpanded: $showUnits) {
                Picker("Unit", selection: $config.unit) {
                    ForEach(DominoUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            }

            Section("Page (\(u))", isExpanded: $showPage) {
                Picker("Paper size", selection: paperSelection) {
                    ForEach(PaperSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                HStack {
                    Text("Orientation")
                    Spacer()
                    Button {
                        rotatePage()
                    } label: {
                        Label(isLandscape ? "Landscape" : "Portrait",
                              systemImage: isLandscape ? "rectangle" : "rectangle.portrait")
                    }
                    .buttonStyle(.bordered)
                }
                numberRow("Width", value: $config.pageWidth)
                numberRow("Height", value: $config.pageHeight)
                Stepper("Pages: \(config.pageCount)",
                        value: $config.pageCount, in: 1...200)
            }

            Section("Margins (\(u))", isExpanded: $showMargins) {
                numberRow("Top", value: $config.marginTop)
                numberRow("Bottom", value: $config.marginBottom)
                numberRow("Left", value: $config.marginLeft)
                numberRow("Right", value: $config.marginRight)
            }

            Section("Layout", isExpanded: $showLayout) {
                numberRow("Row spacing", value: $config.rowSpacing)
                Toggle("Center horizontally", isOn: $config.centerHorizontal)
                Toggle("Center vertically", isOn: $config.centerVertical)
            }

            Section("Domino options", isExpanded: $showOptions) {
                Toggle("Random order", isOn: $config.randomize)
                Toggle("Rounded corners", isOn: $config.radiusCorners)
                Toggle("Show numeric values", isOn: $config.printValues)
                Toggle("Margin box", isOn: $config.marginBorder)
                Toggle("Calibration lines", isOn: $config.calibrationLines)
            }

            Section("Scale correction", isExpanded: $showScale) {
                numberRow("X stated", value: $config.xStated)
                numberRow("X measured", value: $config.xMeasured)
                numberRow("Y stated", value: $config.yStated)
                numberRow("Y measured", value: $config.yMeasured)
                Text(scaleHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset to defaults") {
                    config = DominoConfig()
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        // Con la calibrazione attiva: apri "Scale correction" e precompila gli "stated".
        .onChange(of: config.calibrationLines) { _, on in
            if on {
                withAnimation { showScale = true }
                fillCalibrationStated()
            }
        }
        // Mantieni gli "stated" allineati alle linee di calibrazione quando cambiano pagina/margini.
        .onChange(of: workArea) { _, _ in
            if config.calibrationLines { fillCalibrationStated() }
        }
    }

    private var scaleHint: String {
        if config.calibrationLines {
            return "Calibration on: \"stated\" values are the lengths of the two reference lines (\(String(format: "%.1f", workW)) \(u) × \(String(format: "%.1f", workH)) \(u)). Print, measure each line with a ruler and type the result in \"measured\". X factor: \(String(format: "%.4f", config.xScaleFactor)), Y: \(String(format: "%.4f", config.yScaleFactor))."
        } else {
            return "Print a test, measure a domino with a ruler and enter the values to compensate for printer error. X factor: \(String(format: "%.4f", config.xScaleFactor)), Y: \(String(format: "%.4f", config.yScaleFactor))."
        }
    }

    /// Imposta gli "stated" (e azzera la correzione) sulle lunghezze delle linee di calibrazione.
    private func fillCalibrationStated() {
        let w = (workW * 100).rounded() / 100
        let h = (workH * 100).rounded() / 100
        config.xStated = w; config.xMeasured = w
        config.yStated = h; config.yMeasured = h
    }

    @ViewBuilder
    private func numberRow(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                #if os(macOS)
                .textFieldStyle(.roundedBorder)
                #endif
        }
    }
}
