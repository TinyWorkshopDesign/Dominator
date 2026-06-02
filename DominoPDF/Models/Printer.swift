//
//  Printer.swift
//  DominoBuddy
//
//  Stampa del PDF, funzionante su macOS e iOS/iPadOS.
//

import PDFKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum Printer {
    static func printPDF(_ data: Data) {
        guard !data.isEmpty, let doc = PDFDocument(data: data) else { return }

        #if os(macOS)
        let info = NSPrintInfo.shared
        info.horizontalPagination = .fit
        info.verticalPagination = .fit
        if let op = doc.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: true) {
            op.showsPrintPanel = true
            op.run()
        }
        #else
        let controller = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Dominator"
        controller.printInfo = printInfo
        controller.printingItem = data
        controller.present(animated: true, completionHandler: nil)
        #endif
    }
}
