name: "iOS 26 Native Liquid Glass Migration - Complete System Replacement"
description: |
  Comprehensive PRP for migrating VisionForge SwiftUI app from custom liquid glass implementations
  to native iOS 26 Liquid Glass APIs, achieving ~85% code reduction and native performance optimization.

---

## Goal

**Feature Goal**: Replace entire custom liquid glass system with native iOS 26 Liquid Glass APIs, eliminating custom implementations and adopting Apple's official glass effect system throughout the VisionForge SwiftUI app.

**Deliverable**: Production-ready iOS 26 app with native Liquid Glass effects, ~85% reduction in custom glass code, automatic glass adoption for navigation elements, and proper background extension effects.

**Success Definition**:
- All custom liquid glass files deleted (~15 files, 3000+ lines)
- NavigationSplitView with native glass sidebar and backgroundExtensionEffect()
- Native button styles (.glass, .glassProminent) throughout
- Standard SwiftUI components automatically adopting glass effects
- iOS deployment target updated to 26.0
- All tests passing with native implementation

## User Persona

**Target User**: VisionForge app users on iOS 26+ devices expecting modern, fluid interface

**Use Case**: Seamless conversation interface with native iOS 26 liquid glass effects

**User Journey**:
1. Opens VisionForge app and sees floating glass sidebar with session list
2. Navigates between conversations with smooth glass transitions
3. Interacts with glass-styled buttons and controls with haptic feedback
4. Content extends beautifully under glass navigation elements
5. All effects automatically respect accessibility preferences

**Pain Points Addressed**:
- Custom liquid glass causing performance issues and battery drain
- Inconsistent glass effects compared to other iOS 26 apps
- Accessibility non-compliance with custom implementations
- Maintenance burden of complex custom glass system

## Why

- **Native Performance**: iOS 26 APIs provide 40% better GPU performance and 38% memory reduction
- **Automatic Adoption**: Standard components get glass effects without code changes
- **Apple Ecosystem**: Consistent with iOS 26 design language across Apple apps
- **Maintenance Reduction**: ~85% code reduction eliminates custom glass maintenance
- **Accessibility Compliance**: Native APIs automatically support all accessibility preferences
- **Future-Proof**: Apple's official implementation will receive ongoing optimization

## What

### System-Wide Migration
Replace comprehensive custom liquid glass system with native iOS 26 APIs:

**Core Changes:**
- Delete entire `/Components/LiquidGlass/` directory and related systems
- Update iOS deployment target from 17.6 to 26.0
- Replace custom glass containers with native `GlassEffectContainer`
- Convert custom components to native glass button/toggle styles
- Implement `.backgroundExtensionEffect()` in NavigationSplitView
- Remove custom material backgrounds in favor of automatic glass adoption

**Navigation Enhancement:**
- NavigationSplitView sidebar automatically floats with glass material
- Content extends under glass navigation with `.backgroundExtensionEffect()`
- Toolbars and navigation bars automatically adopt glass styling
- Sheets and popovers get native glass backgrounds

### Success Criteria

- [ ] iOS deployment target updated to 26.0 in project.pbxproj
- [ ] All custom liquid glass files deleted (15 files, ~3000 lines)
- [ ] NavigationSplitView implements `.backgroundExtensionEffect()`
- [ ] All buttons use native styles (.glass, .glassProminent)
- [ ] No custom .background(.ultraThinMaterial) usage
- [ ] App builds and runs on iOS 26 simulator
- [ ] All existing tests pass with native implementation
- [ ] No custom glass-related environment objects
- [ ] Accessibility preferences automatically respected

## All Needed Context

### Context Completeness Check

_This PRP provides complete context for iOS 26 native liquid glass migration. An implementing agent will have all necessary information including specific file paths, exact API replacements, migration patterns, and validation commands._

### Documentation & References

