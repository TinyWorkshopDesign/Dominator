//
//  PDFFile.swift
//  DominoPDF
//

import SwiftUI
import UniformTypeIdentifiers

/// Documento PDF esportabile tramite `.fileExporter` (salva su Mac, condivide su iOS/iPadOS).
struct PDFFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
