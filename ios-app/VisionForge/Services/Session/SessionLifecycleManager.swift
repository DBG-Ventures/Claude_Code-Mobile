//
//  SessionLifecycleManager.swift
//  App lifecycle management for session persistence
//
//  Extracted from SessionRepository for clean separation of lifecycle concerns.
//  Implements iOS app state monitoring with background task management.
//

import Foundation
import UIKit
import Observation

// MARK: - Protocol Definition

protocol SessionLifecycleManagerProtocol {
    func handleAppWillEnterForeground() async
    func handleAppDidEnterBackground() async
    func startBackgroundRefresh()
    func stopBackgroundRefresh()
}

/// Service responsible for managing session state during app lifecycle transitions
@MainActor
@Observable
final class SessionLifecycleManager: SessionLifecycleManagerProtocol {

    // MARK: - Dependencies

    private let persistenceService: SessionPersistenceService
    private let syncService: SessionSyncService

    // MARK: - Observable State

    private(set) var currentAppState: AppState = .active
    private(set) var lastForegroundTransition: Date?
    private(set) var lastBackgroundTransition: Date?
    private(set) var backgroundTasksCompleted: Int = 0
    private(set) var backgroundTasksFailed: Int = 0

    // MARK: - Lifecycle Observers

    private var appLifecycleObservers: [NSObjectProtocol] = []
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Configuration

    private let backgroundTaskTimeout: TimeInterval = 25.0 // iOS gives ~30 seconds
    private let maxBackgroundOperations = 10

    // MARK: - Initialization

    init(
        persistenceService: SessionPersistenceService,
        syncService: SessionSyncService
    ) {
        self.persistenceService = persistenceService
        self.syncService = syncService

        setupLifecycleObservers()
        updateAppState()
    }

    deinit {
        Task { @MainActor in
            cleanup()
        }
    }

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        // Clear existing observers
        cleanup()