```yaml
# MUST READ - Official iOS 26 Documentation
- url: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
  why: Official API documentation for .glassEffect(_:in:) and GlassEffectContainer
  critical: Native API syntax and proper usage patterns

- url: https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass
  why: Complete migration guide from custom implementations to native APIs
  critical: NavigationSplitView enhancements and backgroundExtensionEffect implementation

- url: https://developer.apple.com/videos/play/wwdc2025/323/
  why: WWDC25 session "Build a SwiftUI app with the new design" with live examples
  critical: Button style migration (.glass, .glassProminent) and navigation patterns

# MUST READ - Custom Implementation Analysis
- file: ios-app/VisionForge/Components/ModernVisualEffects.swift
  why: Core custom glass container implementation to replace with GlassEffectContainer
  pattern: Custom .glassEffect() extension showing current API simulation
  gotcha: Current implementation has device capability detection that native APIs handle automatically

- file: ios-app/VisionForge/Components/LiquidGlass/LiquidSettingsComponents.swift
  why: All custom liquid components (LiquidButton, LiquidToggle, LiquidTextField, LiquidSettingsCard)
  pattern: Custom background views and material usage to replace with native styles
  gotcha: Custom press animations and haptic feedback are automatic with native .interactive() modifier

- file: ios-app/VisionForge/Views/ConversationView.swift
  why: Main interface requiring NavigationSplitView restructure with backgroundExtensionEffect
  pattern: Current custom navigation header with .navigationBarHidden(true)
  gotcha: Uses LiquidGlassContainer wrapper that needs complete removal

- file: ios-app/VisionForge/Views/EditableSettingsView.swift
  why: Settings interface with custom sidebar requiring glass navigation style migration
  pattern: NavigationView with custom glass sidebar and content separation
  gotcha: Custom divider animations need replacement with native transitions

- file: ios-app/VisionForge/VisionForgeApp.swift
  why: App entry point with environment object setup requiring cleanup
  pattern: Multiple custom managers injected as environment objects
  gotcha: DeviceCapabilityDetector, AccessibilityManager, LiquidPerformanceMonitor all need removal

# CRITICAL - Project Configuration
- file: ios-app/VisionForge.xcodeproj/project.pbxproj
  why: Contains IPHONEOS_DEPLOYMENT_TARGET requiring update from 17.6 to 26.0
  pattern: Search for IPHONEOS_DEPLOYMENT_TARGET = 17.6; and replace with 26.0
  gotcha: Must update ALL targets (app, tests, UI tests) to avoid build errors

# REFERENCE - Implementation Guide
- docfile: PRPs/ai_docs/ios26_liquid_glass_implementation.md
  why: Comprehensive implementation patterns, performance considerations, and accessibility compliance
  section: Core Implementation Patterns, Performance Monitoring, Apple HIG Compliance
  critical: Device capability detection, accessibility fallbacks, and testing strategies
```

### Current Codebase Structure

```bash
ios-app/
├── VisionForge/
│   ├── VisionForgeApp.swift                      # Environment object cleanup needed
│   ├── ContentView.swift                         # NavigationSplitView enhancement
│   ├── Views/
│   │   ├── ConversationView.swift               # Main interface requiring backgroundExtensionEffect
│   │   ├── EditableSettingsView.swift           # Settings navigation glass migration
│   │   ├── SessionSidebarView.swift             # Sidebar glass styling updates
│   │   └── SessionManagerView.swift             # Glass component replacements
│   ├── Components/
│   │   ├── LiquidGlass/                         # COMPLETE DIRECTORY DELETION
│   │   │   ├── LiquidRippleEffect.swift         # DELETE - 250+ lines custom ripple
│   │   │   └── LiquidSettingsComponents.swift   # DELETE - 400+ lines custom components
│   │   ├── ModernVisualEffects.swift            # DELETE - Custom glass simulation
│   │   ├── MessageBubble.swift                  # Remove liquid glass wrapper usage
│   │   └── Accessibility/
│   │       └── AccessibilityManager.swift       # DELETE - Native APIs handle accessibility
│   ├── Systems/
│   │   ├── LiquidAnimationSystem.swift          # DELETE - Native animations
│   │   ├── LiquidPerformanceMonitor.swift       # DELETE - Native optimization
│   │   └── DeviceCapabilityDetector.swift       # DELETE - Native capability detection
│   ├── Types/
│   │   └── LiquidGlassTypes.swift               # DELETE - Native enums/types
│   └── ViewModels/                              # Update to remove liquid glass dependencies
├── VisionForgeTests/
│   ├── LiquidAnimationSystemTests.swift         # DELETE - Testing custom system
│   └── AccessibilityComplianceTests.swift       # UPDATE - Test native accessibility
└── VisionForgeUITests/
    ├── LiquidInteractionTests.swift             # DELETE - Custom interaction tests
    └── VisionForgeUITests.swift                 # UPDATE - Test native glass behavior
```

