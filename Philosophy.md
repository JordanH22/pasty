# Pastry — Design Philosophy & Standard Operating Procedure

> A lightweight, native macOS application that functions as a high-performance pastebin client.
> Built with the Liquid Glass design language of macOS 26.

---

## 1. Core Technical Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Language | Swift 6 | Native execution with compile-time concurrency safety |
| UI Framework | SwiftUI | Native support for macOS 26 materials and animations |
| Storage | SwiftData | Schema-based local persistence for paste history |
| Network | URLSession | Standard library implementation to minimize binary size |

---

## 2. Design Specification: Liquid Glass

Pastry adheres to the following aesthetic constraints to ensure it feels like a first-party Apple utility:

### Refraction
- Use `.visualEffect` with `ultraThinMaterial`
- **Avoid solid backgrounds entirely** — every surface should breathe

### Glass Strokes
- 0.5pt borders with 20% white opacity
- Define window boundaries without harsh edges
- Layered depth through subtle shadow and blur

### Motion
- Apply `.interactiveSpring()` to **all** transitions and state changes
- No abrupt cuts — everything flows

### Iconography
- **SF Symbols 6.0 exclusively** for all interface actions
- No custom icon assets — system-native only

### Typography
- System font (SF Pro) at all times
- Respect Dynamic Type scaling
- High contrast text over glass surfaces via vibrancy

---

## 3. Functional Workflow

### 3.1 Menu Bar Primary Interface

The application resides **primarily in the Menu Bar** to reduce window clutter.

- **Hotkey Activation**: `Cmd + Shift + V` opens the Pastry popover
- **Smart Capture**: On activation, if the clipboard contains text, it is automatically staged in the "New Paste" editor
- **Instant Dispatch**: A single primary action button to upload and copy the resulting URL

### 3.2 Local Archive

- **Index**: Maintain a searchable history of the last 50 pastes
- **Preview**: Hovering over a history item displays a glass-card preview of the text content
- **One-tap copy**: Click any history item to re-copy its URL

---

## 4. Implementation Guidelines

### Step 1: UI Construction
- Refractive window backgrounds using `.ultraThinMaterial`
- Custom `TextEditor` styling that supports transparency without losing legibility
- Glass-morphism modifiers applied consistently across all views

### Step 2: Data Security
- All API tokens stored in the **macOS Keychain**
- Local paste data encrypted via **AES-256-GCM** (CryptoKit) when "Secure History" is enabled
- No plaintext secrets ever touch disk

### Step 3: Performance Benchmarks

| Metric | Target |
|--------|--------|
| RAM Footprint | < 35 MB during active use |
| Binary Size | < 10 MB total |
| CPU (idle) | 0% when popover is closed |

---

## 5. Quality Assurance (Logic & Stability)

### Offline Handling
- If the network is unavailable, Pastry caches the paste locally and queues it for upload when connectivity returns
- Visual indicator shows queued state with retry countdown

### Formatting
- **Plain Text toggle** strips formatting from clipboard data before uploading
- Respects user's default preference from Settings

### Destruct Timer
- Options: **1 hour**, **1 day**, **1 week**, or **never**
- Applied per-paste at creation time
- Default configurable in Settings

---

## 6. Settings Philosophy

Pastry provides **fully customizable settings** across all dimensions:

### Appearance
- Popover width and height
- Glass intensity / material variant
- Accent color selection

### Behavior
- Default destruct timer
- Plain text by default toggle
- Auto-capture clipboard on open
- History retention count (10–100)
- Launch at login

### Security
- Secure History (encrypted local storage)
- API token management (Keychain-backed)

### Keyboard
- Customizable global hotkey

### API
- Pastebin service endpoint configuration
- Custom API headers

---

## 7. Deployment Protocol

### Build
- Compile as a **Universal Binary** (Apple Silicon + Intel)
- `ARCHS = arm64 x86_64`

### Signing & Notarization
- Execute standard Apple Developer notarization to avoid Gatekeeper warnings
- Hardened Runtime enabled

### Feedback Loop
- Integrate `os_log` for crash reporting
- No heavy third-party SDKs
- Categories: `.network`, `.clipboard`, `.security`, `.ui`

---

## 8. Guiding Principles

1. **Invisible until needed** — menu bar only, zero Dock presence
2. **One action, one result** — paste text, get URL, done
3. **Native above all** — if Apple provides it, we use it
4. **Glass is the brand** — every pixel refracts, nothing is opaque
5. **Respect the machine** — under 35MB RAM, 0% idle CPU, sub-10MB binary
6. **Privacy by default** — Keychain for secrets, optional encryption for history
7. **Offline-first** — never lose a paste to bad WiFi
