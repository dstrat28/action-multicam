import CoreBluetooth
import Foundation

struct DiscoveredCameraCandidate {
    var id: UUID
    var name: String
    var brand: CameraBrand
    var model: CameraModel
    var rssi: Int
    var capabilities: Set<CameraCapability>
    var isAwake: Bool? = nil
    var isConnectable: Bool? = nil
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

enum BLEPeripheralLookupState {
    case cached
    case restored
    case missing

    var label: String {
        switch self {
        case .cached:
            "cached"
        case .restored:
            "restored"
        case .missing:
            "missing"
        }
    }
}

enum BLEScannerEvent {
    case bluetoothStateChanged(CBManagerState)
    case discovered(DiscoveredCameraCandidate)
    case connectionChanged(UUID, CameraConnectionState)
    case log(String)
}

private struct KnownCameraProfile {
    var name: String
    var brand: CameraBrand
    var model: CameraModel
    var capabilities: Set<CameraCapability>
}

final class BLECameraScanner: NSObject {
    private lazy var centralManager = CBCentralManager(delegate: self, queue: nil)
    private var wantsScanning = false
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var clientsByID: [UUID: any BLECameraDeviceClient] = [:]
    private var knownCamerasByID: [UUID: KnownCameraProfile] = [:]
    private var lastAdvertisementLogByID: [UUID: Date] = [:]

    var onEvent: ((BLEScannerEvent) -> Void)?

    var bluetoothState: CBManagerState {
        centralManager.state
    }

    func start() {
        wantsScanning = true
        guard centralManager.state == .poweredOn else {
            onEvent?(.bluetoothStateChanged(centralManager.state))
            return
        }

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        onEvent?(.log("Scanning for GoPro and DJI Bluetooth advertisements."))
    }

    func stop() {
        wantsScanning = false
        centralManager.stopScan()
        onEvent?(.log("Stopped scanning."))
    }

    func peripheralLookup(for id: UUID) -> (peripheral: CBPeripheral?, state: BLEPeripheralLookupState) {
        if let peripheral = peripheralsByID[id] {
            return (peripheral, .cached)
        }

        guard let restoredPeripheral = centralManager.retrievePeripherals(withIdentifiers: [id]).first else {
            return (nil, .missing)
        }

        peripheralsByID[id] = restoredPeripheral
        return (restoredPeripheral, .restored)
    }

    func peripheral(for id: UUID) -> CBPeripheral? {
        peripheralLookup(for: id).peripheral
    }

    func rememberKnownCameras(_ cameras: [DiscoveredCamera]) {
        knownCamerasByID = Dictionary(
            uniqueKeysWithValues: cameras
                .filter(\.isPaired)
                .map { camera in
                    (
                        camera.id,
                        KnownCameraProfile(
                            name: camera.name,
                            brand: camera.brand,
                            model: camera.model,
                            capabilities: camera.capabilities
                        )
                    )
                }
        )
    }

    func connect(
        to id: UUID,
        client: any BLECameraDeviceClient,
        enableAutoReconnect: Bool = false
    ) throws {
        guard let peripheral = peripheralsByID[id] else {
            throw BLEScannerError.peripheralNotFound
        }

        clientsByID[id] = client
        peripheral.delegate = client
        centralManager.connect(
            peripheral,
            options: connectOptions(enableAutoReconnect: enableAutoReconnect)
        )
        onEvent?(.connectionChanged(id, .connecting))
    }

    func disconnect(from id: UUID) {
        guard let peripheral = peripheralsByID[id] else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

extension BLECameraScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onEvent?(.bluetoothStateChanged(central.state))

        if central.state == .poweredOn, wantsScanning {
            start()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let candidate = identifyCamera(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI.intValue
        ) ?? identifyRememberedCamera(
            peripheral: peripheral,
            advertisementData: advertisementData,
            rssi: RSSI.intValue
        ) else {
            return
        }

        peripheralsByID[peripheral.identifier] = peripheral
        logAdvertisementIfNeeded(
            candidate: candidate,
            peripheral: peripheral,
            advertisementData: advertisementData
        )
        onEvent?(.discovered(candidate))
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let id = peripheral.identifier
        onEvent?(.log("\(peripheral.name ?? "Camera"): BLE connection established."))
        clientsByID[id]?.didConnect()
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let message = error?.localizedDescription ?? "Connection failed."
        onEvent?(.log("\(peripheral.name ?? "Camera"): BLE connection failed: \(message)"))
        onEvent?(.connectionChanged(peripheral.identifier, .failed(message)))
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        handleDisconnect(peripheral: peripheral, error: error, isReconnecting: false)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        timestamp: CFAbsoluteTime,
        isReconnecting: Bool,
        error: Error?
    ) {
        handleDisconnect(peripheral: peripheral, error: error, isReconnecting: isReconnecting)
    }
}

private extension BLECameraScanner {
    enum BLEScannerError: LocalizedError {
        case peripheralNotFound

