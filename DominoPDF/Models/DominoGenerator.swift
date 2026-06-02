//
//  DominoGenerator.swift
//  DominoPDF
//
//  Porting in Swift dell'algoritmo di berncodes/pyDominoPDF (GPLv3):
//  generazione dei valori validi e rendering del PDF dei fiducial domino
//  per Shaper Origin.
//

import Foundation
import CoreGraphics
import CoreText

enum DominoGenerator {

    // MARK: - Geometria fissa del domino (in pollici, scalata per l'unità)

    private static let dominoWidthIn = 1.7
    private static let dominoHeightIn = 0.5
    private static let dominoPaddingIn = 0.125   // gap orizzontale tra domino
    private static let cornerRadiusIn = 0.10     // raggio angoli arrotondati
    private static let pipPaddingIn = 0.10
    private static let pipDiameterIn = 0.10
    private static let pipRadiusIn = 0.05

    // MARK: - Valori validi dei domino

    /// Replica `GenerateValidDominos(0, 4095)`:
    /// - 12 bit, riga1 = 6 bit alti, riga2 = 6 bit bassi;
    /// - il totale dei pip "dati" deve essere esattamente 6;
    /// - il valore non deve essere palindromo a 12 bit (domino speculare);
    /// - il valore ribaltato non deve già esistere (rotazione duplicata).
    static let validDominoes: [Int] = {
        var valid: [Int] = []
        var seen = Set<Int>()
        for x in 0...4095 {
            let row1 = (x >> 6) & 0x3F
            let row2 = x & 0x3F
            if row1.nonzeroBitCount + row2.nonzeroBitCount != 6 { continue }
            let reversed = reverse12(x)
            if reversed == x { continue }          // speculare
            if seen.contains(reversed) { continue } // rotazione già presente
            valid.append(x)
            seen.insert(x)
        }
        return valid
    }()

    /// Inverte i 12 bit di un valore.
    private static func reverse12(_ v: Int) -> Int {
        var r = 0
        for i in 0..<12 where (v & (1 << i)) != 0 {
            r |= 1 << (11 - i)
        }
        return r
    }

    // MARK: - Generazione PDF

    /// Crea il PDF completo e ne restituisce i dati.
    static func makePDF(config rawConfig: DominoConfig) -> Data {
        let config = rawConfig.sanitized
        let unitScale = config.unit.unitScale
        let ppu = config.unit.pointsPerUnit

        // Geometria nell'unità corrente.
        let dW = dominoWidthIn * unitScale
        let dH = dominoHeightIn * unitScale
        let dPad = dominoPaddingIn * unitScale
        let cR = cornerRadiusIn * unitScale
        let pipPad = pipPaddingIn * unitScale
        let pipDia = pipDiameterIn * unitScale
        let pipR = pipRadiusIn * unitScale

        // Dimensione pagina in punti PDF.
        let pageWpt = config.pageWidth * ppu
        let pageHpt = config.pageHeight * ppu
        var mediaBox = CGRect(x: 0, y: 0, width: pageWpt, height: pageHpt)

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        // Ordine dei valori (eventualmente mescolato).
        var values = validDominoes
        if config.randomize { values.shuffle() }
        var valueIndex = 0
        let valueCount = values.count

        // Area utile e numero di righe/colonne per pagina.
        let workW = config.pageWidth - (config.marginLeft + config.marginRight)
        let workH = config.pageHeight - (config.marginTop + config.marginBottom)
        let numRows = max(0, 1 + Int(floor((workH - dH) / (dH + config.rowSpacing))))
        let numCols = max(0, 1 + Int(floor((workW - dW) / (dW + dPad))))

        // Offset di centratura.
        var xOffset = 0.0
        if config.centerHorizontal && numCols > 0 {
            let used = Double(numCols) * (dW + dPad) - dPad
            xOffset = (workW - used) / 2.0
        }
        var yOffset = 0.0
        if config.centerVertical && numRows > 0 {
            let used = Double(numRows) * (dH + config.rowSpacing) - config.rowSpacing
            yOffset = (workH - used) / 2.0
        }

        // Pagine dei domino.
        for _ in 0..<config.pageCount {
            ctx.beginPDFPage(nil)
            ctx.saveGState()
            // unità -> punti, con correzione di scala applicata al contenuto.
            ctx.scaleBy(x: ppu * config.xScaleFactor, y: ppu * config.yScaleFactor)

            if config.marginBorder {
                ctx.setStrokeColor(red: 0, green: 0, blue: 1, alpha: 1)
                ctx.setLineWidth(0.01 * unitScale)
                ctx.stroke(CGRect(x: config.marginLeft, y: config.marginBottom,
                                  width: workW, height: workH))
            }

            if numRows > 0 && numCols > 0 {
                for py in 0..<numRows {
                    for px in 0..<numCols {
                        let dx = Double(px) * dW + Double(px) * dPad + config.marginLeft + xOffset
                        let dy = Double(py) * config.rowSpacing + Double(py) * dH + config.marginBottom + yOffset

                        if valueIndex >= valueCount {
                            valueIndex = 0
                            if config.randomize { values.shuffle() }
                        }
                        let value = values[valueIndex]
                        valueIndex += 1

                        placeDomino(ctx, x: dx, y: dy, value: value, config: config,
                                    dW: dW, dH: dH, cR: cR,
                                    pipPad: pipPad, pipDia: pipDia, pipR: pipR)
                    }
                }
            }

            if config.calibrationLines {
                drawCalibrationLines(ctx, config: config, unitScale: unitScale)
            }

            ctx.restoreGState()
            ctx.endPDFPage()
        }

        ctx.closePDF()
        return pdfData as Data
    }

