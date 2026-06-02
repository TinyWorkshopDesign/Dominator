//
//  DominoPDFApp.swift
//  DominoPDF
//
//  App nativa multipiattaforma (macOS / iPadOS / iOS) per generare PDF
//  stampabili di fiducial domino per Shaper Origin.
//  Porting di berncodes/pyDominoPDF (GPLv3).
//

import SwiftUI

@main
struct DominoPDFApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 720)
        #endif
    }
}