        var errorDescription: String? {
            "The selected Bluetooth peripheral is no longer available."
        }
    }

    func identifyCamera(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: Int
    ) -> DiscoveredCameraCandidate? {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? "Unnamed Camera"
        let services = advertisedServiceUUIDs(from: advertisementData)
        let lowercasedName = name.lowercased()

        if services.contains(GoProBLEUUID.serviceControlAndQuery) || lowercasedName.contains("gopro") {
            return DiscoveredCameraCandidate(
                id: peripheral.identifier,
                name: name,
                brand: .gopro,
                model: inferGoProModel(from: name, advertisementData: advertisementData),
                rssi: rssi,
                capabilities: [.record, .mode, .settings, .status, .keepAlive],
                isAwake: inferGoProAwakeState(from: advertisementData, advertisedServices: services),
                isConnectable: inferConnectableState(from: advertisementData)
            )
        }

        if lowercasedName.contains("dji")
            || lowercasedName.contains("osmo")
            || lowercasedName.contains("action")
            || lowercasedName.contains("oa6")
            || lowercasedName.contains("osmoaction")
            || lowercasedName.contains("pocket")
            || lowercasedName.contains("op3") {
            return DiscoveredCameraCandidate(
                id: peripheral.identifier,
                name: name,
                brand: .dji,
                model: inferDJIModel(from: name),
                rssi: rssi,
                capabilities: [.experimental],
                isAwake: inferDJIAwakeState(from: advertisementData, cameraName: name),
                isConnectable: inferConnectableState(from: advertisementData)
            )
        }

        return nil
    }

    func logAdvertisementIfNeeded(
        candidate: DiscoveredCameraCandidate,
        peripheral: CBPeripheral,
        advertisementData: [String: Any]
    ) {
        guard candidate.brand == .dji || candidate.brand == .gopro else { return }

        let now = Date()
        if let lastLog = lastAdvertisementLogByID[candidate.id],
           now.timeIntervalSince(lastLog) < 3 {
            return
        }

        lastAdvertisementLogByID[candidate.id] = now
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            .map(\.uuidString)
            .joined(separator: ",")
        let overflowServices = (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [])
            .map(\.uuidString)
            .joined(separator: ",")
        let manufacturerData = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)?.hexString ?? "-"
        let serviceData = formatServiceData(advertisementData[CBAdvertisementDataServiceDataKey])
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.stringValue ?? "-"
        let isConnectable = inferConnectableState(from: advertisementData)
            .map { $0 ? "yes" : "no" } ?? "unknown"

        let awake = candidate.isAwake.map { $0 ? "yes" : "no" } ?? "unknown"
        onEvent?(.log(
            "\(candidate.name): \(candidate.brand.rawValue) ad fingerprint rssi \(candidate.rssi), awake \(awake), connectable \(isConnectable), localName \(localName ?? "-"), peripheralName \(peripheral.name ?? "-"), services [\(services.isEmpty ? "-" : services)], overflow [\(overflowServices.isEmpty ? "-" : overflowServices)], tx \(txPower), mfg \(manufacturerData), serviceData \(serviceData)"
        ))
    }

    func formatServiceData(_ value: Any?) -> String {
        guard let serviceData = value as? [CBUUID: Data], !serviceData.isEmpty else {
            return "-"
        }

        return serviceData
            .map { "\($0.key.uuidString)=\($0.value.hexString)" }
            .sorted()
            .joined(separator: ",")
    }

    func identifyRememberedCamera(
        peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: Int
    ) -> DiscoveredCameraCandidate? {
        guard let known = knownCamerasByID[peripheral.identifier] else { return nil }

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let services = advertisedServiceUUIDs(from: advertisementData)
        let name = preferredCameraName(
            advertisedName: advertisedName,
            peripheralName: peripheral.name,
            fallback: known.name
        )
        let inferredModel: CameraModel
        switch known.brand {
        case .gopro:
            inferredModel = inferGoProModel(from: name, advertisementData: advertisementData)
        case .dji:
            inferredModel = inferDJIModel(from: name)
        case .unknown:
            inferredModel = .unknown
        }

        return DiscoveredCameraCandidate(
            id: peripheral.identifier,
            name: name,
            brand: known.brand,
            model: inferredModel == .unknown ? known.model : inferredModel,
            rssi: rssi,
            capabilities: known.capabilities,
            isAwake: inferAwakeState(for: known.brand, cameraName: name, from: advertisementData, advertisedServices: services),
            isConnectable: inferConnectableState(from: advertisementData)
        )
    }

    func preferredCameraName(
        advertisedName: String?,
        peripheralName: String?,
        fallback: String
    ) -> String {
        if let advertisedName, !advertisedName.isEmpty {
            return advertisedName
        }

        if let peripheralName, !peripheralName.isEmpty {
            return peripheralName
        }

        return fallback
    }

    func connectOptions(enableAutoReconnect: Bool) -> [String: Any] {
        var options: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]