    // MARK: - Disegno di un singolo domino

    private static func placeDomino(_ ctx: CGContext, x: Double, y: Double, value: Int,
                                    config: DominoConfig,
                                    dW: Double, dH: Double, cR: Double,
                                    pipPad: Double, pipDia: Double, pipR: Double) {
        // Corpo nero del domino.
        ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        let body = CGRect(x: x, y: y, width: dW, height: dH)
        if config.radiusCorners {
            let path = CGPath(roundedRect: body, cornerWidth: cR, cornerHeight: cR, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
        } else {
            ctx.fill(body)
        }

        // Pip bianchi. 2 righe x 8 posizioni; gli angoli (0 e 7) sono sempre presenti,
        // le posizioni 1-6 dipendono dai bit del valore.
        let row1 = (value >> 6) & 0x3F   // bit alti  -> riga py=0
        let row2 = value & 0x3F          // bit bassi -> riga py=1

        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        for py in 0..<2 {
            let bits = (py == 0) ? row1 : row2
            for px in 0..<8 {
                let on: Bool
                if px == 0 || px == 7 {
                    on = true
                } else {
                    // px=1 -> bit più significativo della riga (posizione 5)
                    on = (bits & (1 << (6 - px))) != 0
                }
                guard on else { continue }
                let cx = x + pipPad + pipR + Double(px * 2) * pipDia
                let cy = y + pipPad + pipR + Double(py * 2) * pipDia
                let rect = CGRect(x: cx - pipR, y: cy - pipR, width: pipR * 2, height: pipR * 2)
                ctx.fillEllipse(in: rect)
            }
        }

        // Valore numerico opzionale (sotto il domino).
        if config.printValues {
            drawText("\(value)", center: CGPoint(x: x + dW / 2, y: y - dH * 0.30),
                     fontSize: dH * 0.32, ctx: ctx)
        }
    }

    // MARK: - Linee di calibrazione

    /// Due linee di riferimento lungo i bordi (orizzontale in basso, verticale a sinistra),
    /// ciascuna con la propria misura: si stampano, si misurano col righello e si ricava
    /// la correzione di scala da inserire.
    private static func drawCalibrationLines(_ ctx: CGContext, config: DominoConfig, unitScale: Double) {
        let workW = config.pageWidth - config.marginLeft - config.marginRight
        let workH = config.pageHeight - config.marginTop - config.marginBottom
        let lw = 0.02 * unitScale
        let fs = 0.15 * unitScale

        ctx.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1)
        ctx.setLineWidth(lw)
        ctx.setLineCap(.butt)

        // Linea di quota orizzontale nel margine inferiore (spezzata dal testo).
        let yH = config.marginBottom * 0.5
        let x0 = config.marginLeft
        let x1 = config.pageWidth - config.marginRight
        let labelH = String(format: "%.1f %@", workW, config.unit.symbol)
        let gapH = textWidth(labelH, fontSize: fs) + fs * 1.0
        let xc = (x0 + x1) / 2
        ctx.move(to: CGPoint(x: x0, y: yH));         ctx.addLine(to: CGPoint(x: xc - gapH / 2, y: yH))
        ctx.move(to: CGPoint(x: xc + gapH / 2, y: yH)); ctx.addLine(to: CGPoint(x: x1, y: yH))
        ctx.strokePath()
        drawText(labelH, center: CGPoint(x: xc, y: yH), fontSize: fs, ctx: ctx)

        // Linea di quota verticale nel margine sinistro (spezzata dal testo, in asse).
        let xV = config.marginLeft * 0.5
        let y0 = config.marginBottom
        let y1 = config.pageHeight - config.marginTop
        let labelV = String(format: "%.1f %@", workH, config.unit.symbol)
        let gapV = textWidth(labelV, fontSize: fs) + fs * 1.0
        let yc = (y0 + y1) / 2
        ctx.move(to: CGPoint(x: xV, y: y0));         ctx.addLine(to: CGPoint(x: xV, y: yc - gapV / 2))
        ctx.move(to: CGPoint(x: xV, y: yc + gapV / 2)); ctx.addLine(to: CGPoint(x: xV, y: y1))
        ctx.strokePath()
        drawText(labelV, center: CGPoint(x: xV, y: yc), fontSize: fs, rotation: .pi / 2, ctx: ctx)
    }

    // MARK: - Testo (font monospace)

    private static func makeLine(_ string: String, fontSize: Double) -> CTLine {
        let font = CTFontCreateWithName("Menlo" as CFString, CGFloat(fontSize), nil)
        let attrs: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]
        let attr = CFAttributedStringCreate(nil, string as CFString, attrs as CFDictionary)!
        return CTLineCreateWithAttributedString(attr)
    }

    /// Larghezza tipografica del testo (per dimensionare il gap della linea di quota).
    private static func textWidth(_ string: String, fontSize: Double) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(makeLine(string, fontSize: fontSize), nil, nil, nil))
    }

    /// Disegna testo nero centrato sul punto dato, con rotazione opzionale (radianti).
    private static func drawText(_ string: String, center: CGPoint, fontSize: Double,
                                 rotation: CGFloat = 0, ctx: CGContext) {
        let line = makeLine(string, fontSize: fontSize)
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        if rotation != 0 { ctx.rotate(by: rotation) }
        ctx.textPosition = CGPoint(x: -width / 2, y: -(ascent - descent) / 2)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
