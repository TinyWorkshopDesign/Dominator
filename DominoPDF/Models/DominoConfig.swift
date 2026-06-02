//
//  DominoConfig.swift
//  DominoPDF
//
//  Porting fedele dei parametri di pyDominoPDF (berncodes/pyDominoPDF, GPLv3).
//

import Foundation

/// Unità di misura supportate, con il fattore di scala usato dall'originale.
enum DominoUnit: String, CaseIterable, Identifiable, Codable {
    case inch
    case mm
    case cm

    var id: String { rawValue }

    /// Etichetta mostrata nell'interfaccia.
    var label: String {
        switch self {
        case .inch: return "Inches (in)"
        case .mm:   return "Millimeters (mm)"
        case .cm:   return "Centimeters (cm)"
        }
    }

    /// Simbolo breve.
    var symbol: String {
        switch self {
        case .inch: return "in"
        case .mm:   return "mm"
        case .cm:   return "cm"
        }
    }

    /// _unit_scale dell'originale: converte la geometria fissa (definita in pollici)
    /// nell'unità selezionata, così il domino resta fisicamente sempre 1.7" x 0.5".
    var unitScale: Double {
        switch self {
        case .inch: return 1.0
        case .mm:   return 25.4
        case .cm:   return 2.54
        }
    }

    /// Punti PDF per unità (1 pollice = 72 punti).
    var pointsPerUnit: Double {
        switch self {
        case .inch: return 72.0
        case .mm:   return 72.0 / 25.4
        case .cm:   return 72.0 / 2.54
        }
    }

    /// Millimetri per una unità (per i formati carta standard).
    var toMillimeters: Double {
        switch self {
        case .inch: return 25.4
        case .mm:   return 1.0
        case .cm:   return 10.0
        }
    }

    /// Converte un valore in mm verso questa unità, arrotondato a 2 decimali.
    func fromMillimeters(_ mm: Double) -> Double {
        (mm / toMillimeters * 100).rounded() / 100
    }
}

/// Formati carta standard (dimensioni in mm, verticale). `custom` = personalizzato.
enum PaperSize: String, CaseIterable, Identifiable {
    case custom
    case a0, a1, a2, a3, a4, a5
    case letter, legal, tabloid, ansiC, ansiD, ansiE

    var id: String { rawValue }

    var label: String {
        switch self {
        case .custom:  return "Custom"
        case .a0:      return "A0"
        case .a1:      return "A1"
        case .a2:      return "A2"
        case .a3:      return "A3"
        case .a4:      return "A4"
        case .a5:      return "A5"
        case .letter:  return "US Letter (ANSI A)"
        case .legal:   return "US Legal"
        case .tabloid: return "US Tabloid (ANSI B)"
        case .ansiC:   return "ANSI C"
        case .ansiD:   return "ANSI D"
        case .ansiE:   return "ANSI E"
        }
    }

    /// Dimensioni in millimetri (larghezza, altezza), verticale.
    var mm: (w: Double, h: Double)? {
        switch self {
        case .custom:  return nil
        case .a0:      return (841, 1189)
        case .a1:      return (594, 841)
        case .a2:      return (420, 594)
        case .a3:      return (297, 420)
        case .a4:      return (210, 297)
        case .a5:      return (148, 210)
        case .letter:  return (215.9, 279.4)
        case .legal:   return (215.9, 355.6)
        case .tabloid: return (279.4, 431.8)
        case .ansiC:   return (431.8, 558.8)
        case .ansiD:   return (558.8, 863.6)
        case .ansiE:   return (863.6, 1117.6)
        }
    }

    /// Riconosce il formato dalle dimensioni di pagina (in entrambi gli orientamenti).
    static func matching(width: Double, height: Double, unit: DominoUnit) -> PaperSize {
        let wMM = width * unit.toMillimeters
        let hMM = height * unit.toMillimeters
        for size in allCases {
            guard let d = size.mm else { continue }
            let portrait = abs(wMM - d.w) < 1.0 && abs(hMM - d.h) < 1.0
            let landscape = abs(wMM - d.h) < 1.0 && abs(hMM - d.w) < 1.0
            if portrait || landscape { return size }
        }
        return .custom
    }
}

/// Tutti i parametri configurabili, equivalenti al form web di pyDominoPDF.
struct DominoConfig: Codable, Equatable {
    var unit: DominoUnit = .mm

    // Pagina (valori espressi nell'unità selezionata) — default A4 in mm
    var pageWidth: Double = 210
    var pageHeight: Double = 297
    var marginTop: Double = 10
    var marginLeft: Double = 10
    var marginRight: Double = 10
    var marginBottom: Double = 10
    var pageCount: Int = 1

    // Layout
    var rowSpacing: Double = 6
    var centerHorizontal: Bool = false
    var centerVertical: Bool = false

    // Opzioni domino
    var randomize: Bool = true
    var printValues: Bool = false
    var calibrationLines: Bool = false
    var marginBorder: Bool = false
    var radiusCorners: Bool = true

    // Correzione di scala (per compensare l'errore della stampante) — domino nominale in mm
    var xStated: Double = 43.18
    var xMeasured: Double = 43.18
    var yStated: Double = 12.7
    var yMeasured: Double = 12.7

    /// Fattore di correzione: ingrandisce/riduce per compensare la stampa.
    /// Se la stampa esce più piccola del previsto, il rapporto > 1 la ingrandisce.
    var xScaleFactor: Double { xMeasured == 0 ? 1.0 : xStated / xMeasured }
    var yScaleFactor: Double { yMeasured == 0 ? 1.0 : yStated / yMeasured }

    /// Limiti di sicurezza per evitare PDF degeneri.
    var sanitized: DominoConfig {
        var c = self
        c.pageWidth = max(0.5, pageWidth)
        c.pageHeight = max(0.5, pageHeight)
        c.pageCount = min(max(1, pageCount), 200)
        c.rowSpacing = max(0, rowSpacing)
        c.marginTop = max(0, marginTop)
        c.marginLeft = max(0, marginLeft)
        c.marginRight = max(0, marginRight)
        c.marginBottom = max(0, marginBottom)
        return c
    }
}
