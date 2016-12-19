//
//  PartitionManager.swift
//  pxctest
//
//  Created by Johannes Plunien on 19/12/16.
//  Copyright © 2016 Johannes Plunien. All rights reserved.
//

import FBSimulatorControl
import Foundation

protocol SimulatorAllocator {

    func allocateSimulator(with configuration: FBSimulatorConfiguration, options: FBSimulatorAllocationOptions) throws -> FBSimulator

}

extension FBSimulatorPool: SimulatorAllocator {
}

final class PartitionManager {

    private let partitions: Int

    init(partitions: Int) {
        self.partitions = partitions
    }

    func allocateSimulators(allocator: SimulatorAllocator, simulatorAllocationOptions: FBSimulatorAllocationOptions, simulatorConfigurations: [FBSimulatorConfiguration]) throws -> [FBSimulator] {
        var simulators: [FBSimulator] = []
        for _ in 0..<partitions {
            for simulatorConfiguration in simulatorConfigurations {
                simulators.append(try allocator.allocateSimulator(with: simulatorConfiguration, options: simulatorAllocationOptions))
            }
        }
        return simulators
    }

    func partitionNames(for targets: [String]) -> [String] {
        guard partitions > 1 else { return targets }
        var partitionedTargets: [String] = []
        for target in targets {
            for partition in 0..<partitions {
                partitionedTargets.append("\(target)-part\(partition+1)")
            }
        }
        return partitionedTargets
    }

    func partitionTargets(simulator: FBSimulator, targets: [FBXCTestRunTarget]) -> [FBXCTestRunTarget] {
        guard partitions > 1 else { return targets }
        // FIXME
        return targets
    }

}
