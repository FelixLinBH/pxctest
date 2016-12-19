//
//  PartitionManagerTests.swift
//  pxctest
//
//  Created by Johannes Plunien on 19/12/16.
//  Copyright © 2016 Johannes Plunien. All rights reserved.
//

import FBSimulatorControl
import XCTest
@testable import PXCTestKit

class TestAllocator: SimulatorAllocator {

    func allocateSimulator(with configuration: FBSimulatorConfiguration, options: FBSimulatorAllocationOptions) throws -> FBSimulator {
        let simulator = FBSimulator()
        simulator.configuration = configuration
        return simulator
    }

}

class PartitionManagerTests: XCTestCase {

    func testAllocateSinglePartition() throws {
        let simulators = try PartitionManager(partitions: 1).allocateSimulators(allocator: TestAllocator(), simulatorAllocationOptions: [], simulatorConfigurations: fixtures.simulatorConfigurations)
        XCTAssertEqual(simulators.count, 2)
    }

    func testAllocateMultipleParitions() throws {
        let simulators = try PartitionManager(partitions: 6).allocateSimulators(allocator: TestAllocator(), simulatorAllocationOptions: [], simulatorConfigurations: fixtures.simulatorConfigurations)
        XCTAssertEqual(simulators.count, 12)
    }

    func testParitionNames() {
        XCTAssertEqual(
            PartitionManager(partitions: 1).partitionNames(for: ["UnitTest", "UITests"]),
            ["UnitTest", "UITests"]
        )
        XCTAssertEqual(
            PartitionManager(partitions: 3).partitionNames(for: ["UnitTest", "UITests"]),
            ["UnitTest-part1", "UnitTest-part2", "UnitTest-part3", "UITests-part1", "UITests-part2", "UITests-part3"]
        )
    }

}
