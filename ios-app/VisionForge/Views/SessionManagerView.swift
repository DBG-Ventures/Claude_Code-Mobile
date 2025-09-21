//
//  SessionManagerView.swift
//  Multiple concurrent session management UI.
//
//  SwiftUI interface for managing multiple Claude Code conversation sessions with
//  session switching, creation, and deletion capabilities.
//

import SwiftUI
import Combine

struct SessionManagerView: View {

    // MARK: - State Properties

    @Environment(SessionRepository.self) var sessionRepository
    @Environment(NetworkManager.self) var networkManager
    @State private var showingNewSessionSheet: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var sessionToDelete: SessionManagerResponse?
    @State private var searchText: String = ""
    
    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    // Header with search
                    headerSection
                    
                    // Sessions List
                    sessionsListSection
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewSessionSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSessionSheet) {
                NewSessionSheet()
            }
            .alert("Delete Session", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        Task {
                            try? await sessionRepository.deleteSession(session.sessionId)
                        }
                        sessionToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this session? This action cannot be undone.")
            }
        }
        .onAppear {
            Task {
                do {
                    _ = try await sessionRepository.getAllSessions()
                } catch {
                    print("⚠️ Failed to load sessions: \(error)")
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            
            // Session Stats
            sessionStatsView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Session Stats
    
    private var sessionStatsView: some View {
        HStack(spacing: 20) {
            StatItem(
                icon: "message.badge",
                title: "Total",
                value: "\(sessionRepository.sessions.count)",
                color: .blue
            )

            StatItem(
                icon: "circle.fill",
                title: "Active",
                value: "\(sessionRepository.activeSessions.count)",
                color: .green
            )

            StatItem(
                icon: "clock",
                title: "Recent",
                value: "\(sessionRepository.recentSessions.count)",
                color: .orange
            )
            
            Spacer()
        }
    }
    
    // MARK: - Sessions List Section
    
    private var sessionsListSection: some View {
        Group {
            if sessionRepository.isLoading {
                loadingView
            } else if filteredSessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading sessions...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.badge")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No Sessions Yet" : "No Matching Sessions")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(searchText.isEmpty ? 
                     "Start a new conversation with Claude Code" :
                     "Try adjusting your search terms")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if searchText.isEmpty {
                Button(action: { showingNewSessionSheet = true }) {
                    Label("New Session", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - Sessions List
    
    private var sessionsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(filteredSessions) { session in
                    SessionManagerRow(
                        session: session,
                        onSelect: { selectedSession in
                            // Navigate to conversation
                            // This would typically use a navigation coordinator
                        },
                        onDelete: { sessionToDelete in
                            self.sessionToDelete = sessionToDelete
                            self.showingDeleteAlert = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredSessions: [SessionManagerResponse] {
        if searchText.isEmpty {
            return sessionRepository.sessions
        } else {
            return sessionRepository.sessions.filter { session in
                (session.sessionName ?? "").localizedCaseInsensitiveContains(searchText) ||
                session.sessionId.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Session Row Component

struct SessionManagerRow: View {
    let session: SessionManagerResponse
    let onSelect: (SessionManagerResponse) -> Void
    let onDelete: (SessionManagerResponse) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Session Icon
            Circle()
                .frame(width: 44, height: 44)
                .glassEffect(.clear.tint(statusColor.opacity(0.8)), in: Circle())
                .overlay {
                    Image(systemName: statusIcon)
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .semibold))
                }
            
            // Session Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.sessionName ?? "Untitled Session")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatDate(session.lastActiveAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(session.messageCount) messages")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if let lastMessage = session.conversationHistory?.last {
                    Text(lastMessage.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            
            // Actions
            VStack(spacing: 8) {
                Button(action: { onSelect(session) }) {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                }
                
                Button(action: { onDelete(session) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.body.weight(.semibold))
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(session)
        }
    }
    
    private var statusColor: Color {
        switch session.status {
        case .active:
            return .green
        case .completed:
            return .blue
        case .error:
            return .red
        case .paused:
            return .orange
        }
    }
    
    private var statusIcon: String {
        switch session.status {
        case .active:
            return "message.badge.filled"
        case .completed:
            return "checkmark"
        case .error:
            return "exclamationmark.triangle.fill"
        case .paused:
            return "pause.fill"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Stat Item Component

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - New Session Sheet

struct NewSessionSheet: View {
    @Environment(SessionRepository.self) var sessionRepository
    @Environment(NetworkManager.self) var networkManager
    @Environment(\.presentationMode) var presentationMode

    @State private var sessionName: String = ""
    @State private var workingDirectory: String = ""
    @State private var useCustomWorkingDir: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    // Common working directory presets
    private let workingDirPresets = [
        ("Project Root (Default)", ""),
        ("Desktop", "~/Desktop"),
        ("Documents", "~/Documents"),
        ("Downloads", "~/Downloads"),
        ("Development", "~/Development"),
        ("Custom Path", "custom")
    ]
    @State private var selectedPreset = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Error message if any
                if let errorMessage = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                }

                // Session Name Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Name")
                        .font(.headline)

                    TextField("Enter session name...", text: $sessionName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Working Directory Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Working Directory")
                        .font(.headline)

                    Text("Specify the working directory for Claude SDK session storage. This affects where session files are stored and project context.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Working Directory Options
                    VStack(spacing: 12) {
                        Picker("Working Directory", selection: $selectedPreset) {
                            ForEach(0..<workingDirPresets.count, id: \.self) { index in
                                Text(workingDirPresets[index].0).tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )

                        // Custom path input (shown when "Custom Path" is selected)
                        if selectedPreset == workingDirPresets.count - 1 {
                            TextField("Enter custom working directory path...", text: $workingDirectory)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        // Working directory preview
                        if !effectiveWorkingDirectory.isEmpty {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.blue)
                                Text("Path: \(effectiveWorkingDirectory)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.tertiarySystemGroupedBackground))
                            )
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createSession()
                    }
                    .disabled(sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }

    private var effectiveWorkingDirectory: String {
        if selectedPreset == workingDirPresets.count - 1 {
            return workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return workingDirPresets[selectedPreset].1
        }
    }
    
    private func createSession() {
        isCreating = true
        errorMessage = nil

        let workingDir = effectiveWorkingDirectory.isEmpty ? nil : effectiveWorkingDirectory

        Task {
            do {
                // Create session using SessionRepository
                let session = try await sessionRepository.createSession(
                    name: sessionName,
                    workingDirectory: workingDir
                )

                await MainActor.run {
                    isCreating = false
                    print("✅ Created session: \(session.sessionId)")

                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create session: \(error.localizedDescription)"
                    print("⚠️ Failed to create session: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SessionManagerView()
        .previewEnvironment()
}
