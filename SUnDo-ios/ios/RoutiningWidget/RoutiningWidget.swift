import AppIntents
import SwiftUI
import WidgetKit

// 앱이 App Group UserDefaults에 저장한 `snapshot` JSON을 읽어 그리는 읽기 전용 위젯이다.
// Xcode에서 Widget Extension 타깃을 만든 뒤 이 파일로 바꾸고, 앱과 같은 App Group을 추가한다. (README 참고)
//
// Android 위젯과 맞춘 동작:
//  - 모든 항목을 본다: WidgetKit은 손가락 스크롤이 없어서, iOS 17 이상에서는 위/아래 버튼으로 쪽을 넘긴다.
//  - 오른쪽 아래 "+" 버튼: 누르면 앱의 추가 화면이 열린다(투두 위젯은 투두, 오늘의 루틴 위젯은 루틴).
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
    let page: Int
}

func loadSnapshot() -> Snapshot? {
    guard
        let json = UserDefaults(suiteName: appGroupId)?.string(forKey: "snapshot"),
        let data = json.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(Snapshot.self, from: data)
}

// 위젯별로 지금 몇 쪽을 보고 있는지 App Group에 저장한다.
func pageKey(_ kind: String) -> String { "widgetPage.\(kind)" }

func loadPage(_ kind: String) -> Int {
    UserDefaults(suiteName: appGroupId)?.integer(forKey: pageKey(kind)) ?? 0
}

// 목록이 줄어 저장된 쪽이 범위를 벗어났으면 마지막 쪽으로 보정해 저장한다(버튼과 화면이 어긋나지 않게).
func clampedPage(kind: String, snapshot: Snapshot?, family: WidgetFamily) -> Int {
    let count = (kind == "RoutiningTodo" ? snapshot?.todos?.count : snapshot?.rows.count) ?? 0
    let limit = rowLimit(family)
    let pageCount = max(1, (count + limit - 1) / limit)
    let stored = loadPage(kind)
    let clamped = min(max(0, stored), pageCount - 1)
    if clamped != stored { UserDefaults(suiteName: appGroupId)?.set(clamped, forKey: pageKey(kind)) }
    return clamped
}

// 위/아래 버튼: 쪽을 넘기고 그 위젯만 다시 그린다. 범위는 그릴 때 보정한다.
@available(iOS 17.0, *)
struct ScrollPageIntent: AppIntent {
    static var title: LocalizedStringResource = "목록 넘기기"
    static var isDiscoverable: Bool = false

    @Parameter(title: "위젯") var kind: String
    @Parameter(title: "방향") var delta: Int

    init() {}
    init(kind: String, delta: Int) {
        self.kind = kind
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: appGroupId)
        let next = max(0, (defaults?.integer(forKey: pageKey(kind)) ?? 0) + delta)
        defaults?.set(next, forKey: pageKey(kind))
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        return .result()
    }
}

struct SnapshotProvider: TimelineProvider {
    let kind: String

    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: Date(), snapshot: nil, page: 0) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snap = loadSnapshot()
        completion(SnapshotEntry(date: Date(), snapshot: snap, page: clampedPage(kind: kind, snapshot: snap, family: context.family)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // 앱이 데이터를 바꿀 때 reloadTimelines로 갱신하고, 자정 직후에도 한 번 더 읽는다
        let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(3600)
        let snap = loadSnapshot()
        let entry = SnapshotEntry(date: Date(), snapshot: snap, page: clampedPage(kind: kind, snapshot: snap, family: context.family))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// 한 화면에 보이는 행 수(머리글과 버튼 자리를 뺀 값)
func rowLimit(_ family: WidgetFamily) -> Int {
    switch family {
    case .systemLarge: return 6
    default: return 2
    }
}

struct RowsView: View {
    let kind: String
    let title: String
    let summary: String
    let progress: Double
    let rows: [SnapshotRow]
    let emptyText: String
    let limit: Int
    let page: Int
    let addURL: URL

    private var pageCount: Int { max(1, (rows.count + limit - 1) / limit) }
    private var safePage: Int { min(max(0, page), pageCount - 1) }
    private var visible: ArraySlice<SnapshotRow> {
        let start = safePage * limit
        return rows[start..<min(rows.count, start + limit)]
    }

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
                ForEach(visible) { r in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.time.isEmpty ? "언제든" : r.time).font(.caption2).foregroundStyle(.secondary)
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
            footer
        }
        .padding(4)
    }

    // 아래줄: 왼쪽에 쪽 넘기기(iOS 17 이상), 오른쪽에 "+" 버튼
    private var footer: some View {
        HStack(spacing: 10) {
            if #available(iOS 17.0, *), pageCount > 1 {
                Button(intent: ScrollPageIntent(kind: kind, delta: -1)) { Image(systemName: "chevron.up") }
                    .disabled(safePage == 0)
                Text("\(safePage + 1)/\(pageCount)").font(.caption2).foregroundStyle(.secondary)
                Button(intent: ScrollPageIntent(kind: kind, delta: 1)) { Image(systemName: "chevron.down") }
                    .disabled(safePage >= pageCount - 1)
            }
            Spacer()
            Link(destination: addURL) {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.green))
            }
            .accessibilityLabel("추가")
        }
        .buttonStyle(.plain)
    }
}

struct TodayWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let s = entry.snapshot
        RowsView(
            kind: "RoutiningToday",
            title: "오늘의 루틴",
            summary: s == nil ? "" : (s!.rest ? "쉬는 날" : "\(s!.pct)%  \(s!.done)/\(s!.due)"),
            progress: s == nil || s!.rest ? 0 : Double(s!.pct) / 100,
            rows: s?.rows ?? [],
            emptyText: s == nil ? "앱을 열면 오늘 내용이 나타나요" : (s!.rest ? "쉬는 날이에요" : "오늘 할 루틴이 없어요"),
            limit: rowLimit(family),
            page: entry.page,
            addURL: URL(string: "myroutine://add?kind=routine&homeWidget")!
        )
        .widgetURL(URL(string: "myroutine://open?homeWidget"))
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
            kind: "RoutiningTodo",
            title: "투두",
            summary: s == nil ? "" : "\(done)/\(total)",
            progress: total == 0 ? 0 : Double(done) / Double(total),
            rows: s?.todos ?? [],
            emptyText: s == nil ? "앱을 열면 오늘 내용이 나타나요" : "남은 투두가 없어요",
            limit: rowLimit(family),
            page: entry.page,
            addURL: URL(string: "myroutine://add?kind=todo&homeWidget")!
        )
        .widgetURL(URL(string: "myroutine://open?homeWidget"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct RoutiningTodayWidget: Widget {
    let kind = "RoutiningToday"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider(kind: kind)) { TodayWidgetView(entry: $0) }
            .configurationDisplayName("루티닝 오늘의 루틴")
            .description("오늘 할 루틴과 달성률을 홈 화면에서 봐요")
            // 작은 크기는 "+" 버튼(Link)을 둘 수 없어서 제외한다
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct RoutiningTodoWidget: Widget {
    let kind = "RoutiningTodo"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider(kind: kind)) { TodoWidgetView(entry: $0) }
            .configurationDisplayName("루티닝 투두")
            .description("남은 투두를 홈 화면에서 봐요")
            // 작은 크기는 "+" 버튼(Link)을 둘 수 없어서 제외한다
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct RoutiningWidgetBundle: WidgetBundle {
    var body: some Widget {
        RoutiningTodayWidget()
        RoutiningTodoWidget()
    }
}
