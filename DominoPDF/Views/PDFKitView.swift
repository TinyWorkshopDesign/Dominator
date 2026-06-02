//
//  PDFKitView.swift
//  DominoPDF
//
//  Wrapper di PDFView funzionante sia su macOS sia su iOS/iPadOS.
//

import SwiftUI
import PDFKit

#if os(macOS)
import AppKit

struct PDFKitView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .windowBackgroundColor
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        let doc = PDFDocument(data: data)
        if view.document?.dataRepresentation() != data {
            view.document = doc
        }
    }
}
#else
import UIKit

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.dataRepresentation() != data {
            view.document = PDFDocument(data: data)
        }
    }
}
#endif
