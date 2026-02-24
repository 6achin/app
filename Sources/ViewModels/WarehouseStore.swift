import Foundation
import Combine

enum WarehouseUnitType: String, CaseIterable, Identifiable, Codable {
    case piece = "Stück"
    case display = "Display"
    case box = "Karton"

    var id: String { rawValue }
}

enum StockMovementType: String, CaseIterable, Identifiable, Codable {
    case delivery = "Lieferung"
    case adjustment = "Korrektur"
    case sale = "Verkauf"
    case `return` = "Retour"

    var id: String { rawValue }
}

struct StockItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var sku: String
    var ean: String
    var barcode: String?

    /// Optional packaging conversion helpers
    var piecesPerDisplay: Int?
    var piecesPerBox: Int?

    /// Current stock in base unit: pieces
    var currentPieces: Int

    init(
        id: UUID = UUID(),
        name: String,
        sku: String = "",
        ean: String = "",
        barcode: String? = nil,
        piecesPerDisplay: Int? = nil,
        piecesPerBox: Int? = nil,
        currentPieces: Int = 0
    ) {
        self.id = id
        self.name = name
        self.sku = sku
        self.ean = ean
        self.barcode = barcode
        self.piecesPerDisplay = piecesPerDisplay
        self.piecesPerBox = piecesPerBox
        self.currentPieces = currentPieces
    }
}

struct StockMovement: Identifiable, Hashable, Codable {
    let id: UUID
    var date: Date
    var type: StockMovementType
    var stockItemId: UUID
    var deltaPieces: Int
    var deliveryId: UUID?
    var deliveryLineId: UUID?
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date,
        type: StockMovementType,
        stockItemId: UUID,
        deltaPieces: Int,
        deliveryId: UUID? = nil,
        deliveryLineId: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.stockItemId = stockItemId
        self.deltaPieces = deltaPieces
        self.deliveryId = deliveryId
        self.deliveryLineId = deliveryLineId
        self.note = note
    }
}

struct DeliveryLine: Identifiable, Hashable, Codable {
    let id: UUID
    var stockItemId: UUID
    var name: String
    var sku: String
    var ean: String
    var barcode: String?

    var unitType: WarehouseUnitType
    var quantity: Int
    /// How many pieces does one selected unit represent.
    /// Example: Display=10 pieces, Box=200 pieces.
    var piecesPerUnit: Int

    /// VAT as fraction, e.g. 0.19
    var vatRate: Double

    /// Optional purchase price per selected unit (not per piece).
    var purchasePricePerUnit: Double?

    init(
        id: UUID = UUID(),
        stockItemId: UUID,
        name: String,
        sku: String,
        ean: String,
        barcode: String? = nil,
        unitType: WarehouseUnitType,
        quantity: Int,
        piecesPerUnit: Int,
        vatRate: Double,
        purchasePricePerUnit: Double? = nil
    ) {
        self.id = id
        self.stockItemId = stockItemId
        self.name = name
        self.sku = sku
        self.ean = ean
        self.barcode = barcode
        self.unitType = unitType
        self.quantity = quantity
        self.piecesPerUnit = max(piecesPerUnit, 1)
        self.vatRate = vatRate
        self.purchasePricePerUnit = purchasePricePerUnit
    }

    var totalPieces: Int { max(quantity, 0) * max(piecesPerUnit, 1) }
    var netTotal: Double {
        guard let p = purchasePricePerUnit else { return 0 }
        return Double(max(quantity, 0)) * p
    }
    var vatTotal: Double { netTotal * vatRate }
    var grossTotal: Double { netTotal + vatTotal }
}

struct Delivery: Identifiable, Hashable, Codable {
    let id: UUID
    var supplierName: String
    var supplierDocumentNumber: String
    var date: Date
    var defaultVatRate: Double
    var createdAt: Date
    var lines: [DeliveryLine]