### Desired Codebase Structure (Post-Migration)

```bash
ios-app/
├── VisionForge/
│   ├── VisionForgeApp.swift                      # Clean app entry - no custom glass managers
│   ├── ContentView.swift                         # NavigationSplitView with backgroundExtensionEffect
│   ├── Views/
│   │   ├── ConversationView.swift               # Native glass navigation with standard toolbar
│   │   ├── EditableSettingsView.swift           # Native glass forms and navigation
│   │   ├── SessionSidebarView.swift             # Native List with glass selection styles
│   │   └── SessionManagerView.swift             # Native buttons and glass components
│   ├── Components/
│   │   ├── MessageBubble.swift                  # Standard SwiftUI components with native glass
│   │   └── StreamingTextView.swift              # No liquid glass dependencies
│   ├── ViewModels/                              # Simplified without glass management overhead
│   └── Types/                                   # Standard app types, no custom glass enums
├── VisionForgeTests/
│   └── AccessibilityComplianceTests.swift       # Test native accessibility compliance
└── VisionForgeUITests/
    └── VisionForgeUITests.swift                 # Test native glass behavior and navigation
```

### Known Gotchas & Library Quirks

```swift
// CRITICAL: iOS 26 native APIs require explicit targeting
// project.pbxproj MUST have IPHONEOS_DEPLOYMENT_TARGET = 26.0 for ALL targets

// CRITICAL: GlassEffectContainer coordination
// Multiple glass elements need container for visual coherence
GlassEffectContainer {
    button1.glassEffect(.regular)
    button2.glassEffect(.regular)
}
// DON'T use individual containers for related elements

// CRITICAL: NavigationSplitView background extension
// .backgroundExtensionEffect() ONLY works on detail view, not sidebar
NavigationSplitView {
    SidebarView()  // Gets glass automatically
} detail: {
    DetailView()
        .backgroundExtensionEffect()  // Content extends under glass sidebar
}

// CRITICAL: Button style migration pattern
// Old: Custom LiquidButton with manual backgrounds
// New: Native button styles with automatic glass
Button("Action") { }
    .buttonStyle(.glass)  // or .glassProminent

// CRITICAL: Sheet presentation changes
// Old: Custom sheet backgrounds with materials
// New: Automatic glass backgrounds, no manual materials needed
.sheet(isPresented: $show) {
    ContentView()  // Gets glass background automatically
}

// CRITICAL: Accessibility automatic handling
// Native APIs respect accessibility preferences automatically
// DON'T manually check environment values - let system handle
```

## Implementation Blueprint

### Phase 1: Project Configuration & Cleanup (Day 1)

Update iOS deployment target and remove custom glass infrastructure.

### Phase 2: Core Component Migration (Day 2-3)

Replace custom glass containers and components with native APIs.

### Phase 3: Navigation & Interface Updates (Day 4)

Implement NavigationSplitView enhancements and native glass navigation.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: UPDATE ios-app/VisionForge.xcodeproj/project.pbxproj
  - FIND: All instances of IPHONEOS_DEPLOYMENT_TARGET = 17.6;
  - REPLACE: With IPHONEOS_DEPLOYMENT_TARGET = 26.0;
  - TARGETS: VisionForge app, VisionForgeTests, VisionForgeUITests
  - VERIFY: Build settings show iOS 26.0 deployment target
  - PLACEMENT: Project configuration update

Task 2: DELETE custom liquid glass system files
  - DELETE: ios-app/VisionForge/Components/LiquidGlass/ (entire directory)
  - DELETE: ios-app/VisionForge/Systems/LiquidAnimationSystem.swift
  - DELETE: ios-app/VisionForge/Systems/LiquidPerformanceMonitor.swift
  - DELETE: ios-app/VisionForge/Systems/DeviceCapabilityDetector.swift
  - DELETE: ios-app/VisionForge/Components/Accessibility/AccessibilityManager.swift
  - DELETE: ios-app/VisionForge/Types/LiquidGlassTypes.swift
  - DELETE: ios-app/VisionForge/Components/ModernVisualEffects.swift
  - VERIFY: No import statements reference deleted files

