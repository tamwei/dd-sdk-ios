/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

@testable import Datadog

extension CrashReportingFeature {
    /// Mocks the Crash Reporting feature instance which doesn't load crash reports.
    static func mockNoOp() -> CrashReportingFeature {
        return CrashReportingFeature(
            configuration: .mockWith(crashReportingPlugin: NoopCrashReportingPlugin()),
            commonDependencies: .mockAny()
        )
    }

    static func mockWith(
        configuration: FeaturesConfiguration.CrashReporting = .mockAny(),
        dependencies: FeaturesCommonDependencies = .mockAny()
    ) -> CrashReportingFeature {
        return CrashReportingFeature(
            configuration: configuration,
            commonDependencies: dependencies
        )
    }
}

internal class CrashReportingPluginMock: DDCrashReportingPluginType {
    /// The crash report loaded by this plugin.
    var pendingCrashReport: DDCrashReport?
    /// If the plugin was asked to delete the crash report.
    var hasPurgedCrashReport: Bool?
    /// Custom app state data injected to the plugin.
    var injectedContextData: Data?

    func readPendingCrashReport(completion: (DDCrashReport?) -> Bool) {
        hasPurgedCrashReport = completion(pendingCrashReport)
        didReadPendingCrashReport?()
    }

    /// Notifies the `readPendingCrashReport(completion:)` return.
    var didReadPendingCrashReport: (() -> Void)?

    func inject(context: Data) {
        injectedContextData = context
        didInjectContext?()
    }

    /// Notifies the `inject(context:)` return.
    var didInjectContext: (() -> Void)?
}

internal class NoopCrashReportingPlugin: DDCrashReportingPluginType {
    func readPendingCrashReport(completion: (DDCrashReport?) -> Bool) {}
    func inject(context: Data) {}
}

internal class CrashContextProviderMock: CrashContextProviderType {
    private(set) var currentCrashContext: CrashContext
    var onCrashContextChange: ((CrashContext) -> Void)?

    init(initialCrashContext: CrashContext = .mockAny()) {
        self.currentCrashContext = initialCrashContext
    }

    func update(lastRUMViewEvent: RUMEvent<RUMViewEvent>) {}
    func update(lastTrackingConsent: TrackingConsent) {}
}

class CrashReportingIntegrationMock: CrashReportingIntegration {
    var sentCrashReport: DDCrashReport?
    var sentCrashContext: CrashContext?

    func send(crashReport: DDCrashReport, with crashContext: CrashContext) {
        sentCrashReport = crashReport
        sentCrashContext = crashContext
        didSendCrashReport?()
    }

    var didSendCrashReport: (() -> Void)?
}

extension CrashContext: EquatableInTests {}

extension CrashContext {
    static func mockAny() -> CrashContext {
        return mockWith()
    }

    static func mockWith(
        lastTrackingConsent: TrackingConsent = .granted,
        lastRUMViewEvent: RUMEvent<RUMViewEvent>? = nil,
        lastUserInfo: UserInfo = .mockAny()
    ) -> CrashContext {
        return CrashContext(
            lastTrackingConsent: lastTrackingConsent,
            lastRUMViewEvent: lastRUMViewEvent,
            lastUserInfo: lastUserInfo
        )
    }

    static func mockRandom() -> CrashContext {
        return CrashContext(
            lastTrackingConsent: .mockRandom(),
            lastRUMViewEvent: .mockRandomWith(model: RUMViewEvent.mockRandom()),
            lastUserInfo: .mockRandom()
        )
    }

    var data: Data { try! JSONEncoder().encode(self) }
}

extension DDCrashReport: EquatableInTests {}

internal extension DDCrashReport {
    static func mockAny() -> DDCrashReport {
        return .mockWith()
    }

    static func mockWith(
        date: Date? = .mockAny(),
        type: String = .mockAny(),
        message: String = .mockAny(),
        stackTrace: String = .mockAny(),
        context: Data? = .mockAny()
    ) -> DDCrashReport {
        return DDCrashReport(
            date: date,
            type: type,
            message: message,
            stackTrace: stackTrace,
            context: context
        )
    }

    static func mockRandomWith(context: CrashContext) -> DDCrashReport {
        return mockWith(
            date: .mockRandomInThePast(),
            type: .mockRandom(),
            message: .mockRandom(),
            stackTrace: .mockRandom(),
            context: context.data
        )
    }
}
