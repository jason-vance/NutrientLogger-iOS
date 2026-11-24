//
//  FdcPortionReadingTests.swift
//  Nutrient LoggerTests
//
//  Created by Claude on 11/23/26.
//

import Foundation
import SQLite
import Testing

/// Most SR Legacy portions store `amount` as an INTEGER. SQLite.swift reads those as nil through a
/// `Double?` expression, which turned "4 oz = 113 g" into "1 oz = 113 g".
struct FdcPortionReadingTests {

    @Test func integerAmount_isReadAndScalesTheGramWeight() async throws {
        let db = try await makeDatabase(amountSQL: "4", gramWeightSQL: "113")

        let portions = try db.getPortions(1)

        #expect(portions.count == 1)
        #expect(portions.first?.amount == 4)

        let portion = BundledFdcDatabase.portionFrom(try #require(portions.first))
        #expect(portion.amount == 4)
        #expect(portion.name == "oz")
        #expect(portion.gramWeight == 28.25)
    }

    @Test func realAmount_isStillRead() async throws {
        let db = try await makeDatabase(amountSQL: "0.5", gramWeightSQL: "14.2")

        #expect(try db.getPortions(1).first?.amount == 0.5)
    }

    @Test func missingAmount_isNil() async throws {
        let db = try await makeDatabase(amountSQL: "NULL", gramWeightSQL: "28")

        #expect(try db.getPortions(1).first?.amount == nil)
    }

    /// A one-food database shaped like fdc_legacy.db, with a single "oz" portion.
    private func makeDatabase(amountSQL: String, gramWeightSQL: String) async throws -> FdcSearchableFoodDatabase {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fdc-portion-test-\(UUID().uuidString).db")
        let connection = try Connection(url.path)
        try connection.execute("""
            CREATE TABLE Food (fdc_id INTEGER, data_type TEXT, description TEXT, food_category_id INTEGER);
            CREATE TABLE Portion (
                id INTEGER, fdc_id INTEGER, seq_num INTEGER, amount INTEGER, measure_unit_id INTEGER,
                portion_description TEXT, modifier TEXT, gram_weight INTEGER
            );
            INSERT INTO Food VALUES (1, 'sr_legacy_food', 'Cream puff', NULL);
            INSERT INTO Portion VALUES (1, 1, 1, \(amountSQL), 9999, NULL, 'oz', \(gramWeightSQL));
            """)
        return try await FdcSearchableFoodDatabase(dbPath: url)
    }
}
