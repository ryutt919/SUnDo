import AppKit
import Foundation
import SwiftUI
import WidgetKit

// 위젯 확장의 Swift 로직을 macOS에서 실행해 확인한다(CI의 ios-simulator.yml).
// 위젯 파일에서 @main을 뺀 복사본과 함께 컴파일하며, 인자로 Dart가 만든 snapshot JSON 파일 경로를 받는다.

var failures = 0
func check(_ cond: @autoclosure () -> Bool, _ message: String) {
    if cond() { print("PASS  \(message)") } else { print("FAIL  \(message)"); failures += 1 }
}

let fixturePath = CommandLine.arguments[1]
let raw = try Data(contentsOf: URL(fileURLWithPath: fixturePath))

// 1. Dart가 만든 JSON을 위젯이 그대로 읽는다(more, todoMore 키가 없어도 된다)
let snap = try JSONDecoder().decode(Snapshot.self, from: raw)
check(snap.rows.count == 6, "루틴 행 6개(개수 제한 없음)")
check(snap.todos?.count == 10, "투두 10개(개수 제한 없음)")
check(snap.todos?.first?.time == "10-13 이월 20:15", "지난 투두가 시간과 함께 맨 앞")
check(snap.todos?[1].time == "오늘 09:30", "오늘 투두 중 시간이 있는 것이 먼저")
check(snap.todoTotal == 10 && snap.todoDone == 0, "투두 합계")
check(snap.rows.first?.done == true, "체크한 루틴이 완료로 읽힘")

// 2. 위젯 크기별 한 화면 행 수
check(rowLimit(.systemMedium) == 2 && rowLimit(.systemLarge) == 6, "크기별 행 수")

// 3. 쪽 보정: 목록이 줄어 저장된 쪽이 범위를 벗어나면 마지막 쪽으로 고치고 저장한다
let defaults = UserDefaults(suiteName: "group.com.sundo.myRoutine")!
defaults.removeObject(forKey: pageKey("RoutiningTodo"))
defaults.set(4, forKey: pageKey("RoutiningTodo"))
check(clampedPage(kind: "RoutiningTodo", snapshot: snap, family: .systemMedium) == 4, "10개, 중간 크기: 5쪽 중 5번째 쪽 유지")

var obj = try JSONSerialization.jsonObject(with: raw) as! [String: Any]
obj["todos"] = Array((obj["todos"] as! [Any]).prefix(3))
let small = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: obj))
check(clampedPage(kind: "RoutiningTodo", snapshot: small, family: .systemMedium) == 1, "3개로 줄면 2쪽 중 마지막 쪽(1)으로 보정")
check(loadPage("RoutiningTodo") == 1, "보정한 쪽이 저장됨(버튼과 화면이 어긋나지 않음)")
check(clampedPage(kind: "RoutiningTodo", snapshot: nil, family: .systemLarge) == 0, "스냅샷이 없으면 0쪽")

// 4. 쪽 넘김 버튼(App Intent)이 저장된 쪽을 바꾼다
defaults.set(0, forKey: pageKey("RoutiningToday"))
if #available(macOS 14.0, *) {
    _ = try await ScrollPageIntent(kind: "RoutiningToday", delta: 1).perform()
    check(loadPage("RoutiningToday") == 1, "아래 버튼: 0쪽 에서 1쪽")
    _ = try await ScrollPageIntent(kind: "RoutiningToday", delta: -1).perform()
    check(loadPage("RoutiningToday") == 0, "위 버튼: 1쪽 에서 0쪽")
    _ = try await ScrollPageIntent(kind: "RoutiningToday", delta: -1).perform()
    check(loadPage("RoutiningToday") == 0, "맨 위에서 위 버튼은 0쪽 아래로 내려가지 않음")
}

// 5. 위젯 화면을 이미지로 그려 확인한다(두 번째 인자가 있으면 그 폴더에 PNG 저장)
if CommandLine.arguments.count > 2, #available(macOS 14.0, *) {
    let outDir = CommandLine.arguments[2]
    try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    @MainActor func render(_ name: String, size: CGSize, limit: Int, page: Int, rows: [SnapshotRow], title: String, summary: String, kind: String, add: String) throws {
        let view = RowsView(kind: kind, title: title, summary: summary, progress: 0.1, rows: rows, emptyText: "비었어요",
                            limit: limit, page: page, addURL: URL(string: add)!)
            .frame(width: size.width, height: size.height)
            .padding(12)
            .background(Color(white: 0.95))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            check(false, "\(name) 렌더링"); return
        }
        try png.write(to: URL(fileURLWithPath: outDir + "/" + name + ".png"))
        check(png.count > 2000, "\(name) 렌더링 이미지 생성(\(png.count) bytes)")
    }
    let todos = snap.todos ?? []
    try await MainActor.run {
        try render("투두_중간_1쪽", size: CGSize(width: 338, height: 158), limit: rowLimit(.systemMedium), page: 0, rows: todos,
                   title: "투두", summary: "0/10", kind: "RoutiningTodo", add: "myroutine://add?kind=todo&homeWidget")
        try render("투두_큰_2쪽", size: CGSize(width: 338, height: 354), limit: rowLimit(.systemLarge), page: 1, rows: todos,
                   title: "투두", summary: "0/10", kind: "RoutiningTodo", add: "myroutine://add?kind=todo&homeWidget")
        try render("루틴_큰_1쪽", size: CGSize(width: 338, height: 354), limit: rowLimit(.systemLarge), page: 0, rows: snap.rows,
                   title: "오늘의 루틴", summary: "17%  1/5", kind: "RoutiningToday", add: "myroutine://add?kind=routine&homeWidget")
    }
}

defaults.removeObject(forKey: pageKey("RoutiningTodo"))
defaults.removeObject(forKey: pageKey("RoutiningToday"))
print(failures == 0 ? "모든 확인 통과" : "실패 \(failures)건")
exit(failures == 0 ? 0 : 1)