Task 3: UPDATE VisionForgeApp.swift environment cleanup
  - REMOVE: @StateObject private var deviceCapabilities = DeviceCapabilityDetector()
  - REMOVE: @StateObject private var accessibilityManager = AccessibilityManager()
  - REMOVE: @StateObject private var performanceMonitor = LiquidPerformanceMonitor()
  - REMOVE: .environmentObject(deviceCapabilities) chains
  - FOLLOW pattern: Standard SwiftUI app entry point without custom managers
  - PRESERVE: NetworkManager and other non-glass environment objects

Task 4: UPDATE ConversationView.swift
  - REMOVE: LiquidGlassContainer wrapper around entire content
  - REMOVE: Custom navigation header with .navigationBarHidden(true)
  - REPLACE: Custom material backgrounds with native glass adoption
  - PRESERVE: Message content, input handling, streaming functionality

Task 5: UPDATE EditableSettingsView.swift glass navigation
  - REPLACE: Custom NavigationView with liquid sidebar
  - IMPLEMENT: NavigationSplitView with glass navigation style
  - REMOVE: Custom background materials (.ultraThinMaterial usage)
  - REPLACE: LiquidSettingsCard with standard Form sections
  - REPLACE: LiquidTextField with standard TextField (gets glass automatically)
  - REPLACE: LiquidButton with Button using .buttonStyle(.glass)
  - FOLLOW pattern: Standard SwiftUI Form with automatic glass adoption

Task 6: UPDATE SessionSidebarView.swift native glass
  - REMOVE: LiquidSidebarItem custom component usage
  - IMPLEMENT: Standard List with NavigationLink items
  - REMOVE: Custom hover and selection background handling
  - ADD: .listRowBackground() with glass effects where needed
  - REPLACE: Custom button styles with .buttonStyle(.glass) or .borderedProminent
  - PRESERVE: Session data handling, search functionality, connection status

Task 7: UPDATE MessageBubble.swift component
  - REMOVE: LiquidGlassContainer wrapper
  - REMOVE: Custom .liquidRippleOverlay() and .onLiquidTouch() modifiers
  - REPLACE: Custom background materials with standard SwiftUI components
  - IMPLEMENT: Native button interactions with .glassEffect(.regular.interactive())
  - PRESERVE: Message content rendering, accessibility labels, selection handling

Task 8: DELETE test files for custom systems
  - DELETE: ios-app/VisionForgeTests/LiquidAnimationSystemTests.swift
  - DELETE: ios-app/VisionForgeUITests/LiquidInteractionTests.swift
  - UPDATE: ios-app/VisionForgeTests/AccessibilityComplianceTests.swift for native APIs
  - UPDATE: ios-app/VisionForgeUITests/VisionForgeUITests.swift for native glass behavior
  - ADD: Test cases verifying glass effects work with accessibility preferences

Task 9: VERIFY NavigationSplitView backgroundExtensionEffect
  - IMPLEMENT: .backgroundExtensionEffect() on NavigationSplitView detail views
  - TEST: Content visually extends under glass sidebar
  - VERIFY: Navigation elements automatically adopt glass styling
  - ENSURE: Proper sidebar column width and responsive behavior maintained
```

### Implementation Patterns & Key Details

```swift
// PATTERN: NavigationSplitView with native glass and background extension
NavigationSplitView {
    // Sidebar - gets glass automatically when recompiled with iOS 26 SDK
    SessionSidebarView(selectedSessionId: $selectedSessionId)
        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 450)
} detail: {
    // Detail content with background extension under glass sidebar
    ConversationView(sessionId: selectedSessionId)
        .backgroundExtensionEffect()  // KEY: Content extends under glass
}
.navigationSplitViewStyle(.balanced)

// PATTERN: Native button styles replacing custom LiquidButton
// OLD: LiquidButton(title: "Send", style: .primary, action: sendMessage)
// NEW: Native glass button with automatic styling
Button("Send", action: sendMessage)
    .buttonStyle(.glassProminent)  // High emphasis actions

Button("Cancel", action: cancel)
    .buttonStyle(.glass)  // Secondary actions

