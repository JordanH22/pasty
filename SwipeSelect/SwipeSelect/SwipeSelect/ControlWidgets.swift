import WidgetKit
import SwiftUI
import AppIntents

struct SwipeSelectControls: WidgetBundle {
    var body: some Widget {
        EngineControlWidget()
        SwitchModeControlWidget()
        DoubleTapControlWidget()
        ShakeUndoControlWidget()
    }
}

// MARK: - Engine Toggle

struct EngineControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.swipeselect.engine",
            provider: EngineValueProvider()
        ) { value in
            ControlWidgetToggle(
                "SwipeSelect",
                isOn: value,
                action: ToggleEngineIntent()
            ) { isOn in
                Label(isOn ? "Engine On" : "Engine Off",
                      systemImage: isOn ? "cursorarrow.motionlines" : "cursorarrow")
            }
        }
        .displayName("SwipeSelect Engine")
        .description("Turn the cursor engine on or off")
    }
}

// MARK: - Switch Mode Button

struct SwitchModeControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.swipeselect.switchMode") {
            ControlWidgetButton(action: SwitchModeIntent()) {
                Label("Switch Mode", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .displayName("Switch Cursor Mode")
        .description("Toggle between Free Glide and OG SwipeSelection")
    }
}

// MARK: - Double-Tap Select Toggle

struct DoubleTapControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.swipeselect.doubleTap",
            provider: DoubleTapValueProvider()
        ) { value in
            ControlWidgetToggle(
                "Double-Tap",
                isOn: value,
                action: ToggleDoubleTapIntent()
            ) { isOn in
                Label(isOn ? "On" : "Off", systemImage: "hand.tap.fill")
            }
        }
        .displayName("Double-Tap Select")
        .description("Tap-tap + swipe to select text")
    }
}

// MARK: - Shake to Undo Toggle

struct ShakeUndoControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.swipeselect.shakeUndo",
            provider: ShakeUndoValueProvider()
        ) { value in
            ControlWidgetToggle(
                "Shake Undo",
                isOn: value,
                action: ToggleShakeUndoIntent()
            ) { isOn in
                Label(isOn ? "On" : "Off", systemImage: "arrow.uturn.backward")
            }
        }
        .displayName("Shake to Undo")
        .description("Shake trackpad to trigger ⌘Z")
    }
}