    init(
        id: UUID = UUID(),
        supplierName: String,
        supplierDocumentNumber: String = "",
        date: Date,
        defaultVatRate: Double,
        createdAt: Date = Date(),
        lines: [DeliveryLine]
    ) {
        self.id = id
        self.supplierName = supplierName
        self.supplierDocumentNumber = supplierDocumentNumber
        self.date = date
        self.defaultVatRate = defaultVatRate
        self.createdAt = createdAt
        self.lines = lines
    }

    var totalPieces: Int { lines.reduce(0) { $0 + $1.totalPieces } }
    var netTotal: Double { lines.reduce(0) { $0 + $1.netTotal } }
    var vatTotal: Double { lines.reduce(0) { $0 + $1.vatTotal } }
    var grossTotal: Double { netTotal + vatTotal }
}

final class WarehouseStore: ObservableObject {
    @Published private(set) var items: [StockItem] = []
    @Published private(set) var movements: [StockMovement] = []
    @Published private(set) var deliveries: [Delivery] = []

    private struct PersistedWarehouse: Codable {
        var items: [StockItem]
        var movements: [StockMovement]
        var deliveries: [Delivery]
    }

    private let persistenceURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let fm = FileManager.default
        let baseURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser
        let folderURL = baseURL.appendingPathComponent("BusinessAccountingApp", isDirectory: true)
        if !fm.fileExists(atPath: folderURL.path) {
            try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        persistenceURL = folderURL.appendingPathComponent("warehouse-data.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()

        // Auto-save on changes (debounced)
        Publishers.CombineLatest3($items, $movements, $deliveries)
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    func addDelivery(_ delivery: Delivery) {
        // Apply each line as a stock movement and update stock.
        for line in delivery.lines {
            applyMovement(
                StockMovement(
                    date: delivery.date,
                    type: .delivery,
                    stockItemId: line.stockItemId,
                    deltaPieces: line.totalPieces,
                    deliveryId: delivery.id,
                    deliveryLineId: line.id,
                    note: "Lieferung"
                )
            )
        }
        deliveries.insert(delivery, at: 0)
    }

    func updateDeliveryLine(deliveryId: UUID, lineId: UUID, updated: DeliveryLine) {
        guard let dIdx = deliveries.firstIndex(where: { $0.id == deliveryId }) else { return }
        guard let lIdx = deliveries[dIdx].lines.firstIndex(where: { $0.id == lineId }) else { return }
        let oldLine = deliveries[dIdx].lines[lIdx]

        // Replace the stored line
        deliveries[dIdx].lines[lIdx] = updated

        // Apply delta pieces as an adjustment movement.
        let diff = updated.totalPieces - oldLine.totalPieces
        if diff != 0 {
            applyMovement(
                StockMovement(
                    date: Date(),
                    type: .adjustment,
                    stockItemId: updated.stockItemId,
                    deltaPieces: diff,
                    deliveryId: deliveryId,
                    deliveryLineId: lineId,
                    note: "Korrektur Lieferung"
                )
            )
        }

        // If the line switched stockItemId, revert old and apply new.
        if updated.stockItemId != oldLine.stockItemId {
            // Revert old line pieces on old item
            applyMovement(
                StockMovement(
                    date: Date(),
                    type: .adjustment,
                    stockItemId: oldLine.stockItemId,
                    deltaPieces: -oldLine.totalPieces,
                    deliveryId: deliveryId,
                    deliveryLineId: lineId,
                    note: "Korrektur (Artikel geändert)"
                )
            )

            // Apply full new line pieces on new item
            applyMovement(
                StockMovement(
                    date: Date(),
                    type: .adjustment,
                    stockItemId: updated.stockItemId,
                    deltaPieces: updated.totalPieces,
                    deliveryId: deliveryId,
                    deliveryLineId: lineId,
                    note: "Korrektur (Artikel geändert)"
                )
            )
        }

        // Update packaging helpers from latest information
        updatePackagingHints(for: updated)

        // Keep product meta in sync (best-effort)
        if let idx = items.firstIndex(where: { $0.id == updated.stockItemId }) {
            items[idx].name = updated.name
            items[idx].sku = updated.sku
            items[idx].ean = updated.ean
            items[idx].barcode = updated.barcode
        }
    }

    func upsertStockItemFromLineDraft(name: String, sku: String, ean: String, barcode: String?, unitType: WarehouseUnitType, piecesPerUnit: Int) -> StockItem {
        // Try to match by SKU, then EAN, then name.
        let normalizedSKU = sku.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedEAN = ean.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let idx = items.firstIndex(where: { !$0.sku.isEmpty && $0.sku.lowercased() == normalizedSKU }) {
            items[idx].name = name
            items[idx].ean = ean
            items[idx].barcode = barcode
            updatePackagingHints(itemIndex: idx, unitType: unitType, piecesPerUnit: piecesPerUnit)
            return items[idx]
        }

        if !normalizedEAN.isEmpty, let idx = items.firstIndex(where: { !$0.ean.isEmpty && $0.ean.lowercased() == normalizedEAN }) {
            items[idx].name = name
            if items[idx].sku.isEmpty { items[idx].sku = sku }
            items[idx].barcode = barcode
            updatePackagingHints(itemIndex: idx, unitType: unitType, piecesPerUnit: piecesPerUnit)
            return items[idx]
        }

        if !normalizedName.isEmpty, let idx = items.firstIndex(where: { $0.name.lowercased() == normalizedName }) {
            if items[idx].sku.isEmpty { items[idx].sku = sku }
            if items[idx].ean.isEmpty { items[idx].ean = ean }
            if items[idx].barcode == nil { items[idx].barcode = barcode }
            updatePackagingHints(itemIndex: idx, unitType: unitType, piecesPerUnit: piecesPerUnit)
            return items[idx]
        }

        let new = StockItem(name: name, sku: sku, ean: ean, barcode: barcode, currentPieces: 0)
        items.insert(new, at: 0)
        if let idx = items.firstIndex(where: { $0.id == new.id }) {
            updatePackagingHints(itemIndex: idx, unitType: unitType, piecesPerUnit: piecesPerUnit)
        }
        return new
    }

    func item(for id: UUID) -> StockItem? {
        items.first(where: { $0.id == id })
    }

    func movements(forDelivery deliveryID: UUID) -> [StockMovement] {
        movements
            .filter { $0.deliveryId == deliveryID }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Private

    private func applyMovement(_ movement: StockMovement) {
        movements.insert(movement, at: 0)
        if let idx = items.firstIndex(where: { $0.id == movement.stockItemId }) {
            items[idx].currentPieces += movement.deltaPieces
        }
    }

    private func updatePackagingHints(for line: DeliveryLine) {
        guard let idx = items.firstIndex(where: { $0.id == line.stockItemId }) else { return }
        updatePackagingHints(itemIndex: idx, unitType: line.unitType, piecesPerUnit: line.piecesPerUnit)
    }

    private func updatePackagingHints(itemIndex: Int, unitType: WarehouseUnitType, piecesPerUnit: Int) {
        let pieces = max(piecesPerUnit, 1)
        switch unitType {
        case .piece:
            break
        case .display:
            items[itemIndex].piecesPerDisplay = pieces
        case .box:
            items[itemIndex].piecesPerBox = pieces
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        guard let data = try? Data(contentsOf: persistenceURL) else { return }
        guard let decoded = try? decoder.decode(PersistedWarehouse.self, from: data) else { return }
        items = decoded.items
        movements = decoded.movements
        deliveries = decoded.deliveries
    }

    private func save() {
        let payload = PersistedWarehouse(items: items, movements: movements, deliveries: deliveries)
        guard let data = try? encoder.encode(payload) else { return }
        DispatchQueue.global(qos: .utility).async { [url = persistenceURL] in
            try? data.write(to: url, options: .atomic)
        }
    }
}
