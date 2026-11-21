import Foundation
import Observation

@MainActor
@Observable
final class TaskStore {
    private(set) var tasks: [RenewalTask] = []
    private(set) var loadError: String?

    let schedule = RenewalSchedule(calendar: .autoupdatingCurrent)
    private let fileURL: URL

    init(fileURL: URL = URL.documentsDirectory.appending(path: "renewal-tasks.json")) {
        self.fileURL = fileURL
        load()
    }

    var activeTasks: [RenewalTask] {
        tasks.filter { !$0.isCompleted }.sorted { schedule.nextDueDate(for: $0) < schedule.nextDueDate(for: $1) }
    }

    var completedTasks: [RenewalTask] {
        tasks.filter(\.isCompleted).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func task(withID id: UUID) -> RenewalTask? {
        tasks.first { $0.id == id }
    }

    func upsert(_ task: RenewalTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        save()
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func renew(_ id: UUID, newPrice: Decimal?) {
        guard let task = task(withID: id) else { return }
        upsert(schedule.renewed(task, newPrice: newPrice))
    }

    func reopen(_ id: UUID) {
        guard var task = task(withID: id) else { return }
        task.isCompleted = false
        upsert(task)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            tasks = try JSONDecoder.store.decode([RenewalTask].self, from: data)
        } catch {
            // Keep the unreadable file so a later fix can recover it, rather than overwriting it.
            let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: fileURL, to: backup)
            loadError = "Couldn't read saved tasks. A backup was kept."
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder.store.encode(tasks)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            loadError = "Couldn't save tasks: \(error.localizedDescription)"
        }
    }
}

private extension JSONEncoder {
    static var store: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var store: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
