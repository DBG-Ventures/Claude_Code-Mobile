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
    
    @StateObject private var sessionViewModel = SessionListViewModel()
    @EnvironmentObject var networkManager: NetworkManager
    @State private var showingNewSessionSheet: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var sessionToDelete: SessionResponse?
    @State private var searchText: String = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
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
                NewSessionSheet(sessionViewModel: sessionViewModel)
                    .environmentObject(networkManager)
            }
            .alert("Delete Session", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        sessionViewModel.deleteSession(session)
                        sessionToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this session? This action cannot be undone.")
            }
        }
        .onAppear {
            sessionViewModel.setClaudeService(networkManager.claudeService)
            sessionViewModel.loadSessions()
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
                value: "\(sessionViewModel.sessions.count)",
                color: .blue
            )
            
            StatItem(
                icon: "circle.fill",
                title: "Active", 
                value: "\(sessionViewModel.activeSessions.count)",
                color: .green
            )
            
            StatItem(
                icon: "clock",
                title: "Recent",
                value: "\(sessionViewModel.recentSessions.count)",
                color: .orange
            )
            
            Spacer()
        }
    }
    
    // MARK: - Sessions List Section
    
    private var sessionsListSection: some View {
        Group {
            if sessionViewModel.isLoading {
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
                    SessionRow(
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
    
    private var filteredSessions: [SessionResponse] {
        if searchText.isEmpty {
            return sessionViewModel.sessions
        } else {
            return sessionViewModel.sessions.filter { session in
                session.sessionName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                session.sessionId.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Session Row Component

struct SessionRow: View {
    let session: SessionResponse
    let onSelect: (SessionResponse) -> Void
    let onDelete: (SessionResponse) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Session Icon
            Circle()
                .fill(statusColor.gradient)
                .frame(width: 44, height: 44)
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
                    
                    Text(formatDate(session.updatedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(session.messageCount) messages")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if let lastMessage = session.messages.last {
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
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
    @ObservedObject var sessionViewModel: SessionListViewModel
    @EnvironmentObject var networkManager: NetworkManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var sessionName: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Name")
                        .font(.headline)
                    
                    TextField("Enter session name...", text: $sessionName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
    
    private func createSession() {
        isCreating = true
        
        sessionViewModel.createNewSession(name: sessionName) { success in
            isCreating = false
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SessionManagerView()
        .environmentObject(NetworkManager())
}