        if enableAutoReconnect {
            options[CBConnectPeripheralOptionEnableAutoReconnect] = true
        }

        return options
    }

    func handleDisconnect(
        peripheral: CBPeripheral,
        error: Error?,
        isReconnecting: Bool
    ) {
        clientsByID[peripheral.identifier]?.didDisconnect(error: error)

        if isReconnecting {
            onEvent?(.log("\(peripheral.name ?? "Camera"): BLE disconnected; iOS is reconnecting."))
            onEvent?(.connectionChanged(peripheral.identifier, .reconnecting))
            return
        }

        clientsByID[peripheral.identifier] = nil

        if let error {
            onEvent?(.log("\(peripheral.name ?? "Camera"): BLE disconnected: \(error.localizedDescription)"))
            onEvent?(.connectionChanged(peripheral.identifier, .failed(error.localizedDescription)))
        } else {
            onEvent?(.log("\(peripheral.name ?? "Camera"): BLE disconnected."))
            onEvent?(.connectionChanged(peripheral.identifier, .disconnected))
        }
    }

    func inferGoProModel(from name: String, advertisementData: [String: Any]? = nil) -> CameraModel {
        if let manufacturerData = advertisementData.flatMap(goProManufacturerData),
           manufacturerData.count >= 5 {
            let modelID = manufacturerData[manufacturerData.index(manufacturerData.startIndex, offsetBy: 4)]
            if modelID == 65 {
                return .goproHero13Black
            }
        }

        let lowercasedName = name.lowercased()
        if lowercasedName.contains("hero13")
            || lowercasedName.contains("hero 13")
            || lowercasedName.contains("13 black")
            || lowercasedName.contains("h24.01") {
            return .goproHero13Black
        }
        return .unknown
    }

    func advertisedServiceUUIDs(from advertisementData: [String: Any]) -> [CBUUID] {
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let overflowServices = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? []
        return services + overflowServices
    }

    func inferGoProAwakeState(
        from advertisementData: [String: Any],
        advertisedServices: [CBUUID]
    ) -> Bool? {
        guard let manufacturerData = goProManufacturerData(from: advertisementData),
              manufacturerData.count >= 4 else {
            return nil
        }

        let statusByte = manufacturerData[manufacturerData.index(manufacturerData.startIndex, offsetBy: 3)]
        return (statusByte & 0x01) == 0x01
    }

    func goProManufacturerData(from advertisementData: [String: Any]) -> Data? {
        guard let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              manufacturerData.count >= 2 else {
            return nil
        }

        let firstByte = UInt16(manufacturerData[manufacturerData.startIndex])
        let secondByte = UInt16(manufacturerData[manufacturerData.index(manufacturerData.startIndex, offsetBy: 1)])
        let littleEndianCompanyID = firstByte | (secondByte << 8)
        let bigEndianCompanyID = (firstByte << 8) | secondByte

        guard littleEndianCompanyID == 0xF202 || bigEndianCompanyID == 0xF202 else {
            return nil
        }

        return manufacturerData
    }

    func inferAwakeState(
        for brand: CameraBrand,
        cameraName: String,
        from advertisementData: [String: Any],
        advertisedServices: [CBUUID]
    ) -> Bool? {
        switch brand {
        case .gopro:
            inferGoProAwakeState(from: advertisementData, advertisedServices: advertisedServices)
        case .dji:
            inferDJIAwakeState(from: advertisementData, cameraName: cameraName)
        case .unknown:
            nil
        }
    }

    func inferDJIAwakeState(from advertisementData: [String: Any], cameraName: String) -> Bool? {
        guard cameraName.lowercased().contains("nano") else { return nil }
        guard let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              manufacturerData.count >= 2 else {
            return nil
        }

        let companyID = UInt16(manufacturerData[manufacturerData.startIndex])
            | (UInt16(manufacturerData[manufacturerData.index(manufacturerData.startIndex, offsetBy: 1)]) << 8)
        guard companyID == 0x08AA, let stateByte = manufacturerData.last else { return nil }

        switch stateByte {
        case 0x02:
            return true
        case 0x03:
            return false
        default:
            return nil
        }
    }

    func inferConnectableState(from advertisementData: [String: Any]) -> Bool? {
        if let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool {
            return isConnectable
        }

        if let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber {
            return isConnectable.boolValue
        }

        return nil
    }

    func inferDJIModel(from name: String) -> CameraModel {
        let lowercasedName = name.lowercased()
        let normalizedName = lowercasedName.filter { $0.isLetter || $0.isNumber }
        if normalizedName.contains("action6")
            || normalizedName.contains("oa6")
            || normalizedName.contains("osmoaction6") {
            return .djiOsmoAction6
        }
        if lowercasedName.contains("nano") {
            return .djiOsmoNano
        }
        if lowercasedName.contains("pocket 3")
            || lowercasedName.contains("pocket3")
            || lowercasedName.contains("pocket")
            || lowercasedName.contains("op3") {
            return .djiOsmoPocket3
        }
        return .unknown
    }
}