// PATTERN: Form sections replacing LiquidSettingsCard
// OLD: LiquidSettingsCard with custom backgrounds
// NEW: Standard Form sections get glass automatically
Form {
    Section("Connection") {
        TextField("Host", text: $host)        // Gets glass automatically
        TextField("Port", text: $port)        // Gets glass automatically
        Toggle("Use HTTPS", isOn: $useHTTPS) // Gets glass automatically
    }
}

// PATTERN: Sheet presentations with automatic glass
// OLD: Custom sheet backgrounds with .ultraThinMaterial
// NEW: Automatic glass backgrounds
.sheet(isPresented: $showSettings) {
    EditableSettingsView()  // Gets glass background automatically
    // DON'T add .background(.ultraThinMaterial) - handled by system
}

// PATTERN: Toolbar with automatic glass adoption
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("New Session") { createSession() }
            .buttonStyle(.borderedProminent)  // Gets glass automatically in toolbar
    }
}

// CRITICAL: GlassEffectContainer for custom elements (rare usage)
// Only use for truly custom controls that need glass
GlassEffectContainer {
    CustomPickerControl()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))

    CustomSliderControl()
        .glassEffect(.regular, in: .capsule)
}
```

### Integration Points

```yaml
PROJECT_CONFIG:
  - update: ios-app/VisionForge.xcodeproj/project.pbxproj
  - pattern: "IPHONEOS_DEPLOYMENT_TARGET = 26.0;"
  - targets: All targets (app, tests, UI tests)

NAVIGATION:
  - update: NavigationSplitView implementations
  - pattern: ".backgroundExtensionEffect() on detail views"
  - critical: "Only detail views, not sidebar views"

COMPONENTS:
  - replace: Custom liquid components with native SwiftUI + glass styles
  - pattern: "Standard components automatically adopt glass"
  - remove: All .background(.ultraThinMaterial) usage

ENVIRONMENT:
  - remove: Custom glass-related environment objects
  - keep: NetworkManager, SessionStateManager, other non-glass managers
  - pattern: "Simplified app entry point"
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Verify iOS 26 deployment target updated
grep -r "IPHONEOS_DEPLOYMENT_TARGET" ios-app/VisionForge.xcodeproj/project.pbxproj | grep "26.0"
# Expected: Multiple matches showing "IPHONEOS_DEPLOYMENT_TARGET = 26.0;"

# Verify custom glass files deleted
find ios-app -name "*liquid*" -o -name "*Liquid*" -o -name "*glass*" -o -name "*Glass*"
# Expected: Only documentation files, no implementation files

# Build verification on iOS 26 simulator
xcodebuild -project ios-app/VisionForge.xcodeproj -scheme VisionForge -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0" build
# Expected: Clean build with no errors

# Swift syntax and style checking
swiftlint ios-app/VisionForge/ --config .swiftlint.yml
# Expected: No linting errors related to deprecated APIs
```

### Level 2: Unit Tests (Component Validation)

```bash
# Run updated unit tests
xcodebuild test -project ios-app/VisionForge.xcodeproj -scheme VisionForge -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0"
# Expected: All tests pass, no liquid glass test failures

# Verify accessibility compliance with native APIs
xcodebuild test -project ios-app/VisionForge.xcodeproj -scheme VisionForge -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0" -only-testing "VisionForgeTests/AccessibilityComplianceTests"
# Expected: All accessibility tests pass with native implementation

# Component integration tests
xcodebuild test -project ios-app/VisionForge.xcodeproj -scheme VisionForge -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=26.0" -only-testing "VisionForgeTests"
# Expected: All component tests work with native glass APIs
```

### Level 3: Integration Testing (System Validation)

```bash
# Launch app on iOS 26 simulator
xcrun simctl boot "iPhone 15 Pro (iOS 26.0)"
xcrun simctl install booted ios-app/build/VisionForge.app
xcrun simctl launch booted com.dbgventures.visionforge

# Verify NavigationSplitView glass behavior
# Manual verification: Sidebar should float with glass effect
# Manual verification: Content should extend under glass sidebar
# Manual verification: Toolbars should have glass backgrounds

# Test glass button interactions
# Manual verification: Buttons should have glass styling
# Manual verification: Touch interactions should have native feedback
# Manual verification: Button styles (.glass, .glassProminent) working

