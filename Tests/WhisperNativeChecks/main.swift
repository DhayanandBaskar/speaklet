import AppKit
import WhisperMacSupport

MainActor.assumeIsolated {
    var cases = 0
    var failures = 0
    func check(_ name: String, _ condition: Bool) {
        cases += 1
        if !condition { failures += 1 }
        print("\(condition ? "PASS" : "FAIL") \(name)")
    }
    let board = NSPasteboard(name: NSPasteboard.Name("local.whisperbubble.checks." + UUID().uuidString))
    defer { board.releaseGlobally() }
    let item = NSPasteboardItem()
    item.setString("Original clipboard", forType: .string)
    item.setString("<b>Original clipboard</b>", forType: .html)
    board.clearContents()
    board.writeObjects([item])
    let lease = ClipboardLease(text: "Dictated words", pasteboard: board)
    check("temporary dictation replaces private clipboard", board.string(forType: .string) == "Dictated words")
    check("unchanged clipboard restoration succeeds", lease.restoreIfUnchanged())
    check("original plain text restored", board.string(forType: .string) == "Original clipboard")
    check("original HTML restored", board.string(forType: .html) == "<b>Original clipboard</b>")
    check("restoration is one-use", !lease.restoreIfUnchanged())
    let second = ClipboardLease(text: "Another dictation", pasteboard: board)
    board.clearContents()
    board.setString("User copied something new", forType: .string)
    check("later clipboard change prevents restoration", !second.restoreIfUnchanged())
    check("newly copied user content survives", board.string(forType: .string) == "User copied something new")
    let third = ClipboardLease(text: "Third dictation", pasteboard: board)
    board.clearContents()
    board.setString("Third dictation", forType: .string)
    check("even same-text later copies are preserved", !third.restoreIfUnchanged())
    board.clearContents()
    let empty = ClipboardLease(text: "Temporary", pasteboard: board)
    check("initially empty clipboard restores", empty.restoreIfUnchanged() && board.pasteboardItems?.isEmpty != false)
    print("\(cases) native clipboard cases, \(failures) failures; user's clipboard untouched")
    exit(failures == 0 ? 0 : 1)
}
