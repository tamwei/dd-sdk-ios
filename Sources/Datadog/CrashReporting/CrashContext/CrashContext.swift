/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Describes current Datadog SDK context, so the app state information can be attached to
/// the crash report and retrieved back when the application is started again.
///
/// Note: as it gets saved along with the crash report during process interruption, it's good
/// to keep this data well-packed and as small as possible.
internal struct CrashContext: Codable {
    // MARK: - Initialization

    init(
        lastTrackingConsent: TrackingConsent,
        lastRUMViewEvent: RUMEvent<RUMViewEvent>?,
        lastUserInfo: UserInfo?,
        lastNetworkConnectionInfo: NetworkConnectionInfo?
    ) {
        self.codableTrackingConsent = .init(from: lastTrackingConsent)
        self.codableLastRUMViewEvent = lastRUMViewEvent.flatMap { .init(from: $0) }
        self.codableLastUserInfo = lastUserInfo.flatMap { .init(from: $0) }
        self.codableLastNetworkConnectionInfo = lastNetworkConnectionInfo.flatMap { .init(from: $0) }
    }

    // MARK: - Codable values

    private var codableTrackingConsent: CodableTrackingConsent
    private var codableLastRUMViewEvent: CodableRUMViewEvent?
    private var codableLastUserInfo: CodableUserInfo?
    private var codableLastNetworkConnectionInfo: CodableNetworkConnectionInfo?

    // TODO: RUMM-1049 Add Codable version of `UserInfo?`, `NetworkInfo?` and `CarrierInfo?`

    enum CodingKeys: String, CodingKey {
        case codableTrackingConsent = "ctc"
        case codableLastRUMViewEvent = "lre"
        case codableLastUserInfo = "lui"
        case codableLastNetworkConnectionInfo = "lni"
    }

    // MARK: - Setters & Getters using managed types

    var lastTrackingConsent: TrackingConsent {
        set { codableTrackingConsent = CodableTrackingConsent(from: newValue) }
        get { codableTrackingConsent.managedValue }
    }

    var lastRUMViewEvent: RUMEvent<RUMViewEvent>? {
        set { codableLastRUMViewEvent = newValue.flatMap { CodableRUMViewEvent(from: $0) } }
        get { codableLastRUMViewEvent?.managedValue }
    }

    var lastUserInfo: UserInfo? {
        set { codableLastUserInfo = newValue.flatMap { CodableUserInfo(from: $0) } }
        get { codableLastUserInfo?.managedValue }
    }

    var lastNetworkConnectionInfo: NetworkConnectionInfo? {
        set { codableLastNetworkConnectionInfo = newValue.flatMap { CodableNetworkConnectionInfo(from: $0) } }
        get { codableLastNetworkConnectionInfo?.managedValue }
    }
}

// MARK: - Bridging managed types to Codable representation

/// Codable representation of the public `TrackingConsent`. Uses `Int8` for optimized packing.
private enum CodableTrackingConsent: Int8, Codable {
    case granted
    case notGranted
    case pending

    init(from managedValue: TrackingConsent) {
        switch managedValue {
        case .pending: self = .pending
        case .granted: self = .granted
        case .notGranted: self = .notGranted
        }
    }

    var managedValue: TrackingConsent {
        switch self {
        case .pending: return .pending
        case .granted: return .granted
        case .notGranted: return .notGranted
        }
    }
}

private struct CodableRUMViewEvent: Codable {
    private let model: RUMViewEvent
    private let attributes: [String: Encodable]
    private let userInfoAttributes: [String: Encodable]

    init(from managedValue: RUMEvent<RUMViewEvent>) {
        self.model = managedValue.model
        self.attributes = managedValue.attributes
        self.userInfoAttributes = managedValue.userInfoAttributes
    }

    var managedValue: RUMEvent<RUMViewEvent> {
        return .init(
            model: model,
            attributes: attributes,
            userInfoAttributes: userInfoAttributes
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case model = "mdl"
        case attributes = "att"
        case userInfoAttributes = "uia"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.model = try container.decode(RUMViewEvent.self, forKey: .model)
        self.attributes = try container.decode([String: CodableValue].self, forKey: .attributes)
        self.userInfoAttributes = try container.decode([String: CodableValue].self, forKey: .userInfoAttributes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let encodedAttributes = attributes.mapValues { EncodableValue($0) }
        let encodedUserInfoAttributes = userInfoAttributes.mapValues { EncodableValue($0) }

        try container.encode(model, forKey: .model)
        try container.encode(encodedAttributes, forKey: .attributes)
        try container.encode(encodedUserInfoAttributes, forKey: .userInfoAttributes)
    }
}

private struct CodableUserInfo: Codable {
    private let id: String?
    private let name: String?
    private let email: String?
    private let extraInfo: [AttributeKey: AttributeValue]

    init(from managedValue: UserInfo) {
        self.id = managedValue.id
        self.name = managedValue.name
        self.email = managedValue.email
        self.extraInfo = managedValue.extraInfo
    }

    var managedValue: UserInfo {
        return .init(
            id: id,
            name: name,
            email: email,
            extraInfo: extraInfo
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "nm"
        case email = "em"
        case extraInfo = "ei"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.extraInfo = try container.decode([String: CodableValue].self, forKey: .extraInfo)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let encodedExtraInfo = extraInfo.mapValues { EncodableValue($0) }

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(encodedExtraInfo, forKey: .extraInfo)
    }
}

private struct CodableNetworkConnectionInfo: Codable {
    private let reachability: NetworkConnectionInfo.Reachability
    private let availableInterfaces: [NetworkConnectionInfo.Interface]?
    private let supportsIPv4: Bool?
    private let supportsIPv6: Bool?
    private let isExpensive: Bool?
    private let isConstrained: Bool?

    init(from managedValue: NetworkConnectionInfo) {
        self.reachability = managedValue.reachability
        self.availableInterfaces = managedValue.availableInterfaces
        self.supportsIPv4 = managedValue.supportsIPv4
        self.supportsIPv6 = managedValue.supportsIPv6
        self.isExpensive = managedValue.isExpensive
        self.isConstrained = managedValue.isConstrained
    }

    var managedValue: NetworkConnectionInfo {
        return .init(
            reachability: reachability,
            availableInterfaces: availableInterfaces,
            supportsIPv4: supportsIPv4,
            supportsIPv6: supportsIPv6,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case reachability = "rcb"
        case availableInterfaces = "abi"
        case supportsIPv4 = "si4"
        case supportsIPv6 = "si6"
        case isExpensive = "ise"
        case isConstrained = "isc"
    }
}

// MARK: - Codable Helpers

/// Helper type performing type erasure of encoded JSON types.
/// It conforms to `Encodable`, so decoded value can be further serialized into exactly the same JSON representation.
private struct CodableValue: Codable {
    private let value: Encodable

    init<T: Encodable>(value: T) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            self.init(value: bool)
        } else if let uint64 = try? container.decode(UInt64.self) {
            self.init(value: uint64)
        } else if let int = try? container.decode(Int.self) {
            self.init(value: int)
        } else if let double = try? container.decode(Double.self) {
            self.init(value: double)
        } else if let string = try? container.decode(String.self) {
            self.init(value: string)
        } else if let array = try? container.decode([CodableValue].self) {
            self.init(value: array)
        } else if let dictionary = try? container.decode([String: CodableValue].self) {
            self.init(value: dictionary)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Custom attribute at \(container.codingPath) cannot is not a `Codable` type supported by the SDK."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
