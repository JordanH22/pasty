import AppKit
let pb = NSPasteboard.general
if let types = pb.types {
    for t in types { print(" -", t.rawValue) }
} else {
    print("none")
}