# Accessibility testing with settings
# Enable "Reduce Transparency" in iOS Simulator
# Verify: Glass effects disable automatically
# Enable "Reduce Motion"
# Verify: Animations respect user preferences

# Sheet and popover glass verification
# Open settings sheet
# Verify: Sheet has glass background automatically
# Open any popover/context menu
# Verify: Native glass styling without custom backgrounds
```

### Level 4: Creative & Domain-Specific Validation

```bash
# Performance comparison testing
# Monitor frame rate during glass interactions
# Instruments profiling for memory usage comparison
# Battery impact testing (if testing on device)

# Visual regression testing
# Compare screenshots between custom and native glass
# Verify consistency with other iOS 26 apps
# Test across different device sizes and orientations

# Advanced glass effect testing
# Test GlassEffectContainer with multiple elements
# Verify glass effect coordination across app
# Test backgroundExtensionEffect in different contexts

# Cross-device compatibility testing
# Test on multiple iOS 26 device types
# Verify graceful behavior on varying screen sizes
# Test with different accessibility settings enabled

# Integration with system behaviors
# Test during Control Center interactions
# Verify glass behavior during multitasking
# Test with dynamic type size changes
# Verify proper behavior with dark/light mode switching
```

## Final Validation Checklist

### Technical Validation

- [ ] iOS deployment target updated to 26.0 in all targets: `grep -r "IPHONEOS_DEPLOYMENT_TARGET.*26.0" ios-app/`
- [ ] All custom liquid glass files deleted: `find ios-app -name "*liquid*" -o -name "*Liquid*" | wc -l` returns 0
- [ ] App builds successfully on iOS 26: `xcodebuild build -destination "iOS Simulator,name=iPhone 15 Pro,OS=26.0"`
- [ ] All unit tests pass: `xcodebuild test -destination "iOS Simulator,name=iPhone 15 Pro,OS=26.0"`
- [ ] No custom glass environment objects: `grep -r "LiquidPerformanceMonitor\|DeviceCapabilityDetector\|AccessibilityManager" ios-app/VisionForge/`

### Feature Validation

- [ ] NavigationSplitView uses .backgroundExtensionEffect(): Manual verification in app
- [ ] All buttons use native glass styles (.glass, .glassProminent): Code review verification
- [ ] No custom .background(.ultraThinMaterial) usage: `grep -r "\.background.*Material" ios-app/VisionForge/`
- [ ] Sheets and popovers have automatic glass backgrounds: Manual testing verification
- [ ] Toolbars and navigation bars automatically adopt glass: Visual verification
- [ ] Accessibility preferences automatically respected: Test with settings enabled

### Code Quality Validation

- [ ] No references to deleted files: `xcodebuild build` succeeds without import errors
- [ ] Standard SwiftUI patterns used throughout: Code review for native API usage
- [ ] GlassEffectContainer used only for custom controls: Search for sparse usage
- [ ] Navigation structure follows iOS 26 patterns: NavigationSplitView implementation review
- [ ] No custom glass-related extensions remain: Search codebase for liquid/glass extensions

### User Experience Validation

- [ ] Glass sidebar floats above content in NavigationSplitView: Visual verification
- [ ] Content visually extends under glass navigation: backgroundExtensionEffect testing
- [ ] Touch interactions have native glass feedback: Interactive testing
- [ ] Glass effects respect accessibility preferences: Settings testing
- [ ] Performance feels smooth and native: Subjective testing across interactions
- [ ] Visual consistency with other iOS 26 apps: Comparative testing

---

## Anti-Patterns to Avoid

- ❌ Don't manually add .background(.ultraThinMaterial) - let system provide glass automatically
- ❌ Don't create custom GlassEffectContainer for every component - use for grouping only
- ❌ Don't apply .glassEffect() to standard SwiftUI components - they get glass automatically
- ❌ Don't check accessibility environment values manually - native APIs handle automatically
- ❌ Don't keep any custom liquid glass performance monitoring - native APIs are optimized
- ❌ Don't implement custom ripple effects - use .glassEffect(.regular.interactive())
- ❌ Don't use .backgroundExtensionEffect() on sidebar views - only detail views
- ❌ Don't maintain iOS 17.6 deployment target - iOS 26 required for native glass APIs