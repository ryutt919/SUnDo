import SwiftUI
import WidgetKit

// 앱이 App Group UserDefaults에 저장한 `snapshot` JSON을 읽어 그리는 읽기 전용 위젯이다.
// Xcode에서 Widget Extension 타깃을 만든 뒤 이 파일로 바꾸고, 앱과 같은 App Group을 추가한다. (README 참고)
private let appGroupId = "group.com.sundo.myRoutine"

struct SnapshotRow: Decodable, Identifiable {
    let id: String
    let emoji: String
    let name: String
    let time: String
    let done: Bool
}

struct Snapshot: Decodable {
    let date: String
    let pct: Int
    let done: Int
    let due: Int
    let rest: Bool
    let rows: [SnapshotRow]
    let todos: [SnapshotRow]?
    let todoDone: Int?
    let todoTotal: Int?
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

func loadSnapshot() -> Snapshot? {
    guard
        let json = UserDefaults(suiteName: appGroupId)?.string(forKey: "snapshot"),
        let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(Snapshot.self, from: data)
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: Date(), snapshot: nil) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // 앱이 데이터를 바꿀 때 reloadTimelines로 갱신하고, 자정 직후에도 한 번 더 읽는다
        let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [SnapshotEntry(date: Date(), snapshot: loadSnapshot())], policy: .after(next)))
    }
}

struct RowsView: View {
    let title: String
    let summary: String
    let progress: Double
    let rows: [SnapshotRow]
    let emptyText: String
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(summary).font(.subheadline).bold()
            }
            ProgressView(value: progress).tint(.green)
            if rows.isEmpty {
                Spacer()
                Text(emptyText).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(rows.prefix(limit)) { r in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.time).font(.caption2).foregroundStyle(.secondary)
                            Text("\(r.emoji) \(r.name)").font(.subheadline).bold().lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: r.done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }
}

struct TodayWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let s = entry.snapshot
        RowsView(
            title: "오늘의 루틴",
            summary: s == nil ? "" : (s!.rest ? "쉬는 날" : "\(s!.pct)%  \(s!.done)/\(s!.due)"),
            progress: s == nil || s!.rest ? 0 : Double(s!.pct) / 100,
            rows: s?.rows ?? [],
            emptyText: s == nil ? "앱을 열면 오늘 내용이 나타나요" : (s!.rest ? "쉬는 날이에요" : "오늘 할 루틴이 없어요"),
            limit: family == .systemSmall ? 2 : 4
        )
        .widgetURL(URL(string: "myroutine://open"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct TodoWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let s = entry.snapshot
        let total = s?.todoTotal ?? 0
        let done = s?.todoDone ?? 0
        RowsView(
            title: "투두",
            summary: s == nil ? "" : "\(done)/\(total)",
            progress: total == 0 ? 0 : Double(done) / Double(total),
            rows: s?.todos ?? [],
            emptyText: s == nil ? "앱을 열면 오늘 내용이 나타나요" : "남은 투두가 없어요",
            limit: family == .systemSmall ? 2 : 4
        )
        .widgetURL(URL(string: "myroutine://open"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct RoutiningTodayWidget: Widget {
    let kind = "RoutiningToday"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { TodayWidgetView(entry: $0) }
            .configurationDisplayName("루티닝 오늘의 루틴")
            .description("오늘 할 루틴과 달성률을 홈 화면에서 봐요")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct RoutiningTodoWidget: Widget {
    let kind = "RoutiningTodo"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { TodoWidgetView(entry: $0) }
            .configurationDisplayName("루티닝 투두")
            .description("남은 투두를 홈 화면에서 봐요")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct RoutiningWidgetBundle: WidgetBundle {
    var body: some Widget {
        RoutiningTodayWidget()
        RoutiningTodoWidget()
    }
}
