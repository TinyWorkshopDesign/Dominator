//
//  DominoGeneratorTests.swift
//  DominoPDFTests
//
//  Congela gli invarianti del cuore dell'app: i 452 valori validi dei fiducial
//  domino (verificati identici alla lista hardcoded di pyDominoPDF) e le regole
//  a 12 bit che li generano. Se una modifica cambia la lista, questi test falliscono.
//

import XCTest
import PDFKit
@testable import Dominator

final class DominoGeneratorTests: XCTestCase {

    // MARK: - Lista dei valori validi (riferimento: pyDominoPDF)

    func testValidDominoCount() {
        XCTAssertEqual(DominoGenerator.validDominoes.count, 452)
    }

    /// Primi e ultimi valori della lista, identici a quella del Python originale.
    func testFirstAndLastValues() {
        let values = DominoGenerator.validDominoes
        XCTAssertEqual(Array(values.prefix(10)),
                       [63, 95, 111, 119, 123, 125, 126, 159, 175, 183])
        XCTAssertEqual(Array(values.suffix(10)),
                       [3099, 3111, 3115, 3123, 3143, 3147, 3155, 3207, 3211, 3335])
    }

    /// Checksum dell'intera lista: blocca qualunque variazione, anche nei valori centrali.
    func testValuesChecksum() {
        XCTAssertEqual(DominoGenerator.validDominoes.reduce(0, +), 593_460)
    }

    // MARK: - Regole di validità a 12 bit

    func testEveryValueHasExactlySixDataPips() {
        for v in DominoGenerator.validDominoes {
            let row1 = (v >> 6) & 0x3F
            let row2 = v & 0x3F
            XCTAssertEqual(row1.nonzeroBitCount + row2.nonzeroBitCount, 6,
                           "il valore \(v) non ha 6 pip dati")
        }
    }

    func testNoPalindromesAndNoRotatedDuplicates() {
        let values = DominoGenerator.validDominoes
        let set = Set(values)
        for v in values {
            let reversed = reverse12(v)
            XCTAssertNotEqual(reversed, v, "il valore \(v) è un palindromo a 12 bit")
            XCTAssertFalse(set.contains(reversed),
                           "il valore \(v) e il suo ribaltato \(reversed) sono entrambi in lista")
        }
    }

    func testValuesAreAscendingAndInRange() {
        let values = DominoGenerator.validDominoes
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(values.count, Set(values).count)
        XCTAssertTrue(values.allSatisfy { (0...4095).contains($0) })
    }

    /// Reimplementazione indipendente dell'inversione dei 12 bit.
    private func reverse12(_ v: Int) -> Int {
        var r = 0
        for i in 0..<12 where (v & (1 << i)) != 0 { r |= 1 << (11 - i) }
        return r
    }
}

final class DominoConfigTests: XCTestCase {

    func testSanitizedClampsDegenerateValues() {
        var c = DominoConfig()
        c.pageWidth = -10
        c.pageHeight = 0
        c.pageCount = 9999
        c.rowSpacing = -5
        c.marginTop = -1
        let s = c.sanitized
        XCTAssertEqual(s.pageWidth, 0.5)
        XCTAssertEqual(s.pageHeight, 0.5)
        XCTAssertEqual(s.pageCount, 200)
        XCTAssertEqual(s.rowSpacing, 0)
        XCTAssertEqual(s.marginTop, 0)
    }

    func testScaleFactorWithZeroMeasuredIsOne() {
        var c = DominoConfig()
        c.xMeasured = 0
        c.yMeasured = 0
        XCTAssertEqual(c.xScaleFactor, 1.0)
        XCTAssertEqual(c.yScaleFactor, 1.0)
    }

    func testScaleFactorCompensatesShrinkage() {
        var c = DominoConfig()
        c.xStated = 100
        c.xMeasured = 99   // la stampa esce più piccola -> fattore > 1
        XCTAssertEqual(c.xScaleFactor, 100.0 / 99.0, accuracy: 1e-12)
    }

    /// Il ripristino della calibrazione in un'unità diversa deve preservare i fattori.
    func testCalibrationApplyPreservesFactorsAcrossUnits() {
        var saved = DominoConfig()
        saved.unit = .inch
        saved.xStated = 7.5
        saved.xMeasured = 7.45
        saved.yStated = 10.9
        saved.yMeasured = 10.93

        var restored = DominoConfig()   // default in mm
        restored.apply(saved.calibration)

        XCTAssertEqual(restored.xScaleFactor, saved.xScaleFactor, accuracy: 1e-12)
        XCTAssertEqual(restored.yScaleFactor, saved.yScaleFactor, accuracy: 1e-12)
        // I valori sono stati convertiti in mm.
        XCTAssertEqual(restored.xStated, 7.5 * 25.4, accuracy: 1e-9)
    }

    func testCalibrationSettingsCodableRoundTrip() throws {
        let original = CalibrationSettings(unit: .cm, xStated: 19.0, xMeasured: 18.9,
                                           yStated: 27.7, yMeasured: 27.75)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CalibrationSettings.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testPaperSizeMatching() {
        XCTAssertEqual(PaperSize.matching(width: 210, height: 297, unit: .mm), .a4)
        XCTAssertEqual(PaperSize.matching(width: 297, height: 210, unit: .mm), .a4)   // landscape
        XCTAssertEqual(PaperSize.matching(width: 8.5, height: 11, unit: .inch), .letter)
        XCTAssertEqual(PaperSize.matching(width: 123, height: 456, unit: .mm), .custom)
    }
}

final class PDFOutputTests: XCTestCase {

    /// Il PDF generato ha il numero di pagine richiesto e il mediaBox in punti corretto.
    func testGeneratedPDFPageCountAndSize() throws {
        var config = DominoConfig()        // A4 in mm
        config.pageCount = 3
        config.randomize = false

        let data = DominoGenerator.makePDF(config: config)
        XCTAssertFalse(data.isEmpty)

        let doc = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(doc.pageCount, 3)

        let box = try XCTUnwrap(doc.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(Double(box.width), 210 * 72.0 / 25.4, accuracy: 0.01)
        XCTAssertEqual(Double(box.height), 297 * 72.0 / 25.4, accuracy: 0.01)
    }

    /// Margini più grandi della pagina: nessun crash, PDF comunque valido.
    func testDegenerateMarginsDoNotCrash() throws {
        var config = DominoConfig()
        config.marginLeft = 500
        config.marginRight = 500
        let data = DominoGenerator.makePDF(config: config)
        let doc = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertEqual(doc.pageCount, 1)
    }
}
