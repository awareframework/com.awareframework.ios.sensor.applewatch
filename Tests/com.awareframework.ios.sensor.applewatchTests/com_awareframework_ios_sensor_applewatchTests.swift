//
//  com_awareframework_ios_sensor_applewatchTests.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/05.
//


import XCTest
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared
import com_awareframework_ios_sensor_uwb_shared
@testable import com_awareframework_ios_sensor_applewatch_iOS

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Realm.Configuration.defaultConfiguration.inMemoryIdentifier = self.name
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testA(){
        
    }

    // MARK: - Rows received from the watch

    private func decodedRows(_ json: String) -> [[String: Any]] {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]]) ?? []
    }

    private func makeSensor() -> AppleWatchSensor {
        AppleWatchSensor(AppleWatchSensor.Config().apply { config in
            config.dbPath = "watch_receive_test_\(UUID().uuidString)"
        })
    }

    /// Numbers with no fractional part (a heart rate of 72.0) used to become Int64 and were then
    /// read as the model's default (0) by `as? Double`
    func testWholeNumbersKeepTheirValue() throws {
        let sensor = makeSensor()
        let rows = decodedRows(#"[{"timestamp": 1795060031991, "hr": 72.0, "label": ""}, {"timestamp": 1795060032991, "hr": 71.5, "label": ""}]"#)
        let models = try XCTUnwrap(sensor.watchModels(tableName: AWHeartRateSensorData.databaseTableName, records: rows))
        let hr = models.compactMap { ($0 as? AWHeartRateSensorData)?.hr }
        XCTAssertEqual(hr, [72.0, 71.5])
        XCTAssertEqual((models.first as? AWHeartRateSensorData)?.timestamp, 1_795_060_031_991)
    }

    /// UWB rows from the watch (AWUWBSensor) used to be rejected as "Unsupported table"
    func testUWBRowsAreAcceptedAndTheirTableExists() throws {
        let sensor = makeSensor()
        let rows = decodedRows(#"[{"timestamp": 1795060031991, "label": "", "distance": 2.0, "directionX": 0.5, "directionY": 0, "directionZ": -0.5, "horizontalAngle": 1.25}]"#)
        let models = try XCTUnwrap(sensor.watchModels(tableName: AWUWBData.databaseTableName, records: rows),
                                   "ios_watch_uwb is a known table")
        let uwb = try XCTUnwrap(models.first as? AWUWBData)
        XCTAssertEqual(uwb.distance, 2.0)
        XCTAssertEqual(uwb.directionY, 0.0)
        XCTAssertEqual(uwb.horizontalAngle, 1.25)

        let engine = try XCTUnwrap(sensor.dbEngine as? SQLiteEngine)
        XCTAssertTrue(try engine.getAllTableNames().contains(AWUWBData.databaseTableName), "the table is created")
        let saved = expectation(description: "saved")
        engine.save(models) { error in
            XCTAssertNil(error)
            saved.fulfill()
        }
        wait(for: [saved], timeout: 5)
        let reader = Engine.Builder().setPath(sensor.CONFIG.dbPath).setType(.sqlite)
            .setTableName(AWUWBData.databaseTableName).build()
        XCTAssertEqual(reader.fetch(filter: nil, limit: nil)?.first?["distance"] as? Double, 2.0, "read back for sync")
    }
}
