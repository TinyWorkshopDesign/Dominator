//
//  ContentView.swift
//  DominoPDF
//

import SwiftUI

struct ContentView: View {
    @State private var config = DominoConfig()
    @State private var pdfData = Data()
    @State private var showExporter = false

    var body: some View {
        NavigationSplitView {
            SettingsForm(config: $config)
                .navigationTitle("Dominator")
                #if os(macOS)
                .frame(minWidth: 320)
                #endif
        } detail: {
            PreviewPane(pdfData: pdfData,
                        validCount: DominoGenerator.validDominoes.count,
                        onExport: { showExporter = true },
                        onRegenerate: { regenerate() },
                        onPrint: { Printer.printPDF(pdfData) })
        }
        .task(id: config) { regenerate() }
        .fileExporter(
            isPresented: $showExporter,
            document: PDFFile(data: pdfData),
            contentType: .pdf,
            defaultFilename: "Domino_\(timestamp()).pdf"
        ) { _ in }
    }

    private func regenerate() {
        pdfData = DominoGenerator.makePDF(config: config)
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }
}

/// Pannello di anteprima del PDF con pulsanti di rigenerazione ed esportazione.
private struct PreviewPane: View {
    let pdfData: Data
    let validCount: Int
    let onExport: () -> Void
    let onRegenerate: () -> Void
    let onPrint: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if pdfData.isEmpty {
                ContentUnavailableView("No preview",
                                       systemImage: "doc.richtext",
                                       description: Text("Adjust the settings to generate the PDF."))
            } else {
                PDFKitView(data: pdfData)
            }
        }
        .navigationTitle("Preview")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onPrint()
                } label: {
                    Label("Print", systemImage: "printer")
                }
                .disabled(pdfData.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    onExport()
                } label: {
                    Label("Export PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(pdfData.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("\(validCount) valid dominoes available")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(.bar)
        }
    }
}

#Preview {
    ContentView()
}