        // Monitor app lifecycle transitions
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.executeAppWillEnterForeground()
            }
        }

        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.executeAppDidEnterBackground()
            }
        }

        let terminateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppWillTerminate()
            }
        }

        let becomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppDidBecomeActive()
            }
        }

        let resignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppWillResignActive()
            }
        }

        appLifecycleObservers = [
            foregroundObserver,
            backgroundObserver,
            terminateObserver,
            becomeActiveObserver,
            resignActiveObserver
        ]

        print("📱 Session lifecycle observers registered")
    }

    private func cleanup() {
        // Remove notification observers
        for observer in appLifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        appLifecycleObservers.removeAll()

        // End any active background tasks
        endBackgroundTask()
    }

    // MARK: - SessionLifecycleManagerProtocol Implementation

    func handleAppWillEnterForeground() async {
        await executeAppWillEnterForeground()
    }

    func handleAppDidEnterBackground() async {
        await executeAppDidEnterBackground()
    }

    func startBackgroundRefresh() {
        syncService.startBackgroundRefresh()
    }

    func stopBackgroundRefresh() {
        syncService.stopBackgroundRefresh()
    }

    // MARK: - App State Handling

    private func executeAppWillEnterForeground() async {
        print("📱 App entering foreground - refreshing session state")

        currentAppState = .foreground
        lastForegroundTransition = Date()

        // Reconnect to SessionManager if needed
        if syncService.sessionManagerStatus == .disconnected {
            await syncService.forceReconnection()
        }

        // Refresh sessions from backend if connection is healthy
        if syncService.sessionManagerStatus.isHealthy {
            do {
                _ = try await syncService.refreshSessionsFromBackend()
            } catch {
                print("⚠️ Failed to refresh sessions on foreground: \(error)")
            }
        }

        // Restart background refresh
        syncService.startBackgroundRefresh()
    }

    private func executeAppDidEnterBackground() async {
        print("📱 App entering background - persisting session state")

        currentAppState = .background
        lastBackgroundTransition = Date()

        // Start background task for persistence operations
        await startBackgroundTask()

        // Stop background refresh to save battery
        syncService.stopBackgroundRefresh()

        // Perform critical persistence operations
        await performBackgroundPersistence()

        // End background task
        endBackgroundTask()
    }

    private func handleAppWillTerminate() async {
        print("📱 App terminating - final session persistence")

        currentAppState = .terminating

        // Perform emergency persistence
        await performEmergencyPersistence()

        cleanup()
    }

    private func handleAppDidBecomeActive() async {
        print("📱 App became active")
        currentAppState = .active
    }

    private func handleAppWillResignActive() async {
        print("📱 App will resign active")
        currentAppState = .inactive
    }

    // MARK: - Background Task Management

    private func startBackgroundTask() async {
        guard backgroundTaskIdentifier == .invalid else { return }

        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(
            withName: "SessionPersistence"
        ) { [weak self] in
            Task { @MainActor in
                await self?.backgroundTaskExpired()
            }
        }

        print("🔄 Started background task: \(backgroundTaskIdentifier.rawValue)")

        // Set a timer to ensure we don't exceed the background time limit
        DispatchQueue.main.asyncAfter(deadline: .now() + backgroundTaskTimeout) {
            Task { @MainActor in
                await self.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else { return }

        print("⏹️ Ending background task: \(backgroundTaskIdentifier.rawValue)")

        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }

    private func backgroundTaskExpired() async {
        print("⏰ Background task expired - performing emergency cleanup")
        await performEmergencyPersistence()
        endBackgroundTask()
    }

    // MARK: - Persistence Operations

    private func performBackgroundPersistence() async {
        let startTime = Date()

        do {
            // Quick persistence of critical session data
            await persistenceService.performBackgroundPersistence()

            backgroundTasksCompleted += 1
            print("✅ Background persistence completed in \(Date().timeIntervalSince(startTime))s")

        } catch {
            backgroundTasksFailed += 1
            print("⚠️ Background persistence failed: \(error)")
        }
    }

    private func performEmergencyPersistence() async {
        do {
            // Minimal, critical data persistence only
            await persistenceService.performEmergencyPersistence()
            print("🚨 Emergency persistence completed")
        } catch {
            print("🚨 Emergency persistence failed: \(error)")
        }
    }

    // MARK: - Session Recovery

    /// Restore sessions after app launch or foreground transition
    func restoreSessionState() async throws {
        guard persistenceService.isInitialized else {
            throw SessionLifecycleError.persistenceNotReady
        }

        do {
            // Load from local persistence first for immediate UI
            let localSessions = try await persistenceService.loadRecentSessions(limit: 20)

            print("✅ Restored \(localSessions.count) sessions from persistence")

            // Then sync with SessionManager backend for latest state
            if syncService.sessionManagerStatus.isHealthy {
                _ = try await syncService.refreshSessionsFromBackend()
            }

        } catch {
            print("⚠️ Failed to restore session state: \(error)")
            throw SessionLifecycleError.restoreFailed(error)
        }
    }

    /// Prepare for app suspension with quick persistence
    func prepareForSuspension() async {
        currentAppState = .suspending

        await startBackgroundTask()
        await performBackgroundPersistence()
        endBackgroundTask()
    }

    // MARK: - State Monitoring

    private func updateAppState() {
        switch UIApplication.shared.applicationState {
        case .active:
            currentAppState = .active
        case .inactive:
            currentAppState = .inactive
        case .background:
            currentAppState = .background
        @unknown default:
            currentAppState = .unknown
        }
    }

    // MARK: - Statistics & Debugging

    func getLifecycleStatistics() -> LifecycleStatistics {
        return LifecycleStatistics(
            currentAppState: currentAppState,
            lastForegroundTransition: lastForegroundTransition,
            lastBackgroundTransition: lastBackgroundTransition,
            backgroundTasksCompleted: backgroundTasksCompleted,
            backgroundTasksFailed: backgroundTasksFailed,
            hasActiveBackgroundTask: backgroundTaskIdentifier != .invalid,
            observersRegistered: appLifecycleObservers.count
        )
    }

    func getDebugInfo() -> String {
        return """
        SessionLifecycleManager Debug:
        - Current state: \(currentAppState)
        - Background task active: \(backgroundTaskIdentifier != .invalid)
        - Observers registered: \(appLifecycleObservers.count)
        - Background tasks completed: \(backgroundTasksCompleted)
        - Background tasks failed: \(backgroundTasksFailed)
        - Last foreground: \(lastForegroundTransition?.formatted() ?? "never")
        - Last background: \(lastBackgroundTransition?.formatted() ?? "never")
        """
    }
}

// MARK: - Supporting Types

enum AppState: String, CaseIterable {
    case active = "active"
    case inactive = "inactive"
    case background = "background"
    case foreground = "foreground"
    case suspending = "suspending"
    case terminating = "terminating"
    case unknown = "unknown"

    var displayName: String {
        return rawValue.capitalized
    }
}

struct LifecycleStatistics {
    let currentAppState: AppState
    let lastForegroundTransition: Date?
    let lastBackgroundTransition: Date?
    let backgroundTasksCompleted: Int
    let backgroundTasksFailed: Int
    let hasActiveBackgroundTask: Bool
    let observersRegistered: Int

    var backgroundSuccessRate: Double {
        let totalTasks = backgroundTasksCompleted + backgroundTasksFailed
        guard totalTasks > 0 else { return 1.0 }
        return Double(backgroundTasksCompleted) / Double(totalTasks)
    }

    var isHealthy: Bool {
        return observersRegistered > 0 && backgroundSuccessRate > 0.8
    }
}

enum SessionLifecycleError: LocalizedError {
    case persistenceNotReady
    case restoreFailed(Error)
    case backgroundTaskTimeout
    case emergencyPersistenceFailed

    var errorDescription: String? {
        switch self {
        case .persistenceNotReady:
            return "Persistence service not initialized"
        case .restoreFailed(let error):
            return "Failed to restore session state: \(error.localizedDescription)"
        case .backgroundTaskTimeout:
            return "Background task timed out"
        case .emergencyPersistenceFailed:
            return "Emergency persistence failed"
        }
    }
}