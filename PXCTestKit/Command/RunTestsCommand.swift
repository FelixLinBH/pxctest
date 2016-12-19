//
//  RunTestsCommand.swift
//  pxctest
//
//  Created by Johannes Plunien on 23/11/16.
//  Copyright © 2016 Johannes Plunien. All rights reserved.
//

import FBSimulatorControl
import Foundation

final class RunTestsCommand: Command {

    enum RuntimeError: Error {
        case testRunHadFailures(Int)
        case testRunHadErrors([TestError])
    }

    struct TestError {
        let simulator: FBSimulator
        let target: String
        let errors: [Error]
        let crashes: [FBDiagnostic]
    }

    private var bundleIDS: [String] = []
    private let context: Context
    private let reporterRegistry: ReporterRegistry
    private var simulators: [FBSimulator] = []

    init(context: Context) {
        self.context = context
        self.reporterRegistry = ReporterRegistry(context: context)
    }

    func abort() {
        for simulator in simulators {
            for bundleID in bundleIDS {
                do {
                    try simulator.killApplication(withBundleID: bundleID)
                }
                catch {
                    context.consoleOutput.write(line: "\(error)")
                }
            }
        }
        context.consoleOutput.write(line: "\(ANSI.red)Test run was aborted\(ANSI.reset)")
    }

    func run() throws {
        try run(control: FBSimulatorControl.withContext(context))
    }

    func run(control: FBSimulatorControl) throws {
        let testRun = try FBXCTestRun.withTestRunFile(atPath: context.testRun.path).build()
        let partitionManager = PartitionManager(partitions: context.partitions)

        try context.outputManager.reset(
            targets: partitionManager.partitionNames(for: testRun.targets.map({ $0.name })),
            simulatorConfigurations: context.simulatorConfigurations
        )

        simulators = try partitionManager.allocateSimulators(
            allocator: control.pool,
            simulatorAllocationOptions: context.simulatorAllocationOptions,
            simulatorConfigurations: context.simulatorConfigurations
        )

        try simulators.loadDefaults(context: context)
        try simulators.overrideWatchDogTimer(targets: testRun.targets)
        try simulators.boot(context: context)

        let targets = partitionManager.partitionTargets(simulator: simulators.first!, targets: testRun.targets)

        let testErrors = try test(simulators: simulators, targets: targets)
        try context.outputManager.extractDiagnostics(simulators: simulators, targets: testRun.targets, testErrors: testErrors)

        if testErrors.count > 0 {
            throw RuntimeError.testRunHadErrors(testErrors)
        }

        try reporterRegistry.finishReporting(consoleOutput: context.consoleOutput)
    }

    // MARK: - Private

    private func test(simulators: [FBSimulator], targets: [FBXCTestRunTarget]) throws -> [TestError] {
        var errors: [TestError] = []

        for target in targets {
            if context.testsToRun.count > 0 && context.testsToRun[target.name] == nil {
                continue
            }

            var testsToRun = target.testLaunchConfiguration.testsToRun
            if context.testsToRun.count > 0, let targetTestsToRun = context.testsToRun[target.name] {
                testsToRun = target.testLaunchConfiguration.testsToRun.union(targetTestsToRun)
            }
            let testEnvironment = Environment.prepare(forRunningTests: target.testLaunchConfiguration.testEnvironment, with: context.environment)
            let testLaunchConfigurartion = target.testLaunchConfiguration
                .withTestsToRun(testsToRun)
                .withTestEnvironment(testEnvironment)

            try simulators.install(applications: target.applications)
            try simulators.startTest(testLaunchConfigurartion: testLaunchConfigurartion, target: target, reporterRegistry: reporterRegistry)

            bundleIDS += target.applications.flatMap({ $0.bundleID })

            for simulator in simulators {
                let testManagerResults = simulator.resourceSink.testManagers.flatMap { $0.waitUntilTestingHasFinished(withTimeout: context.timeout) }
                if testManagerResults.reduce(true, { $0 && $1.didEndSuccessfully }) {
                    continue
                }
                let error = TestError(
                    simulator: simulator,
                    target: target.name,
                    errors: testManagerResults.flatMap { $0.error },
                    crashes: testManagerResults.flatMap { $0.crashDiagnostic }
                )
                errors.append(error)
            }
        }

        return errors
    }

}
