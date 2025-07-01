import SwiftUI
import AVFoundation
import UIKit
import PDFKit
import UniformTypeIdentifiers
import AVKit

// New enum for script input type
enum ScriptInputType: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case text = "Text File"
    case typed = "Type It"

    var id: String { self.rawValue }
}

enum VoiceGender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
    
    var id: String { self.rawValue }
}


struct SerializableColor: Codable, Equatable {
    var r, g, b, a: Double

    init(_ color: Color) {
        let ui = UIColor(color)
        var r : CGFloat = 0, g : CGFloat = 0, b : CGFloat = 0, a : CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = .init(r); self.g = .init(g); self.b = .init(b); self.a = .init(a)
    }

    var swiftUIColor: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }
}

struct ContentView: View {
    // MARK: - State Variables
    @State private var isShowingSplash: Bool = true
    @State private var fileContent: String = ""
    @State private var dialogue: [(character: String, line: String)] = []
    @State private var characters: [String] = []
    @State private var selectedCharacters: Set<String> = []
    @State private var isCharacterSelected: Bool = false

    @State private var currentUtteranceIndex: Int = 0
    @State private var isSpeaking: Bool = false
    @State private var isPaused: Bool = false
    @State private var isUserLine: Bool = false

    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var speechDelegate: AVSpeechSynthesizerDelegateWrapper?

    @State private var showScriptCompletionAlert: Bool = false
    @State private var displayLinesAsRead: Bool = true
    @State private var displayMyLines: Bool = false
    @State private var isShowingCharacterCustomization: Bool = false
    @State private var characterOptions: [String: CharacterOptions] = [:]
    
    @State private var showColorDuplicateWarning: Bool = false
    @State private var pendingColorSelection: (characterName: String, color: Color)? = nil
    @State private var showVoiceDuplicateWarning: Bool = false
    @State private var pendingVoiceSelection: (characterName: String, voiceID: String)? = nil
    
    @State private var isShowingStartingLineSelection: Bool = false
    @State private var selectedStartingLineIndex: Int? = nil
    @State private var showLastLineWarning: Bool = false
    @State private var hasSetStartingLine: Bool = false
    @State private var startingLineIndex: Int = 0
    
    @State private var showTapToContinue: Bool = false
    @State private var firstVideoURL: URL?
    @State private var secondVideoURL: URL?
    @State private var hasPlayedFirstVideo = false
    @State private var isPlayingSecondVideo = false
    
    @State private var showHints: Bool = true
    @State private var hintClickCount: Int = 0
    @State private var currentHintLineIndex: Int = -1
    @State private var revealedWords: [String] = []
    
    @State private var isShowingHomepage: Bool = true
    @State private var isShowingScriptLibrary: Bool = false
    @State private var expandedCharacterLists: Set<UUID> = []
    @State private var lastSaveTime: Date = Date()
    @State private var pendingSave: Bool = false
    @State private var isLoadedScript: Bool = false
    
    @FocusState private var isScriptNameFocused: Bool
    @State private var scriptName: String = ""
    @State private var speechSessionId: UUID = UUID()
    
    @State private var savedCharacterOptions: [String: CharacterOptions] = [:]
    
    @State private var wasPlayingBeforeRating: Bool = false
    @State private var wasPausedBeforeRating: Bool = false
    @State private var expandedStartingLines: Set<UUID> = []
    
    @State private var showDeleteConfirmation: Bool = false
    @State private var scriptToDelete: SavedScript? = nil

    @State private var hasTappedStars: Bool = false
    @State private var selectedStarRating: Int = 0
    @State private var showRatingAlert: Bool = false
    @State private var showRatingPrompt: Bool = false
    @State private var showStarRating: Bool = false
    @State private var appUsageTimer: Timer?
    @State private var usageStartTime: Date?
    @State private var hasPromptedForRating: Bool = false
    private let ratingPromptDelay: TimeInterval = 10.0

    enum AlertType: Identifiable {
        case noCharacterSelected
        case displayLinesAsReadInfo
        case notApplicableInfo
        case displayMyLinesInfo
        case lastLineWarning
        case hintsInfo
        case scriptFormatError
        case emptyScriptName
        case emptyScriptNameAndNoCharacter // NEW

        var id: Int {
            switch self {
            case .noCharacterSelected: return 0
            case .displayLinesAsReadInfo: return 1
            case .notApplicableInfo: return 2
            case .displayMyLinesInfo: return 3
            case .lastLineWarning: return 4
            case .hintsInfo: return 5
            case .scriptFormatError: return 6
            case .emptyScriptName: return 7
            case .emptyScriptNameAndNoCharacter: return 8 // NEW
            }
        }
    }

    @State private var activeAlert: AlertType? = nil
    @State private var isShowingDocumentPicker: Bool = false
    @State private var selectedFileURL: URL? = nil
    @State private var hasUploadedFile: Bool = false
    @State private var hasPressedContinue: Bool = false
    @State private var uploadedFileName: String = ""
    @State private var inputType: ScriptInputType = .text
    @State private var splashPlayer = AVPlayer()
    @State private var videoFinished = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLibraryOpen: Bool = false
    
    // Updated to use LibraryManager
    @StateObject private var libraryManager = LibraryManager()
    @State private var currentSavedScript: SavedScript? = nil

    var body: some View {
        ZStack(alignment: .leading) {
            mainContentView
                .navigationBarHidden(isShowingSplash)
            
            // Hamburger menu slide-in panel
            if isLibraryOpen {
                // Dark overlay background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isLibraryOpen = false
                        }
                    }
                
                // Menu panel
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Menu")
                            .font(.title2)
                            .bold()
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                isLibraryOpen = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    
                    // Menu options
                    VStack(spacing: 0) {
                        // Upload Script button
                        Button(action: {
                            navigateToUploadScript()
                        }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                                
                                Text("Upload Script")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                        
                        // Script Library button
                        Button(action: {
                            navigateToScriptLibrary()
                        }) {
                            HStack {
                                Image(systemName: "books.vertical.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                
                                Text("Script Library")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .frame(maxWidth: 320)
                .background(Color(UIColor.systemBackground))
                .transition(.move(edge: .leading))
            }
        }
        .alert(isPresented: $showScriptCompletionAlert) {
            Alert(
                title: Text("You've reached the end!"),
                message: Text("Would you like to keep the same settings or change your settings?"),
                primaryButton: .default(Text("Keep Settings")) {
                    restartScript(keepSettings: true)
                },
                secondaryButton: .default(Text("Change Settings")) {
                    restartScript(keepSettings: false)
                }
            )
        }
    }

    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        if isShowingSplash {
            splashView
                .onAppear { print("🔍 Navigation: Showing splash") }
        } else {
            NavigationView {
                if isShowingHomepage {
                    homepageView
                        .onAppear { print("🔍 Navigation: Showing homepage") }
                } else if isShowingScriptLibrary {
                    scriptLibraryView
                        .onAppear { print("🔍 Navigation: Showing script library") }
                } else if !hasUploadedFile {
                    uploadView
                        .onAppear { print("🔍 Navigation: Showing upload view - hasUploadedFile: \(hasUploadedFile)") }
                } else if !hasPressedContinue {
                    continueView
                        .onAppear { print("🔍 Navigation: Showing continue view - hasPressedContinue: \(hasPressedContinue)") }
                } else if !isShowingCharacterCustomization {
                    settingsView
                        .onAppear { print("🔍 Navigation: Showing settings view - isShowingCharacterCustomization: \(isShowingCharacterCustomization)") }
                } else if !isShowingStartingLineSelection {
                    characterCustomizationView
                        .onAppear { print("🔍 Navigation: Showing character customization - isShowingStartingLineSelection: \(isShowingStartingLineSelection)") }
                } else if !isCharacterSelected {
                    startingLineSelectionView
                        .onAppear { print("🔍 Navigation: Showing starting line selection - isCharacterSelected: \(isCharacterSelected)") }
                } else {
                    scriptReadingView
                        .onAppear { print("🔍 Navigation: Showing script reading view - ALL CONDITIONS MET") }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    
    // MARK: - Splash View
    @ViewBuilder
    private var splashView: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .white)
                .ignoresSafeArea()

            VStack {
                VStack(spacing: 10) {
                    Text("Welcome to")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)

                    Text("SceneAloud!")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                }
                .padding(.top, 160)

                Spacer()
                
                // Video player with dark mode support
                if let videoURLs = getVideoURLsForColorScheme() {
                    ZStack {
                        // Background that adapts to color scheme
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.black : Color.white)
                            .frame(width: 575, height: 575)
                            .cornerRadius(15)
                        
                        VideoPlayer(player: splashPlayer)
                            .frame(width: 575, height: 575)
                            .background(Color.clear)
                            .clipped()
                            .cornerRadius(15)
                            .disabled(true)
                            .allowsHitTesting(false)
                        
                        // Multiple overlays to cover black areas (only in light mode)
                        if colorScheme == .light {
                            // Specific overlay for black rectangle between video and "SceneAloud!" text
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 575, height: 100) // Taller to cover the problem area
                                .position(x: 287.5, y: 50) // Higher up to cover area above video
                                .allowsHitTesting(false)
                            
                            // Top overlay (original)
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 575, height: 105)
                                .position(x: 287.5, y: 75)
                                .allowsHitTesting(false)
                            
                            // Bottom overlay
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 575, height: 150)
                                .position(x: 287.5, y: 495)
                                .allowsHitTesting(false)
                            
                            // Left overlay
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 50, height: 575)
                                .position(x: 25, y: 287.5)
                                .allowsHitTesting(false)
                            
                            // Right overlay
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 50, height: 575)
                                .position(x: 550, y: 287.5)
                                .allowsHitTesting(false)
                            
                            // Corner overlays for rounded corners
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.clear)
                                .stroke(Color.white, lineWidth: 15)
                                .frame(width: 575, height: 575)
                                .allowsHitTesting(false)
                        }
                    }
                    .onAppear {
                        setupFirstVideo(firstVideoURL: videoURLs.first, secondVideoURL: videoURLs.second)
                    }
                    .onDisappear {
                        cleanupVideoPlayer()
                    }
                } else {
                    // Fallback if video files are not found
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .cornerRadius(15)
                        .overlay(
                            Text("Video not found")
                                .foregroundColor(.gray)
                        )
                }
                
                Spacer()
                
                // Fixed height container for tap text to prevent credits from moving
                VStack {
                    if showTapToContinue {
                        Text("Tap anywhere to continue")
                            .font(.body)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .opacity(0.8)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.5), value: showTapToContinue)
                    } else {
                        // Invisible placeholder to maintain layout
                        Text("Tap anywhere to continue")
                            .font(.body)
                            .opacity(0)
                    }
                }
                .frame(height: 30) // Fixed height to prevent layout shifts
                .padding(.bottom, 2.5)

                VStack(spacing: 5) {
                    Text("Created by Lucy Brown")
                    Text("Sound Design and Logo by Abrielle Smith")
                }
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 155)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            handleSplashTap()
        }
    }
    
    // MARK: - Homepage View
    @ViewBuilder
    private var homepageView: some View {
        VStack(spacing: 0) {
            // Top section with title, subtitle, and buttons grouped together
            VStack(spacing: 0) {
                Text("Home")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                Text("Choose an option to get started")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)  // Space before buttons
                
                // Main action buttons - directly under the subtitle
                VStack(spacing: 40) {
                    // Upload Script button
                    Button(action: {
                        isLoadedScript = false
                        isShowingHomepage = false
                        // This will navigate to the upload view since hasUploadedFile is still false
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                            Text("Upload Script")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                    
                    // Library button
                    Button(action: {
                        isShowingHomepage = false
                        isShowingScriptLibrary = true
                    }) {
                        HStack {
                            Image(systemName: "books.vertical.fill")
                                .font(.title2)
                            Text("Script Library")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            // Spacer to fill remaining space
            Spacer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // No hamburger button on homepage as requested
            ToolbarItem(placement: .principal) {
                Text("")
                    .foregroundColor(.clear)
            }
        }
    }
    
    // MARK: - Script Library View
    @ViewBuilder
    private var scriptLibraryView: some View {
        VStack(spacing: 0) {
            // Header
            VStack {
                Text("Script Library")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 20)
            
            // Scripts list
            if libraryManager.scripts.isEmpty {
                // Empty state - centered
                VStack(spacing: 15) {
                    Spacer()
                    
                    Image(systemName: "books.vertical")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                            
                    Text("No Saved Scripts")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                            
                    Text("You don't have any saved scripts yet")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                            
                    Text("Scripts you rehearse will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                            
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
            } else {
                
                // Scripts list
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(libraryManager.scripts.sorted(by: { $0.dateSaved > $1.dateSaved })) { script in
                            scriptLibraryCard(for: script)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .foregroundColor(.clear)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    isShowingScriptLibrary = false
                    isShowingHomepage = true
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        isLibraryOpen.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Main menu")
            }
        }
        .alert("Delete Script", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                scriptToDelete = nil
            }
            Button("Confirm", role: .destructive) {
                if let script = scriptToDelete {
                    deleteScript(script)  // Use our helper function, not libraryManager.delete
                    print("🗑️ Deleted script: \(script.title)")
                }
                scriptToDelete = nil
            }
        } message: {
            if let script = scriptToDelete {
                Text("Are you sure you want to delete '\(script.title)'? This action cannot be undone.")
            } else {
                Text("Are you sure you want to delete this script? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Script Library Card
    @ViewBuilder
    private func scriptLibraryCard(for script: SavedScript) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Script Title with delete button
            HStack {
                Text(script.title)
                    .font(.headline)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Delete button
                Button(action: {
                    scriptToDelete = script
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Character Names
            VStack(alignment: .leading, spacing: 4) {
                Text("Characters:")
                    .font(.subheadline)
                    .foregroundColor(adaptiveSecondaryColor)
                
                let allCharacters = getCharacterNamesForScript(script)
                let isJustListening = script.settings.selectedCharacters.contains("Just Listening") || script.settings.selectedCharacters.contains("Not Applicable")
                
                if isJustListening {
                    // When "Just Listening" is selected, show it first, then all other characters
                    let isExpanded = expandedCharacterLists.contains(script.id)
                    let hasMoreCharacters = allCharacters.count > 3
                    
                    Button(action: {
                        if isExpanded {
                            expandedCharacterLists.remove(script.id)
                        } else {
                            expandedCharacterLists.insert(script.id)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            // Show "Just Listening" first (highlighted as the user's selection)
                            Text("Just Listening")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .bold()
                                .padding(.leading, 8)
                            
                            // Show other characters based on expanded state
                            if isExpanded {
                                // Show all characters when expanded
                                ForEach(allCharacters, id: \.self) { characterName in
                                    Text(characterName.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(adaptiveSecondaryColor)
                                        .padding(.leading, 8)
                                }
                            } else {
                                // Show limited characters when collapsed
                                let displayCharacters = allCharacters.prefix(3)
                                ForEach(Array(displayCharacters), id: \.self) { characterName in
                                    Text(characterName.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(adaptiveSecondaryColor)
                                        .padding(.leading, 8)
                                }
                                
                                // Add "..." if there are more characters and not expanded
                                if hasMoreCharacters {
                                    Text("... and \(allCharacters.count - 3) more (tap to expand)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .italic()
                                        .padding(.leading, 8)
                                }
                            }
                            
                            // Add "tap to collapse" hint when expanded and there were originally more characters
                            if isExpanded && hasMoreCharacters {
                                Text("(tap to collapse)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .italic()
                                    .padding(.leading, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!hasMoreCharacters) // Only make it tappable if there are more characters to show
                    
                } else {
                    // Show actual script characters when user is playing specific characters
                    let userCharacters = script.settings.selectedCharacters.filter { character in
                        // Make sure the character actually exists in the script AND isn't the old "Not Applicable"
                        character != "Not Applicable" && allCharacters.contains { $0.caseInsensitiveCompare(character) == .orderedSame }
                    }
                    let otherCharacters = allCharacters.filter { character in
                        // Characters that the user is NOT playing
                        !script.settings.selectedCharacters.contains { $0.caseInsensitiveCompare(character) == .orderedSame }
                    }
                    
                    let isExpanded = expandedCharacterLists.contains(script.id)
                    let hasMoreCharacters = otherCharacters.count > 3
                    
                    Button(action: {
                        if isExpanded {
                            expandedCharacterLists.remove(script.id)
                        } else {
                            expandedCharacterLists.insert(script.id)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            // Show user's characters first (the ones they're actually playing)
                            if !userCharacters.isEmpty {
                                ForEach(userCharacters, id: \.self) { characterName in
                                    Text(characterName.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(getCharacterHighlightColor(characterName, script: script))
                                        .bold()
                                        .padding(.leading, 8)
                                }
                            }
                            
                            // Show other characters based on expanded state
                            if isExpanded {
                                // Show all other characters when expanded
                                ForEach(otherCharacters, id: \.self) { characterName in
                                    Text(characterName.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(adaptiveSecondaryColor)
                                        .padding(.leading, 8)
                                }
                            } else {
                                // Show limited other characters when collapsed
                                let displayOtherCharacters = otherCharacters.prefix(3)
                                ForEach(Array(displayOtherCharacters), id: \.self) { characterName in
                                    Text(characterName.capitalized)
                                        .font(.subheadline)
                                        .foregroundColor(adaptiveSecondaryColor)
                                        .padding(.leading, 8)
                                }
                                
                                // Add "..." if there are more characters and not expanded
                                if hasMoreCharacters {
                                    Text("... and \(otherCharacters.count - 3) more (tap to expand)")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .italic()
                                        .padding(.leading, 8)
                                }
                            }
                            
                            // Add "tap to collapse" hint when expanded and there were originally more characters
                            if isExpanded && hasMoreCharacters {
                                Text("(tap to collapse)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .italic()
                                    .padding(.leading, 8)
                            }
                            
                            // Show message if no characters found (shouldn't happen but just in case)
                            if userCharacters.isEmpty && otherCharacters.isEmpty {
                                Text("No characters found")
                                    .font(.caption)
                                    .foregroundColor(adaptiveSecondaryColor)
                                    .italic()
                                    .padding(.leading, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!hasMoreCharacters) // Only make it tappable if there are more characters to show
                }
            }
            
            // Settings
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings:")
                    .font(.subheadline)
                    .foregroundColor(adaptiveSecondaryColor)
                
                HStack(spacing: 15) {
                    Text("Display lines as read")
                        .font(.caption)
                        .foregroundColor(script.settings.displayLinesAsRead ? .green : adaptiveSecondaryColor)
                    
                    Text("Display my lines")
                        .font(.caption)
                        .foregroundColor(script.settings.displayMyLines ? .green : adaptiveSecondaryColor)
                    
                    Text("Hints")
                        .font(.caption)
                        .foregroundColor(script.settings.showHints ? .green : adaptiveSecondaryColor)
                }
            }
            
            // Starting Line
            VStack(alignment: .leading, spacing: 4) {
                let startingLineInfo = getStartingLineInfo(script)
                let isExpanded = expandedStartingLines.contains(script.id)
                let shouldTruncate = startingLineInfo.line.count > 50 && startingLineInfo.line != "End of script"
                
                HStack {
                    Text("Starting line:")
                        .font(.subheadline)
                        .foregroundColor(adaptiveSecondaryColor)
                    Spacer()
                }
                
                if shouldTruncate {
                    Button(action: {
                        if isExpanded {
                            expandedStartingLines.remove(script.id)
                        } else {
                            expandedStartingLines.insert(script.id)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            if isExpanded {
                                // Show full text with character name in bold - consistent alignment
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(startingLineInfo.character + ":")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(startingLineInfo.line)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                // Show truncated text with character name bold
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(startingLineInfo.character + ":")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(String(startingLineInfo.line.prefix(50)) + "...")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            
                            // Add expand/collapse hint
                            Text(isExpanded ? "(tap to collapse)" : "(tap to expand)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Show full text with character name in bold when no truncation needed
                    if startingLineInfo.character.isEmpty {
                        Text(startingLineInfo.line)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(startingLineInfo.character + ":")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(startingLineInfo.line)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            
            // Progress Snippet
            VStack(alignment: .leading, spacing: 8) {
                Text("Progress:")
                    .font(.subheadline)
                    .foregroundColor(adaptiveSecondaryColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    let snippet = getProgressSnippet(script)
                    ForEach(Array(snippet.enumerated()), id: \.offset) { index, entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.character)
                                .font(.caption)
                                .bold()
                                .foregroundColor(.primary)
                            
                            Text(entry.line)
                                .font(.caption)
                                .padding(4)
                                .background(
                                    entry.isCurrentLine ?
                                    getColorForCharacterInScript(entry.character, script: script).opacity(0.7) :
                                    getColorForCharacterInScript(entry.character, script: script).opacity(0.3)
                                )
                                .cornerRadius(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            Button(action: {
                loadScriptFromLibrary(script)
            }) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.body)
                    Text("Load Script")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding(15)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    // MARK: - Upload View
    @ViewBuilder
    private var uploadView: some View {
        VStack(spacing: 20) {
            Text("Upload Your Script")
                .font(.largeTitle)
                .bold()
                .padding(.top, 20)

            Text("Is your script a PDF, a text file, or will you type it?")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Picker("Script Input Type", selection: $inputType) {
                ForEach(ScriptInputType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 40)

            inputTypeContent

            Spacer()
        }
        .padding()
        .alert(item: $activeAlert) { alert in
            alertForType(alert)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Invisible title to enable navigation bar
            ToolbarItem(placement: .principal) {
                Text("")
                    .foregroundColor(.clear)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Reset any uploaded content and go back to homepage
                    uploadedFileName = ""
                    fileContent = ""
                    selectedFileURL = nil
                    dialogue = []
                    characters = []
                    selectedCharacters = []
                    hasUploadedFile = false
                    hasPressedContinue = false
                    isShowingHomepage = true
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        isLibraryOpen.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Main menu")
            }
        }
    }

    // MARK: - Input Type Content
    @ViewBuilder
    private var inputTypeContent: some View {
        switch inputType {
        case .typed:
            typedInputView
        case .pdf:
            pdfInputView
        case .text:
            textFileInputView
        }
    }

    private var typedInputView: some View {
        VStack(spacing: 15) {
            // Format guidance
            VStack(alignment: .leading, spacing: 8) {
                Text("Script Format:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Please format your script with each line as:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Character Name: Line of dialogue")
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                Text("Example:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("JOHN: Hello, how are you today?")
                    Text("MARY: I'm doing great, thanks for asking!")
                    Text("JOHN: That's wonderful to hear.")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            
            // TextEditor with placeholder and tap-to-dismiss
            ZStack(alignment: .topLeading) {
                VStack {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $fileContent)
                            .frame(height: 200)
                            .border(Color.gray, width: 1)
                        
                        // Placeholder text
                        if fileContent.isEmpty {
                            Text("Type script here")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }

            Button(action: {
                // Dismiss keyboard first
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                // Always validate format
                let convertedScript = convertScriptToCorrectFormat(from: fileContent)
                let testDialogue = extractDialogue(from: convertedScript)
                
                // Check if any dialogue was extracted OR if fileContent is empty
                if testDialogue.isEmpty || fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Show format error alert
                    activeAlert = .scriptFormatError
                    return
                }
                
                // If format is valid, proceed normally
                self.dialogue = testDialogue
                let extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
                self.characters = extractedCharacters
                ensureCharacterOptions()
                updateHighlightColors()
                self.uploadedFileName = "Typed Script"
                self.hasPressedContinue = false
                self.hasUploadedFile = true
            }) {
                Text("Submit Script")
                    .font(.headline)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - PDF Input View
    @ViewBuilder
    private var pdfInputView: some View {
        VStack(spacing: 20) {
            Text("Hello! To keep this app free, PDF conversion isn't supported. Instead, copy the prompt below into ChatGPT or Claude AI(or any similar AI tool) and attach your script PDF to convert your PDF to a text file for free.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            pdfButtons
        }
    }

    // MARK: - PDF Buttons
    @ViewBuilder
    private var pdfButtons: some View {
        Button(action: {
            UIPasteboard.general.string = """
            I have a PDF file attached that contains the script for a play.  The script contains scene descriptions, parenthetical notations, and most importantly, the lines each character should read.  Scene descriptions will often be written in italics.

            Your job is to extract the character lines, and nothing else.   It is important for you to extract all of the lines until you reach the end of the play.  The end of the play will often be indicated by "END OF PLAY" or something similar.

            Please return the lines in the following format:

            "Character name: Line"

            If the text in the PDF isn't extractable using standard methods, please use OCR to extract the text from the pages.
            If the process takes too long and is interrupted, to make this more manageable, extract the character lines one page at a time.

            You do not need to ask me if it is ok to use more sophisticated OCR techniques, and you don't need to ask me each time you finish a page.
            I want you to extract all of the lines until you reach the end of the play.  If you need to do this page by page, do so without asking me if it's ok.

            Once you have finished all the pages, please consolidate all of the prior lines from all pages into a single file, and allow me to download the file.  Make sure the lines are in the original order.
            """
        }) {
            Text("Copy Prompt")
                .font(.headline)
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
        }

        Button(action: {
            if let url = URL(string: "https://chat.openai.com/") {
                UIApplication.shared.open(url)
            }
        }) {
            Text("Go to ChatGPT")
                .font(.headline)
                .padding()
                .foregroundColor(.white)
                .background(Color.green)
                .cornerRadius(10)
        }

        Button(action: {
            if let url = URL(string: "https://claude.ai/new") {
                UIApplication.shared.open(url)
            }
        }) {
            Text("Go to Claude AI")
                .font(.headline)
                .padding()
                .foregroundColor(.white)
                .background(Color.green)
                .cornerRadius(10)
        }
    }

    // MARK: - Text File Input View
    @ViewBuilder
    private var textFileInputView: some View {
        VStack(spacing: 20) {
            // Format guidance section
            VStack(alignment: .leading, spacing: 12) {
                Text("Text File Format:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Your text file should be formatted with each line as:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Character Name: Line of dialogue")
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                Text("Example:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("JOHN: Hello, how are you today?")
                    Text("MARY: I'm doing great, thanks for asking!")
                    Text("JOHN: That's wonderful to hear.")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            
            // Upload button
            Button(action: {
                isShowingDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title)
                    Text("Select Text File")
                        .font(.headline)
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .sheet(isPresented: $isShowingDocumentPicker) {
                DocumentPicker(filePath: $selectedFileURL, allowedContentTypes: [UTType.plainText])
            }
            .onChange(of: selectedFileURL) { _, newValue in
                if let url = newValue {
                    handleFileSelection(url: url)
                }
            }
        }
    }

    // MARK: - Continue View
    @ViewBuilder
    private var continueView: some View {
        VStack(spacing: 20) {
            Text("Script Uploaded!")
                .font(.largeTitle)
                .bold()
                .padding(.top, 20)

            Text("Press Continue to select your settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack {
                Text(uploadedFileName)
                    .font(.title2)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button(action: {
                    uploadedFileName = ""
                    fileContent = ""
                    selectedFileURL = nil
                    dialogue = []
                    characters = []
                    selectedCharacters = []
                    hasUploadedFile = false
                    hasPressedContinue = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Remove uploaded script")
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)

            Button(action: {
                // Validate script format when Continue is pressed
                let convertedScript = convertScriptToCorrectFormat(from: fileContent)
                self.dialogue = self.extractDialogue(from: convertedScript)
                
                // Check if any dialogue was extracted
                if dialogue.isEmpty {
                    // Show format error alert and stay on this page
                    activeAlert = .scriptFormatError
                    return
                }
                
                // If format is valid, proceed
                let extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
                self.characters = extractedCharacters
                ensureCharacterOptions()
                updateHighlightColors()
                hasPressedContinue = true
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
        .alert(item: $activeAlert) { alert in
            alertForType(alert)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Add invisible title to enable navigation bar
            ToolbarItem(placement: .principal) {
                Text("")
                    .foregroundColor(.clear)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        isLibraryOpen.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Main menu")
            }
        }
    }

    // MARK: - Settings View
    @ViewBuilder
    private var settingsView: some View {
        ZStack(alignment: .topLeading) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading) {
                            Text("Settings")
                                .font(.largeTitle)
                                .bold()
                                .padding(.top, 20)
                                .padding(.bottom, 20)
                            
                            Text("Select your characters")
                                .font(.title2)
                                .padding(.vertical, 5)
                            
                            characterSelectionSection
                            
                            displaySettingsSection
                            
                            Spacer(minLength: 20)
                            
                            // Script name input section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Script Name")
                                    .font(.title2)
                                    .padding(.bottom, 5)
                                
                                ZStack(alignment: .topLeading) {
                                    TextField("Enter script name", text: $scriptName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.body)
                                        .focused($isScriptNameFocused)
                                    
                                    // Placeholder-like behavior when empty
                                    if scriptName.isEmpty {
                                        Text("Enter script name")
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                            .id("scriptNameField")
                            .padding(.bottom, 20)

                            Button(action: {
                                let hasScriptName = !scriptName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                let hasSelectedCharacters = !selectedCharacters.isEmpty
                                
                                // Check all possible combinations
                                if !hasScriptName && !hasSelectedCharacters {
                                    activeAlert = .emptyScriptNameAndNoCharacter
                                } else if !hasScriptName {
                                    activeAlert = .emptyScriptName
                                } else if !hasSelectedCharacters {
                                    activeAlert = .noCharacterSelected
                                } else {
                                    // All requirements met - continue
                                    updateHighlightColors()
                                    isShowingCharacterCustomization = true
                                }
                            }) {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.bottom, 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
                .onChange(of: isScriptNameFocused) { _, isFocused in
                    if isFocused {
                        print("📝 Text field focused - scrolling to center")
                        // Small delay to let keyboard animation start
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                proxy.scrollTo("scriptNameField", anchor: .center)
                            }
                        }
                    } else {
                        print("📝 Text field lost focus")
                    }
                }
            }
        }
        .alert(item: $activeAlert) { alert in
            alertForType(alert)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // invisible title to enable navigation bar
            ToolbarItem(placement: .principal) {
                Text("")
                    .foregroundColor(.clear)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    hasPressedContinue = false
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        isLibraryOpen.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Main menu")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside text field
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: selectedCharacters) { _, newValue in
            if newValue.contains("Just Listening") {
                displayMyLines = false
                showHints = false
            }
            updateHighlightColors()
        }
        .onChange(of: displayMyLines) { _, newValue in
            if newValue {
                showHints = false
            }
        }
        .onChange(of: showHints) { _, newValue in
            if newValue {
                displayMyLines = false
            }
        }
    }

    // MARK: - Character Selection Section
    @ViewBuilder
    private var characterSelectionSection: some View {
        HStack {
            Text("Just Listening")
                Button(action: { activeAlert = .notApplicableInfo }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
                Toggle("", isOn: Binding(
                    get: { selectedCharacters.contains("Just Listening") },
                    set: { newValue in
                        if newValue {
                            selectedCharacters = ["Just Listening"]
                            // Immediately disable hints when Just Listening is selected
                            showHints = false
                            displayMyLines = false
                            print("⚙️ Just Listening selected - disabled hints and displayMyLines")
                        } else {
                            selectedCharacters.remove("Just Listening")
                            print("⚙️ Just Listening deselected")
                        }
                    }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 2)

        ForEach(characters, id: \.self) { character in
            Toggle(character.capitalized, isOn: Binding(
                get: { selectedCharacters.contains(character) },
                set: { newValue in
                    if newValue {
                        selectedCharacters.remove("Just Listening")
                        selectedCharacters.insert(character)
                    } else {
                        selectedCharacters.remove(character)
                    }
                }
            ))
            .padding(.vertical, 2)
        }
    }

    // MARK: - Display Settings Section
    @ViewBuilder
    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Display lines as read")
                    .font(.title2)
                Button(action: {
                    activeAlert = .displayLinesAsReadInfo
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Toggle("", isOn: $displayLinesAsRead)
                .labelsHidden()
        }
        .padding(.top, 20)
        VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Display my lines")
                        .font(.title2)
                    Button(action: {
                        activeAlert = .displayMyLinesInfo
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Toggle("", isOn: $displayMyLines)
                    .labelsHidden()
                    .disabled(selectedCharacters.contains("Just Listening"))
            }
        .padding(.vertical, 2)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Hints")
                    .font(.title2)
                Button(action: {
                    activeAlert = .hintsInfo
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Toggle("", isOn: $showHints)
                .labelsHidden()
                .disabled(selectedCharacters.contains("Just Listening"))
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Character Customization List
    @ViewBuilder
    private var characterCustomizationList: some View {
        List {
            ForEach(characters, id: \.self) { name in
                Section(header: Text(name.capitalized)) {
                    characterVoiceSection(for: name)
                    characterHighlightSection(for: name)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    

    // MARK: - Character Voice Section
    @ViewBuilder
    private func characterVoiceSection(for name: String) -> some View {
        let isCharacterSelected = selectedCharacters.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Voice")
                    .font(.headline)
                
                if isCharacterSelected {
                    Text("(You're playing this character)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            if isCharacterSelected {
                disabledVoiceInfo
            } else {
                activeVoiceControls(for: name)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Disabled Voice Info
    @ViewBuilder
    private var disabledVoiceInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Voice selection disabled")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Since you're playing this character, you'll be reading the lines yourself.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Active Voice Controls
    @ViewBuilder
    private func activeVoiceControls(for name: String) -> some View {
        VStack(spacing: 12) {
            genderPicker(for: name)
            specificVoicePicker(for: name)
            voicePreviewButton(for: name)
        }
    }

    // MARK: - Gender Picker
    @ViewBuilder
    private func genderPicker(for name: String) -> some View {
        Picker("Voice Gender", selection: Binding(
            get: { getSelectedVoiceGender(for: name) },
            set: { newGender in
                handleGenderChange(for: name, newGender: newGender)
            }
        )) {
            ForEach(VoiceGender.allCases) { gender in
                Text(gender.rawValue).tag(gender)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }

    // MARK: - Specific Voice Picker
    @ViewBuilder
    private func specificVoicePicker(for name: String) -> some View {
        Picker("Specific Voice", selection: Binding(
            get: { characterOptions[name]?.voiceID ?? "" },
            set: { newVoiceID in
                handleVoiceChange(for: name, newVoiceID: newVoiceID)
            }
        )) {
            let selectedGender = getSelectedVoiceGender(for: name)
            ForEach(getVoicesForGender(selectedGender), id: \.identifier) { voice in
                Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    // MARK: - Voice Preview Button
    @ViewBuilder
    private func voicePreviewButton(for name: String) -> some View {
        Button(action: {
            if let voiceID = characterOptions[name]?.voiceID {
                previewVoice(voiceID: voiceID)
            }
        }) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                Text("Preview Voice")
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Character Highlight Section
    @ViewBuilder
    private func characterHighlightSection(for name: String) -> some View {
        let isUserCharacter = selectedCharacters.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame })
        let isNotApplicable = selectedCharacters.contains("Just Listening")
        
        if isUserCharacter && !isNotApplicable {
            // User is playing this character and not "Just Listening" - allow color selection
            ColorPicker("Highlight Color", selection: Binding(
                get: { characterOptions[name]?.highlight.swiftUIColor ?? .yellow },
                set: { newColor in
                    // Check if the color is white, black, or gray and prevent it
                    if !isRestrictedColor(newColor) {
                        // First, temporarily set the color so the picker shows the selection
                        let previousColor = characterOptions[name]?.highlight.swiftUIColor ?? .yellow
                        characterOptions[name]?.highlight = SerializableColor(newColor)
                        
                        // Then check for duplicate colors among user's characters
                        let charactersUsingColor = findCharactersUsingColor(newColor, excluding: name)
                        
                        // Show warning if ANY other character is using this color
                        if !charactersUsingColor.isEmpty {
                            // Revert to previous color and show warning
                            characterOptions[name]?.highlight = SerializableColor(previousColor)
                            pendingColorSelection = (characterName: name, color: newColor)
                            showColorDuplicateWarning = true
                        }
                        // If no duplicates, the color stays applied
                    }
                    // If it's a restricted color, the picker will revert to the previous color
                }
            ), supportsOpacity: false)
        } else {
            // User is not playing this character or "Just Listening" is selected - show locked gray
            HStack {
                Text("Highlight Color")
                Spacer()
                Rectangle()
                    .fill(characterOptions[name]?.highlight.swiftUIColor ?? .gray)
                    .frame(width: 44, height: 30)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                Text("Locked")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Voice Change Handlers
    private func handleGenderChange(for name: String, newGender: VoiceGender) {
        let voicesForGender = getVoicesForGender(newGender)
        
        // Get currently used voice IDs to avoid duplicates
        let currentlyUsedVoiceIDs = getCurrentlyUsedVoiceIDs(excluding: name)
        
        // Find the first available voice in this gender that's not already used
        var selectedVoice: AVSpeechSynthesisVoice?
        
        for voice in voicesForGender {
            if !currentlyUsedVoiceIDs.contains(voice.identifier) {
                selectedVoice = voice
                break
            }
        }
        
        // If no unique voice found, use the first voice in the gender (allow duplicates as fallback)
        if selectedVoice == nil, let firstVoice = voicesForGender.first {
            selectedVoice = firstVoice
        }
        
        // Apply the selected voice
        if let voice = selectedVoice {
            let charactersUsingVoice = findCharactersUsingVoice(voice.identifier, excluding: name)
            
            if !charactersUsingVoice.isEmpty {
                pendingVoiceSelection = (characterName: name, voiceID: voice.identifier)
                showVoiceDuplicateWarning = true
            } else {
                characterOptions[name]?.voiceID = voice.identifier
            }
        }
    }

    private func handleVoiceChange(for name: String, newVoiceID: String) {
        let charactersUsingVoice = findCharactersUsingVoice(newVoiceID, excluding: name)
        
        if !charactersUsingVoice.isEmpty {
            pendingVoiceSelection = (characterName: name, voiceID: newVoiceID)
            showVoiceDuplicateWarning = true
        } else {
            characterOptions[name]?.voiceID = newVoiceID
            previewVoice(voiceID: newVoiceID)
        }
    }

    // MARK: - Voice Duplicate Alert Components
    @ViewBuilder
    private var voiceDuplicateAlertButtons: some View {
        Button("Cancel") {
            pendingVoiceSelection = nil
        }
        Button("Continue Anyway") {
            if let pending = pendingVoiceSelection {
                characterOptions[pending.characterName]?.voiceID = pending.voiceID
                previewVoice(voiceID: pending.voiceID)
            }
            pendingVoiceSelection = nil
        }
    }

    // Duplicate Voice Alert View
    @ViewBuilder
    private var voiceDuplicateAlertMessage: some View {
        if let pending = pendingVoiceSelection {
            let charactersUsingVoice = findCharactersUsingVoice(pending.voiceID, excluding: pending.characterName)
            
            if charactersUsingVoice.count == 1 {
                Text("This voice is already being used for \(charactersUsingVoice[0].capitalized). Do you want to use the same voice for both characters?")
            } else if charactersUsingVoice.count > 1 {
                let characterNames = charactersUsingVoice.map { $0.capitalized }
                let formattedNames = formatCharacterNames(characterNames)
                Text("This voice is already being used for \(formattedNames). Do you want to use the same voice for all these characters?")
            }
        }
    }
    
    // Duplicate Color Alert View
    @ViewBuilder
    private var colorDuplicateAlertMessage: some View {
        if let pending = pendingColorSelection {
            let charactersUsingColor = findCharactersUsingColor(pending.color, excluding: pending.characterName)
            
            if charactersUsingColor.count == 1 {
                Text("This color is already being used for \(charactersUsingColor[0].capitalized). Do you want to use the same color for both characters?")
            } else if charactersUsingColor.count > 1 {
                let characterNames = charactersUsingColor.map { $0.capitalized }
                let formattedNames = formatCharacterNames(characterNames)
                Text("This color is already being used for \(formattedNames). Do you want to use the same color for all these characters?")
            }
        }
    }
    
    @ViewBuilder
    private var colorDuplicateAlertButtons: some View {
        Button("Cancel") {
            pendingColorSelection = nil
        }
        Button("Continue Anyway") {
            if let pending = pendingColorSelection {
                characterOptions[pending.characterName]?.highlight = SerializableColor(pending.color)
            }
            pendingColorSelection = nil
        }
    }

    
    // MARK: - Character Customization View
    @ViewBuilder
    private var characterCustomizationView: some View {
        VStack {
            // Move the List and title into a single ScrollView structure
            List {
                // Custom title as the first section
                Section {
                    Text("Character Customization")
                        .font(.largeTitle)
                        .bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 10)
                        .padding(.bottom, 5)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                
                // Character sections
                ForEach(characters, id: \.self) { name in
                    Section(header: Text(name.capitalized)) {
                        characterVoiceSection(for: name)
                        characterHighlightSection(for: name)
                    }
                }
            }
            .listStyle(.insetGrouped)
            
            characterCustomizationButtonSection
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Add invisible title to enable navigation bar
            ToolbarItem(placement: .principal) {
                Text("")
                    .foregroundColor(.clear)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    pauseSpeechForNavigation()
                    stopVoicePreview()
                    isShowingCharacterCustomization = false
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        isLibraryOpen.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Main menu")
            }
        }
        .onAppear {
            print("🎨 === Character Customization View Appeared ===")
            print("🎨 Current characterOptions: \(characterOptions.mapValues { "color: \($0.highlight)" })")
            print("🎨 isLoadedScript: \(isLoadedScript)")
                
            ensureCharacterOptions()
            updateHighlightColors()
            
            print("🎨 After ensureCharacterOptions:")
            print("🎨 Updated characterOptions: \(characterOptions.mapValues { "color: \($0.highlight)" })")
            print("🎨 === End Debug ===")
        }
        .onDisappear {
            stopVoicePreview()
        }
        .alert("Voice Already In Use", isPresented: $showVoiceDuplicateWarning) {
            voiceDuplicateAlertButtons
        } message: {
            voiceDuplicateAlertMessage
        }
        .alert("Color Already In Use", isPresented: $showColorDuplicateWarning) {
            colorDuplicateAlertButtons
        } message: {
            colorDuplicateAlertMessage
        }
        .onAppear {
            // Restore saved character options if they exist
            if !savedCharacterOptions.isEmpty {
                characterOptions = savedCharacterOptions
                print("🎨 Restored character options: \(characterOptions.keys)")
            }
            ensureCharacterOptions()
            updateHighlightColors()
        }
    }
    
    // MARK: - Character Customization Button Section
    @ViewBuilder
    private var characterCustomizationButtonSection: some View {
        VStack {
            Button(action: {
                if isLoadedScript {
                    // For loaded scripts: set all states needed to reach script reading view
                    isShowingStartingLineSelection = true  // This needs to be true
                    isCharacterSelected = true             // This makes it go to script reading
                    print("📖 Loaded script: going directly back to script reading")
                } else {
                    // For new scripts: preserve starting line selection before going to starting line view
                    if selectedStartingLineIndex == nil && hasSetStartingLine {
                        selectedStartingLineIndex = startingLineIndex
                        print("📝 New script: preserved starting line selection: \(startingLineIndex)")
                    }
                    isShowingStartingLineSelection = true
                    print("📝 New script: going to starting line selection")
                }
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 10)
        }
    }
   
    // MARK: - Starting Line Selection View
    @ViewBuilder
    private var startingLineSelectionView: some View {
        VStack(spacing: 0) {
            // Script display with title inside the ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // Custom title and description at the top of scrollable content
                    VStack(spacing: 10) {
                        Text(isLoadedScript ? "Starting Line (Locked)" : "Select Starting Line")
                                .font(.largeTitle)
                                .bold()
                                .padding(.top, 20)
                        
                        Text(isLoadedScript ?
                                 "The starting line is locked for saved scripts. Your progress continues from where you left off." :
                                 "Please select the line you would like to start rehearsing from.")
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                    }
                    
                    // Script lines
                    ForEach(dialogue.indices, id: \.self) { index in
                        let entry = dialogue[index]
                        let isSelected = selectedStartingLineIndex == index
                        let isUserCharacter = selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame })
                        let characterColor = colorForCharacter(entry.character)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.character)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(entry.line)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(5)
                                .background(
                                    isSelected ?
                                    Color.green.opacity(0.7) :
                                    (isUserCharacter && !selectedCharacters.contains("Not Applicable") ?
                                     characterColor.opacity(0.3) :
                                     Color.clear)
                                )
                                .cornerRadius(5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 5)
                        .id(index)
                        .contentShape(Rectangle()) // Makes entire area tappable
                        .onTapGesture {
                            // Only allow selection if not a loaded script
                            if !isLoadedScript {
                                if selectedStartingLineIndex == index {
                                    // Tapping the same line again deselects it
                                    selectedStartingLineIndex = nil
                                } else {
                                    // Check if this is the last line
                                    if index == dialogue.count - 1 {
                                        // Show warning for last line
                                        showLastLineWarning = true
                                        selectedStartingLineIndex = index // Still select it, but show warning
                                    } else {
                                        // Select this line normally
                                        selectedStartingLineIndex = index
                                    }
                                }
                            }
                            // If isLoadedScript is true, tapping does nothing
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
            .background(Color(UIColor.systemBackground))
            
            // Continue button at bottom (stays fixed)
            VStack {
                Button(action: {
                    if isLoadedScript {
                        // For loaded scripts, keep the original progress, don't reset to starting line
                        // startingLineIndex stays the same, currentUtteranceIndex stays the same
                        // Don't change anything - just proceed
                        print("📖 Loaded script: keeping progress at \(currentUtteranceIndex), starting at \(startingLineIndex)")
                    } else {
                        // For new scripts, check if this is the initial setup or returning from navigation
                        if let startingIndex = selectedStartingLineIndex {
                            startingLineIndex = startingIndex
                            
                            // Only reset currentUtteranceIndex if this is the initial setup
                            // If currentUtteranceIndex is already ahead of startingLineIndex, preserve it
                            if currentUtteranceIndex < startingLineIndex {
                                currentUtteranceIndex = startingIndex
                                print("📝 New script: initial setup - set progress to starting line \(startingIndex)")
                            } else {
                                print("📝 New script: returning from navigation - keeping progress at \(currentUtteranceIndex)")
                            }
                            
                            hasSetStartingLine = true
                        }
                    }
                    isCharacterSelected = true
                }) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((isLoadedScript || selectedStartingLineIndex != nil) ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isLoadedScript && selectedStartingLineIndex == nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 10)
            }
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Add invisible title to enable navigation bar
            ToolbarItem(placement: .principal) {
                Text("")
                    .foregroundColor(.clear)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    selectedStartingLineIndex = nil
                    isShowingStartingLineSelection = false
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        isLibraryOpen.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Main menu")
            }
        }
        .alert("Last Line Selected", isPresented: $showLastLineWarning) {
            Button("Cancel") {
                selectedStartingLineIndex = nil // Deselect the last line
            }
            Button("Continue Anyway") {
                // Keep the selection, user confirmed they want to rehearse the last line
            }
        } message: {
            Text("Error: You have selected the very last line of the script. Are you sure you want to rehearse that?")
        }
        
        .onAppear {
            // Restore starting line selection if it was set
            if selectedStartingLineIndex == nil && hasSetStartingLine {
                selectedStartingLineIndex = startingLineIndex
                print("🎯 Restored starting line selection on appear: \(startingLineIndex)")
            } else {
                print("🔍 No restoration needed - selectedStartingLineIndex already set or hasSetStartingLine is false")
            }
        }
    }
    
    
    // MARK: - Script Reading View
    @ViewBuilder
    private var scriptReadingView: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(dialogue.indices, id: \.self) { index in
                            let entry = dialogue[index]
                            
                            // Only show lines from the starting point onwards
                            if index >= startingLineIndex {
                                if displayLinesAsRead {
                                    if index <= currentUtteranceIndex {
                                        lineView(for: entry, at: index)
                                    }
                                } else {
                                    lineView(for: entry, at: index)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)  // Ensure left alignment
                    .padding()
                    .onChange(of: currentUtteranceIndex) { _ in
                        withAnimation {
                            proxy.scrollTo(currentUtteranceIndex, anchor: .top)
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                .onAppear {
                    initializeSpeech()
                    startUsageTracking() // Start tracking usage time
                    
                    // Auto-save new scripts when they first reach the script reading view
                    if currentSavedScript == nil {
                        print("💾 Auto-saving new script: \(scriptName)")
                        saveCurrentScript()
                    } else {
                        print("📖 Continuing existing script: \(currentSavedScript?.title ?? "Unknown")")
                        
                        // Auto-scroll to current progress position with a small delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                proxy.scrollTo(currentUtteranceIndex, anchor: .center)
                            }
                            print("📍 Auto-scrolled to progress line: \(currentUtteranceIndex)")
                        }
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
            
            controlButtonsSection
        }
        .navigationTitle(scriptName.isEmpty ? "SceneAloud" : scriptName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Auto-pause speech when going back
                    pauseSpeechForNavigation()
                    
                    // Save current progress before going back
                    if currentSavedScript != nil {
                        saveCurrentScript()
                        print("💾 Saved progress before going back")
                    }
                    
                    if isLoadedScript {
                        // For loaded scripts: skip starting line selection, go directly to character customization
                        isCharacterSelected = false
                        isShowingStartingLineSelection = false
                        print("⬅️ Loaded script: going directly to character customization")
                    } else {
                        // For new scripts: normal flow through starting line selection
                        isCharacterSelected = false
                        isShowingStartingLineSelection = true
                        print("⬅️ New script: going to starting line selection")
                    }
                    
                    print("⬅️ Navigating back - isLoadedScript: \(isLoadedScript)")
                }) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        isLibraryOpen.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                }
                .accessibilityLabel("Main menu")
            }
        }
        .onDisappear {
            // Auto-pause when view disappears for any reason
            pauseSpeechForNavigation()
            stopUsageTracking() // Stop tracking when leaving script view
        }
        .overlay {
            if showRatingPrompt {
                customRatingView
            }
        }
    }

    
    private func pauseSpeechForNavigation() {
            if synthesizer.isSpeaking {
                synthesizer.pauseSpeaking(at: .immediate)
                isPaused = true
            }
        }

    // MARK: - Control Buttons Section
    @ViewBuilder
    private var controlButtonsSection: some View {
        VStack(spacing: 15) {
            // Main music player controls
            HStack(spacing: 30) {
                // Previous/Back button
                Button(action: {
                    skipBackOneLine()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                }
                .disabled(currentUtteranceIndex < startingLineIndex)
                
                // Play/Pause button - disabled when it's user's line
                Button(action: pauseOrResumeSpeech) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .foregroundColor(isUserLine ? .gray : .blue)
                        .frame(width: 44, height: 44)
                }
                .disabled(isUserLine)
                
                // Next/Forward button - highlighted when it's user's line
                Button(action: {
                    if isUserLine {
                        userLineFinished()
                    } else {
                        skipForwardOneLine()
                    }
                }) {
                    ZStack {
                        // Background circle when it's user's line
                        if isUserLine {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 44, height: 44)
                        }
                        
                        // Icon
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundColor(isUserLine ? .white : .blue)
                    }
                    .frame(width: 44, height: 44)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(15)
            .padding(.horizontal)
            
            // Bottom buttons section (Hint and/or Restart Line)
            if showHints {
                // Show both hint and restart line buttons when hints are enabled
                HStack(spacing: 20) {
                    // Hint Button - changes based on click count and line length
                    Button(action: {
                        guard currentUtteranceIndex < dialogue.count else { return }
                        let currentLine = dialogue[currentUtteranceIndex]
                        
                        if shouldShowFullLineButton(for: currentLine.line, clickCount: hintClickCount) {
                            handleRevealFullLinePressed()
                        } else {
                            handleHintButtonPressed()
                        }
                    }) {
                        HStack {
                            Image(systemName: "lightbulb")
                                .font(.body)
                            
                            // Button text logic: only change text for user lines with specific conditions
                            if currentUtteranceIndex < dialogue.count && isUserLine {
                                let currentLine = dialogue[currentUtteranceIndex]
                                let words = currentLine.line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                                
                                // Show "Reveal My Line" for short lines (5 words or fewer)
                                if words.count <= 5 {
                                    Text("Reveal My Line")
                                        .font(.body)
                                }
                                // Show "Reveal Full Line" only after 2 hints on longer lines
                                else if shouldShowFullLineButton(for: currentLine.line, clickCount: hintClickCount) {
                                    Text("Reveal Full Line")
                                        .font(.body)
                                }
                                // Default to "Hint" for all other cases
                                else {
                                    Text("Hint")
                                        .font(.body)
                                }
                            } else {
                                // Always show "Hint" when not on user line
                                Text("Hint")
                                    .font(.body)
                            }
                        }
                        .foregroundColor(getHintButtonColor())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(getHintButtonColor().opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(getHintButtonDisabled())
                    
                    // Restart Line Button
                    Button(action: {
                        restartCurrentLine()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.body)
                            Text("Restart Line")
                                .font(.body)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(isUserLine)
                }
            } else {
                // Show only restart line button (centered) when hints are disabled
                Button(action: {
                    restartCurrentLine()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .font(.body)
                        Text("Restart Line")
                            .font(.body)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isUserLine)
            }
        }
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var customRatingView: some View {
        ZStack {
            // Dark overlay background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Rating popup box
            VStack(spacing: 20) {
                // "Enjoying SceneAloud?" text
                Text("Enjoying SceneAloud?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // "Tap a star to rate it on the App Store" text
                Text("Tap a star to rate it on the\nApp Store.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                // Five interactive stars
                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { index in
                        Button(action: {
                            handleStarTap(index)
                        }) {
                            Image(systemName: index <= selectedStarRating ? "star.fill" : "star")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 10)

                // Bottom buttons area
                if hasTappedStars {
                    // Always show Cancel and Submit once user has tapped stars
                    HStack {
                        Button("Cancel") {
                            selectedStarRating = 0
                            hasTappedStars = false  // Reset for next time - this ensures next popup starts with "Not Now"
                            showRatingPrompt = false
                            startUsageTracking()  // Start timer for next 20 seconds
                        }
                        .font(.body)
                        .foregroundColor(.blue)

                        Spacer()

                        Button("Submit") {
                            openAppStoreRating()
                            markRatingPrompted()
                            showRatingPrompt = false
                            selectedStarRating = 0  // Reset for next time
                            hasTappedStars = false  // Reset for next time
                        }
                        .font(.body)
                        .foregroundColor(.blue)
                    }
                } else {
                    // Show "Not Now" only when user hasn't tapped stars yet
                    Button("Not Now") {
                        print("⭐ User selected 'Not Now' - restarting timer")
                        showRatingPrompt = false
                        startUsageTracking()
                    }
                    .font(.body)
                    .foregroundColor(.blue)
               }
           }
            .padding(30)
            .background(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6))
            .cornerRadius(20)
            .shadow(radius: 10)
           .frame(maxWidth: 300)
       }
    }

    // MARK: - Alert Helper
    private func alertForType(_ alert: AlertType) -> Alert {
        switch alert {
        case .hintsInfo:
            return Alert(
                title: Text("Hints"),
                message: Text("When turned on, 'Hints' allows you to ask for the first few words of your line to be revealed if you are having trouble remembering it."),
                dismissButton: .default(Text("OK")) {
                    activeAlert = nil
                }
            )
        case .scriptFormatError:
            return Alert(
                title: Text("Script Format Error"),
                message: Text("Your script could not be processed. Please make sure each line follows the format:\n\nCharacter Name: Line of dialogue\n\nFor example:\nJOHN: Hello there!\nMARY: How are you?"),
                dismissButton: .default(Text("OK")) {
                    // For uploaded files, reset to upload page
                    if hasUploadedFile && !uploadedFileName.contains("Typed Script") {
                        uploadedFileName = ""
                        fileContent = ""
                        selectedFileURL = nil
                        dialogue = []
                        characters = []
                        selectedCharacters = []
                        hasUploadedFile = false
                        hasPressedContinue = false
                    }
                    // For typed scripts, preserve fileContent and stay on typing page
                    if !hasUploadedFile || uploadedFileName.contains("Typed Script") {
                        // Don't clear fileContent - just reset the upload flags
                        uploadedFileName = ""
                        dialogue = []
                        characters = []
                        selectedCharacters = []
                        hasUploadedFile = false
                        hasPressedContinue = false
                    }
                    activeAlert = nil
                }
            )
            
        case .noCharacterSelected:
            return Alert(
                title: Text("No Character Selected"),
                message: Text("Please select at least one character to continue."),
                dismissButton: .default(Text("OK")) {
                    activeAlert = nil
                }
            )
        case .displayLinesAsReadInfo:
            return Alert(
                title: Text("Display Lines As Read Info"),
                message: Text("The 'Display Lines As Read' option shows all of the script when turned off. When turned on lines will only appear as they are read, making it easier to follow."),
                dismissButton: .default(Text("OK")) {
                    activeAlert = nil
                }
            )
        case .notApplicableInfo:
            return Alert(
                title: Text("Just Listening"),
                message: Text("When 'Just Listening' is selected, you will just be listening to the script and will not be participating."),
                dismissButton: .default(Text("OK")) {
                    activeAlert = nil
                }
            )
        case .displayMyLinesInfo:
            return Alert(
                title: Text("Display My Lines"),
                message: Text("When selected, 'Display My Lines' will display the lines of the character the user has selected to play. When it is not selected, the user will be prompted when it is their line, but they will not be shown it."),
                dismissButton: .default(Text("OK")) {
                    activeAlert = nil
                }
            )
        case .emptyScriptName:
            return Alert(
                title: Text("Script Name Required"),
                message: Text("Please enter a name for your script before continuing."),
                dismissButton: .default(Text("OK")) {
                    activeAlert = nil
                }
            )
        case .emptyScriptNameAndNoCharacter: // NEW
            return Alert(
                title: Text("Missing Information"),
                message: Text("Please enter a script name and select at least one character before continuing."),
                dismissButton: .default(Text("OK")) {
                    activeAlert = nil
                }
            )
        case .lastLineWarning: // NEW
            return Alert(
                title: Text("Last Line Selected"),
                message: Text("Error: You have selected the very last line of the script. Are you sure you want to rehearse that?"),
                primaryButton: .default(Text("Cancel")) {
                    selectedStartingLineIndex = nil
                    activeAlert = nil
                },
                secondaryButton: .default(Text("Continue Anyway")) {
                    activeAlert = nil
                }
            )
        }
    }

    // MARK: - Line View
        @ViewBuilder
        private func lineView(for entry: (character: String, line: String), at index: Int) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.character)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if selectedCharacters.contains("Just Listening") {
                    // When "Just Listening" is selected, check THIS character's color individually
                    let characterColor = colorForCharacter(entry.character)
                    let isThisCharacterGray = isColorGray(characterColor)
                    
                    Text(entry.line)
                        .font(.body)
                        .padding(5)
                        .background(
                            isThisCharacterGray ?
                            // If THIS character has gray color, only highlight current line
                            (index == currentUtteranceIndex ?
                             characterColor.opacity(0.7) :
                             Color.clear
                            ) :
                            // If THIS character has custom color, show persistently
                            (index == currentUtteranceIndex ?
                             characterColor.opacity(0.7) :
                             characterColor.opacity(0.2)
                            )
                        )
                        .cornerRadius(5)
                } else if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
                    // This is a user-selected character - always show background, bright when current
                    if displayMyLines {
                        Text(entry.line)
                            .font(.body)
                            .padding(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                index == currentUtteranceIndex ?
                                colorForCharacter(entry.character).opacity(0.7) :
                                colorForCharacter(entry.character).opacity(0.2)
                            )
                            .cornerRadius(5)
                    } else {
                        // Check if this line has already passed (user has moved beyond it)
                        if index < currentUtteranceIndex {
                            // Show the actual line text for passed lines
                            Text(entry.line)
                                .font(.body)
                                .padding(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colorForCharacter(entry.character).opacity(0.2))
                                .cornerRadius(5)
                        }
                        // Check if this is the current line and we have hint text to show
                        else if index == currentUtteranceIndex && showHints && !revealedWords.isEmpty {
                            // Show hint text
                            let hintText = revealedWords.joined(separator: " ")
                            let isFullReveal = hintClickCount >= 999 // Check if full line was revealed
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isFullReveal ? entry.line : (hintText + (hintText == entry.line ? "" : "...")))
                                    .font(.body)
                                    .foregroundColor(isFullReveal ? .primary : .secondary)
                                    .padding(5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(colorForCharacter(entry.character).opacity(0.7))
                                    .cornerRadius(5)
                                
                                if !isFullReveal {
                                    Text("Hint: Tap hint button for more")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        } else if index == currentUtteranceIndex {
                            // Current line - show "It's your line" message
                            Text("It's your line! Press to continue.")
                                .font(.body)
                                .padding(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colorForCharacter(entry.character).opacity(0.7))
                                .cornerRadius(5)
                        }
                        // For future lines (index > currentUtteranceIndex), show nothing when displayMyLines is off
                    }
                } else {
                    // This is a non-selected character - check if THIS character has gray or custom color
                    let characterColor = colorForCharacter(entry.character)
                    let isThisCharacterGray = isColorGray(characterColor)
                    
                    Text(entry.line)
                        .font(.body)
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            index == currentUtteranceIndex ?
                            characterColor.opacity(0.7) :
                            (isThisCharacterGray ? Color.clear : characterColor.opacity(0.2))
                        )
                        .cornerRadius(5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 5)
            .id(index)
        }
    
    // MARK: - Voice Preview Functionality
    @State private var previewSynthesizer = AVSpeechSynthesizer()

    private func previewVoice(voiceID: String) {
        // Stop any currently playing preview
        stopVoicePreview()
        
        // Create utterance with "Hello"
        let utterance = AVSpeechUtterance(string: "Hello")
        
        // Set the voice
        if let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        }
        
        // Configure for quick preview
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 0.8
        utterance.pitchMultiplier = 1.0
        
        // Speak the preview
        previewSynthesizer.speak(utterance)
    }

    private func stopVoicePreview() {
        if previewSynthesizer.isSpeaking {
            previewSynthesizer.stopSpeaking(at: .immediate)
        }
    }
    // MARK: - Helper function to get currently used voice IDs
    private func getCurrentlyUsedVoiceIDs(excluding excludeName: String) -> Set<String> {
        var usedIDs: Set<String> = []
        for (name, options) in characterOptions {
            if name != excludeName {
                usedIDs.insert(options.voiceID)
            }
        }
        return usedIDs
    }
    
    // MARK: - Voice Management System
    private func assignUniqueVoices() {
        // Get all available male voices as default
        let maleVoices = getVoicesForGender(.male)
        
        var voiceIndex = 0
        
        // Assign voices to characters that don't have them yet
        for name in characters {
            if let currentVoiceID = characterOptions[name]?.voiceID,
               !currentVoiceID.isEmpty,
               AVSpeechSynthesisVoice(identifier: currentVoiceID) != nil {
                // Character already has a valid voice, keep it
                continue
            } else {
                // Character needs a new voice - assign next available male voice
                if voiceIndex < maleVoices.count {
                    characterOptions[name]?.voiceID = maleVoices[voiceIndex].identifier
                    voiceIndex += 1
                } else {
                    // Fallback if we run out of male voices
                    let fallbackVoice = getDefaultVoiceID()
                    characterOptions[name]?.voiceID = fallbackVoice
                }
            }
        }
    }

    private func reassignVoiceIfDuplicate(newVoiceID: String, forCharacter characterName: String) {
        // Check if any other character is using this voice
        for (otherName, options) in characterOptions {
            if otherName != characterName && options.voiceID == newVoiceID {
                // Found a duplicate! Assign a new voice to the other character
                assignNewUniqueVoice(to: otherName, avoiding: [newVoiceID])
                break
            }
        }
    }

    private func assignNewUniqueVoice(to characterName: String, avoiding avoidVoiceIDs: [String]) {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Get all currently used voice IDs
        var usedVoiceIDs = Set(avoidVoiceIDs)
        for (otherName, options) in characterOptions {
            if otherName != characterName {
                usedVoiceIDs.insert(options.voiceID)
            }
        }
        
        // Find first available voice
        for voice in allVoices {
            if !usedVoiceIDs.contains(voice.identifier) {
                characterOptions[characterName]?.voiceID = voice.identifier
                return
            }
        }
        
        // If no unique voice found (shouldn't happen), use default
        characterOptions[characterName]?.voiceID = getDefaultVoiceID()
    }
    
    // MARK: - Centralized Voice Lists
    private var maleVoiceKeys: [String] {
        return [
            "rocko en-gb", "daniel en-gb", "arthur en-gb", "aaron en-us",
            "daniel fr-fr", "reed en-gb", "fred en-us", "reed en-us",
            "reed fi-fi", "reed fr-ca", "gordon en-au", "eddy en-gb",
            "rishi en-in", "eddy en-us", "ralph en-us", "grandpa fi-fi",
            "eddy fi-fi", "eddy fr-ca", "hattori ja-jp", "xander nl-nl",
            "li-mu zh-cn", "eddy zh-tw"
        ]
    }

    private var femaleVoiceKeys: [String] {
        return [
            "samantha en-us", "karen en-au", "anna de-de", "paulina es-mx",
            "marie fr-fr", "luciana pt-br", "joana pt-pt", "helena de-de",
            "daria bg-bg", "melina el-gr", "catherine en-au", "martha en-gb",
            "grandma fi-fi", "shelley fi-fi", "amélie fr-ca", "flo fr-fr",
            "damayanti id-id", "kyoko ja-jp", "o-ren ja-jp", "ellen nl-be",
            "shelley pt-br", "alva sv-se", "kanya th-th", "meijia zh-tw",
            "nicky en-us"
        ]
    }

    private var otherVoiceKeys: [String] {
        return [
            "bahh en-us", "jester en-us", "organ en-us", "cellos en-us",
            "zarvox en-us", "whisper en-us", "good news en-us", "bad news en-us",
            "bubbles en-us", "superstar en-us", "bells en-us", "trinoids en-us",
            "boing en-us", "wobble en-us"
        ]
    }


    // MARK: - Voice Helper Functions
    private func formatCharacterNames(_ names: [String]) -> String {
        if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        } else {
            let allButLast = names.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(names.last!)"
        }
    }

    // Find ALL characters using a specific voice
    private func findCharactersUsingVoice(_ voiceID: String, excluding excludeName: String) -> [String] {
        var charactersUsingVoice: [String] = []
        for (characterName, options) in characterOptions {
            if characterName != excludeName && options.voiceID == voiceID {
                charactersUsingVoice.append(characterName)
            }
        }
        return charactersUsingVoice
    }
    
    private func findCharacterUsingVoice(_ voiceID: String, excluding excludeName: String) -> String? {
        for (characterName, options) in characterOptions {
            if characterName != excludeName && options.voiceID == voiceID {
                return characterName
            }
        }
        return nil
    }
    
    private func getDefaultVoiceID() -> String {
        // Try to get one of our curated voices as default, preferably English
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Preferred default voices in order of preference
        let preferredDefaults = [
            "samantha en-us", "karen en-au", "aaron en-us", "daniel en-gb"
        ]
        
        for preferredVoice in preferredDefaults {
            if let voice = allVoices.first(where: { voice in
                let voiceKey = "\(voice.name.lowercased()) \(voice.language.lowercased())"
                return voiceKey == preferredVoice
            }) {
                return voice.identifier
            }
        }
        
        // Fallback to any curated voice
        let curatedVoices = getVoicesForGender(.female) + getVoicesForGender(.male) + getVoicesForGender(.other)
        if let firstCurated = curatedVoices.first {
            return firstCurated.identifier
        }
        
        // Last resort - system default
        if let systemDefault = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode()) {
            return systemDefault.identifier
        }
        
        // Absolute fallback
        if let firstVoice = allVoices.first {
            return firstVoice.identifier
        }
        
        return ""
    }
    
    private func getSelectedVoiceGender(for characterName: String) -> VoiceGender {
        guard let voiceID = characterOptions[characterName]?.voiceID,
              !voiceID.isEmpty,
              let voice = AVSpeechSynthesisVoice(identifier: voiceID) else {
            return .female // Default to female if no voice selected
        }
        
        let voiceKey = "\(voice.name.lowercased()) \(voice.language.lowercased())"
        
        // Check which curated list contains this voice
        if maleVoiceKeys.contains(voiceKey) {
            return .male
        } else if femaleVoiceKeys.contains(voiceKey) {
            return .female
        } else if otherVoiceKeys.contains(voiceKey) {
            return .other
        }
        
        // Default to female if voice not found in curated lists
        return .female
    }
    

    private func getVoicesForGender(_ gender: VoiceGender) -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Get the appropriate voice list based on gender
        var targetVoiceKeys: [String] = []
        switch gender {
        case .male:
            targetVoiceKeys = maleVoiceKeys
        case .female:
            targetVoiceKeys = femaleVoiceKeys
        case .other:
            targetVoiceKeys = otherVoiceKeys
        }
        
        // Find matching voices from available system voices
        var filteredVoices: [AVSpeechSynthesisVoice] = []
        
        for voiceKey in targetVoiceKeys {
            if let matchingVoice = allVoices.first(where: { voice in
                let systemVoiceKey = "\(voice.name.lowercased()) \(voice.language.lowercased())"
                return systemVoiceKey == voiceKey
            }) {
                filteredVoices.append(matchingVoice)
            }
        }
        
        return filteredVoices
    }
    

    // Helper function to get voice name for display
    private func getVoiceDisplayName(for characterName: String) -> String {
        guard let voiceID = characterOptions[characterName]?.voiceID,
              !voiceID.isEmpty,
              let voice = AVSpeechSynthesisVoice(identifier: voiceID) else {
            return "No voice selected"
        }
        
        return "\(voice.name) (\(voice.language))"
    }
    // MARK: - Highlight Helper functions
    
    // Helper function to find characters using the same color
    private func findCharactersUsingColor(_ color: Color, excluding excludeName: String) -> [String] {
        var charactersUsingColor: [String] = []
        
        // Only check among characters the user is playing (excluding "Just Listening")
        let userCharacters = selectedCharacters.filter { $0 != "Just Listening" }
        
        for characterName in userCharacters {
            if characterName != excludeName,
               let characterColor = characterOptions[characterName]?.highlight.swiftUIColor,
               colorsAreEqual(color, characterColor) {
                charactersUsingColor.append(characterName)
            }
        }
        
        return charactersUsingColor
    }
    
    // Helper function to check for restricted colors
    private func isRestrictedColor(_ color: Color) -> Bool {
        let uiColor = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Check for white (high values for all RGB)
        if red > 0.85 && green > 0.85 && blue > 0.85 {
            return true
        }
        
        // Check for black (low values for all RGB)
        if red < 0.15 && green < 0.15 && blue < 0.15 {
            return true
        }
        
        // Check for gray (similar values for RGB) - more restrictive detection
        let maxDiff = max(abs(red - green), abs(green - blue), abs(red - blue))
        if maxDiff < 0.05 {  // Very similar RGB values = gray
            return true
        }
        
        // Additional check for low saturation colors (which appear grayish)
        let maxRGB = max(red, green, blue)
        let minRGB = min(red, green, blue)
        let saturation = maxRGB == 0 ? 0 : (maxRGB - minRGB) / maxRGB
        
        if saturation < 0.2 {  // Low saturation = grayish
            return true
        }
        
        return false
    }
        
    private func isColorGray(_ color: Color) -> Bool {
            let defaultDarkGray = Color.gray.opacity(0.3)
            let defaultLightGray = Color.gray.opacity(0.15)
            
            return colorsAreEqual(color, defaultDarkGray) || colorsAreEqual(color, defaultLightGray)
        }
    
    
    // Helper function to check if user has customized any colors
        private func hasUserCustomizedAnyColors() -> Bool {
            // Check if any character has a color different from the default gray colors
            for (_, options) in characterOptions {
                let characterColor = options.highlight.swiftUIColor
                
                // Check if the color is different from default gray colors
                let defaultDarkGray = Color.gray.opacity(0.3)
                let defaultLightGray = Color.gray.opacity(0.15)
                
                // If the color is not one of the default grays, user has customized
                if !colorsAreEqual(characterColor, defaultDarkGray) &&
                   !colorsAreEqual(characterColor, defaultLightGray) {
                    return true
                }
            }
            return false
        }

        // Helper function to compare colors
        private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
            // Convert colors to UIColor for comparison
            let uiColor1 = UIColor(color1)
            let uiColor2 = UIColor(color2)
            
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            
            uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            // Compare with small tolerance for floating point precision
            let tolerance: CGFloat = 0.01
            return abs(r1 - r2) < tolerance &&
                   abs(g1 - g2) < tolerance &&
                   abs(b1 - b2) < tolerance &&
                   abs(a1 - a2) < tolerance
        }
    
    /// Makes sure every character has a default entry in `characterOptions`
    private func ensureCharacterOptions() {
        print("🔧 === ensureCharacterOptions() START ===")
        print("🔧 Current characterOptions before: \(characterOptions.keys)")
        
        // Determine the appropriate gray color based on color scheme
        let defaultGrayColor: Color
        if colorScheme == .dark {
            // Dark mode: use darker gray
            defaultGrayColor = Color.gray.opacity(0.3)
        } else {
            // Light mode: use lighter gray
            defaultGrayColor = Color.gray.opacity(0.15)
        }
        
        print("🔧 Default gray color: \(defaultGrayColor)")
        print("🔧 Characters list: \(characters)")
        
        // Create basic options for characters that don't have them yet
        for name in characters where characterOptions[name] == nil {
            characterOptions[name] = CharacterOptions(
                voiceID: "", // Will be assigned in assignUniqueVoices
                highlight: SerializableColor(defaultGrayColor)
            )
            print("🔧 Created default options for: \(name)")
        }
        
        // Assign unique voices to all characters
        assignUniqueVoices()
        
        // Create a safer way to print the character options
        var characterOptionsSummary: [String: String] = [:]
        for (key, value) in characterOptions {
            characterOptionsSummary[key] = "voice: \(value.voiceID.prefix(10))..., color: \(value.highlight.r),\(value.highlight.g),\(value.highlight.b)"
        }
        print("🔧 Final characterOptions after: \(characterOptionsSummary)")
        print("🔧 === ensureCharacterOptions() END ===")
    }

    // MARK: - Update highlight colors when selection changes
    private func updateHighlightColors() {
        print("🌈 === updateHighlightColors() START ===")
        print("🌈 selectedCharacters: \(selectedCharacters)")
        print("🌈 isLoadedScript: \(isLoadedScript)")
        
        // Check if user has already customized colors - if so, DON'T override them
        // BUT exclude restricted colors (white/black/gray) from being considered "custom"
        let hasCustomColors = characterOptions.values.contains { option in
            let color = option.highlight.swiftUIColor
            let defaultDarkGray = Color.gray.opacity(0.3)
            let defaultLightGray = Color.gray.opacity(0.15)
            
            // Check if it's not a default gray AND not a restricted color
            let isNotDefaultGray = !colorsAreEqual(color, defaultDarkGray) && !colorsAreEqual(color, defaultLightGray)
            let isNotRestrictedColor = !isRestrictedColor(color)
            
            return isNotDefaultGray && isNotRestrictedColor
        }
        
        print("🌈 hasCustomColors: \(hasCustomColors)")
        
        if hasCustomColors {
            print("🌈 Valid custom colors detected - preserving existing colors, not applying defaults")
            return // Don't override custom colors
        }
        
        // Only apply default color scheme if no valid custom colors exist
        print("🌈 No valid custom colors - applying default color scheme")
        
        // Rest of the original logic for default colors...
        let allColors: [Color] = [
            Color.red, Color.blue, Color.green, Color.yellow, Color.purple, Color.orange,
            Color.pink, Color.cyan, Color.brown,
            Color(red: 1.0, green: 0.0, blue: 1.0),     // Magenta
            Color(red: 0.5, green: 0.0, blue: 0.5),     // Dark purple
            Color(red: 0.0, green: 0.5, blue: 0.0),     // Dark green
            Color(red: 0.5, green: 0.5, blue: 0.0),     // Olive
            Color(red: 0.0, green: 0.5, blue: 0.5),     // Teal
            Color(red: 0.5, green: 0.0, blue: 0.0),     // Dark red
            Color(red: 0.0, green: 0.0, blue: 0.5),     // Navy blue
            Color(red: 1.0, green: 0.5, blue: 0.0),     // Orange-red
            Color(red: 0.5, green: 1.0, blue: 0.0),     // Lime green
            Color(red: 0.0, green: 1.0, blue: 0.5),     // Spring green
            Color(red: 0.5, green: 0.0, blue: 1.0),     // Blue-violet
            Color(red: 1.0, green: 0.0, blue: 0.5),     // Rose
            Color(red: 0.0, green: 0.5, blue: 1.0)      // Sky blue
        ]
        
        let selectedCharactersList = characters.filter { character in
            selectedCharacters.contains(where: { $0.caseInsensitiveCompare(character) == .orderedSame })
        }
        
        let nonSelectedGrayColor: Color
        if colorScheme == .dark {
            nonSelectedGrayColor = Color.gray.opacity(0.3)
        } else {
            nonSelectedGrayColor = Color.gray.opacity(0.15)
        }
        
        // Set all characters to gray first
        for name in characters {
            if characterOptions[name] == nil {
                characterOptions[name] = CharacterOptions(
                    voiceID: AVSpeechSynthesisVoice.currentLanguageCode(),
                    highlight: SerializableColor(nonSelectedGrayColor)
                )
            } else {
                characterOptions[name]?.highlight = SerializableColor(nonSelectedGrayColor)
            }
        }
        
        // Then assign unique colors to selected characters only
        for (index, name) in selectedCharactersList.enumerated() {
            let colorIndex = index % allColors.count
            characterOptions[name]?.highlight = SerializableColor(allColors[colorIndex])
        }
        
        print("🌈 Applied default colors to selected characters")
        print("🌈 === updateHighlightColors() END ===")
    }
    
    // MARK: - Splash Screen Helper Functions
    
    private func getVideoURLsForColorScheme() -> (first: URL, second: URL)? {
        if colorScheme == .dark {
            // Dark mode videos
            guard let firstURL = Bundle.main.url(forResource: "SceneAloudLogo_Anim1", withExtension: "mp4"),
                  let secondURL = Bundle.main.url(forResource: "SceneAloudLogo_Anim2", withExtension: "mp4") else {
                print("❌ Dark mode videos not found")
                return nil
            }
            return (first: firstURL, second: secondURL)
        } else {
            // Light mode videos
            guard let firstURL = Bundle.main.url(forResource: "Sequence 10", withExtension: "mp4"),
                  let secondURL = Bundle.main.url(forResource: "Sequence 10_1", withExtension: "mp4") else {
                print("❌ Light mode videos not found")
                return nil
            }
            return (first: firstURL, second: secondURL)
        }
    }
    
    private func setupFirstVideo(firstVideoURL: URL, secondVideoURL: URL) {
        self.firstVideoURL = firstVideoURL
        self.secondVideoURL = secondVideoURL
        
        let playerItem = AVPlayerItem(url: firstVideoURL)
        splashPlayer.replaceCurrentItem(with: playerItem)
        splashPlayer.actionAtItemEnd = .pause
        
        // Set up first video completion detection
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            // First video finished - show tap prompt
            print("🎬 First video finished")
            withAnimation {
                self.showTapToContinue = true
                self.hasPlayedFirstVideo = true
            }
        }
        
        splashPlayer.play()
        print("🎬 Started playing first video")
    }

    private func handleSplashTap() {
        print("🖱️ Splash tap detected - hasPlayedFirstVideo: \(hasPlayedFirstVideo), isPlayingSecondVideo: \(isPlayingSecondVideo)")
        
        if hasPlayedFirstVideo && !isPlayingSecondVideo {
            // First video has finished and user tapped - play second video
            print("🎬 Playing second video")
            playSecondVideo()
        } else if isPlayingSecondVideo {
            // Second video is playing - ignore taps to prevent interruption
            print("🎬 Second video playing - ignoring tap")
            return
        } else {
            // First video hasn't finished yet - ignore tap
            print("🎬 First video still playing - ignoring tap")
            return
        }
    }

    private func playSecondVideo() {
        guard let secondVideoURL = secondVideoURL else {
            print("❌ Second video URL not found")
            return
        }
        
        print("🎬 Setting up second video: \(secondVideoURL.lastPathComponent)")
        isPlayingSecondVideo = true
        
        // Hide tap prompt with animation
        withAnimation {
            showTapToContinue = false
        }
        
        // Remove old observers to prevent conflicts
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        // Set up second video
        let secondPlayerItem = AVPlayerItem(url: secondVideoURL)
        splashPlayer.replaceCurrentItem(with: secondPlayerItem)
        splashPlayer.actionAtItemEnd = .pause
        
        // Set up second video completion detection
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: secondPlayerItem,
            queue: .main
        ) { _ in
            // Second video finished - go to homepage
            print("🎬 Second video finished - transitioning to homepage")
            self.transitionToHomepage()
        }
        
        // Start playing second video
        splashPlayer.play()
        print("🎬 Second video started playing")
    }

    private func transitionToHomepage() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isShowingSplash = false
            isShowingHomepage = true
        }
    }

    private func cleanupVideoPlayer() {
        splashPlayer.pause()
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        // Reset video states
        hasPlayedFirstVideo = false
        isPlayingSecondVideo = false
        showTapToContinue = false
    }
    
    // MARK: - Skip Navigation Functions
    private func skipBackOneLine() {
        print("🔄 Skip back pressed - Current index: \(currentUtteranceIndex), isPaused: \(isPaused)")
        print("🔄 Starting line index: \(startingLineIndex)")
        print("🔄 Button should be disabled if: \(currentUtteranceIndex <= startingLineIndex) = \(currentUtteranceIndex <= startingLineIndex)")
        
        if isPaused {
            skipBackWhilePaused()
        } else {
            skipBackWhileUnpaused()
        }
    }

    private func skipForwardOneLine() {
        print("🔄 Skip forward pressed - Current index: \(currentUtteranceIndex), isPaused: \(isPaused)")
        
        if isPaused {
            skipForwardWhilePaused()
        } else {
            skipForwardWhileUnpaused()
        }
    }
    
    // MARK: - Paused Skip Functions
    private func skipBackWhilePaused() {
        print("⏸️ Skipping back while paused - currentIndex: \(currentUtteranceIndex), startingIndex: \(startingLineIndex)")
        
        // DON'T stop speech here - we want to be able to resume
        // Just clear delegates to prevent old ones from firing
        synthesizer.delegate = nil
        speechDelegate = nil
        print("⏸️ Cleared delegates but kept speech paused")
        
        // Move index back OR stay at current if at beginning
        if currentUtteranceIndex > startingLineIndex {
            currentUtteranceIndex -= 1
            resetHintForNewLine()
            print("⏸️ Moved back to index: \(currentUtteranceIndex)")
        } else {
            print("⏸️ At starting line (\(startingLineIndex)), staying at current line ready to restart at index: \(currentUtteranceIndex)")
            resetHintForNewLine()
        }
        
        // Update states
        updateProgress()
        updateUserLineState()
        
        // Stay paused - but we need to prepare for the case where user hits unpause
        // The synthesizer should be stopped and ready to start the new line
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("⏸️ Stopped current speech to prepare for new line")
        }
        
        isPaused = true
        isSpeaking = false
        
        print("⏸️ Paused skip back complete - index: \(currentUtteranceIndex), isPaused: \(isPaused)")
    }

    private func skipForwardWhilePaused() {
        print("⏸️ Skipping forward while paused")
        
        // Stop any speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.delegate = nil
        speechDelegate = nil
        
        // Move index forward
        currentUtteranceIndex += 1
        resetHintForNewLine()
        print("➡️ Moved forward to index: \(currentUtteranceIndex)")
        
        // Check end of script
        if currentUtteranceIndex >= dialogue.count {
            print("📜 Reached end of script")
            showScriptCompletionAlert = true
            return
        }
        
        // Update states
        updateProgress()
        updateUserLineState()
        
        // Stay paused
        isPaused = true
        isSpeaking = false
        
        print("✅ Paused skip forward complete - index: \(currentUtteranceIndex), isPaused: \(isPaused)")
    }

    // MARK: - Unpaused Skip Functions
    private func skipBackWhileUnpaused() {
        print("▶️ Skipping back while unpaused - currentIndex: \(currentUtteranceIndex), startingIndex: \(startingLineIndex)")
        
        // Stop current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("🛑 Stopped speaking")
        }
        synthesizer.delegate = nil
        speechDelegate = nil
        
        // Move index back OR restart current line if at beginning
        if currentUtteranceIndex > startingLineIndex {
            currentUtteranceIndex -= 1
            resetHintForNewLine()
            print("⬅️ Moved back to index: \(currentUtteranceIndex)")
        } else {
            print("🔄 Already at starting line (\(startingLineIndex)), will restart current line at index: \(currentUtteranceIndex)")
            resetHintForNewLine()
        }
        
        // Update states
        updateProgress()
        updateUserLineState()
        
        // Start speaking immediately if not user line
        isPaused = false
        isSpeaking = false
        
        if !isUserLine {
            print("🎬 About to call speakLineForUnpausedSkip() for index: \(currentUtteranceIndex)")
            speakLineForUnpausedSkip()
            print("🎬 Called speakLineForUnpausedSkip()")
        } else {
            print("👤 Line is user's line - waiting for user")
        }
        
        print("✅ Unpaused skip back complete - index: \(currentUtteranceIndex), speaking: \(!isUserLine)")
    }
    
    private func skipForwardWhileUnpaused() {
        print("➡️ === skipForwardWhileUnpaused() ENTRY ===")
        print("➡️ currentUtteranceIndex: \(currentUtteranceIndex)")
        print("➡️ synthesizer.isSpeaking: \(synthesizer.isSpeaking)")
        
        // Stop current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("➡️ Stopped speaking")
        }
        synthesizer.delegate = nil
        speechDelegate = nil
        print("➡️ Cleared delegates")
        
        // Move index forward
        print("➡️ Moving forward from \(currentUtteranceIndex) to \(currentUtteranceIndex + 1)")
        currentUtteranceIndex += 1
        resetHintForNewLine()
        print("➡️ Moved forward to index: \(currentUtteranceIndex)")
        
        // Check end of script
        if currentUtteranceIndex >= dialogue.count {
            print("➡️ Reached end of script")
            showScriptCompletionAlert = true
            return
        }
        
        // Update states
        print("➡️ About to call updateProgress()")
        updateProgress()
        print("➡️ About to call updateUserLineState()")
        updateUserLineState()
        print("➡️ After updateUserLineState(), isUserLine: \(isUserLine)")
        
        // Start speaking immediately if not user line
        isPaused = false
        isSpeaking = false
        print("➡️ Set isPaused = false, isSpeaking = false")
        
        if !isUserLine {
            print("➡️ Not user line - about to call speakLineForUnpausedSkip()")
            speakLineForUnpausedSkip()
            print("➡️ Called speakLineForUnpausedSkip()")
        }
        
        print("➡️ === skipForwardWhileUnpaused() EXIT ===")
        print("➡️ Final state - index: \(currentUtteranceIndex), isUserLine: \(isUserLine), isPaused: \(isPaused)")
    }
    
    // Special speech function ONLY for unpaused skips
    private func speakLineForUnpausedSkip() {
        guard currentUtteranceIndex < dialogue.count else {
            showScriptCompletionAlert = true
            return
        }

        let entry = dialogue[currentUtteranceIndex]
        print("🎭 Speaking after unpaused skip - character: \(entry.character), index: \(currentUtteranceIndex)")
        
        // Force UI update BEFORE starting speech with a longer delay
        DispatchQueue.main.async {
            // This forces SwiftUI to update the view with the new currentUtteranceIndex
            print("🔄 Forcing UI update for index: \(self.currentUtteranceIndex)")
            
            // Then start speech after UI has had time to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let utterance = AVSpeechUtterance(string: entry.line)

                if let id = self.characterOptions[entry.character]?.voiceID,
                   let voice = AVSpeechSynthesisVoice(identifier: id) {
                    utterance.voice = voice
                }
                utterance.postUtteranceDelay = 0.5

                let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
                    currentUtteranceIndex += 1
                    updateProgress()
                    startNextLine()
                }
                self.speechDelegate = delegate
                self.synthesizer.delegate = delegate
                self.synthesizer.speak(utterance)
                
                print("🗣️ Started speaking line after UI update delay")
            }
        }
    }
    
    
    // MARK: - Skip Helper Functions
    private func updateUserLineState() {
        guard currentUtteranceIndex < dialogue.count else {
            isUserLine = false
            return
        }
        
        let entry = dialogue[currentUtteranceIndex]
        if selectedCharacters.contains("Just Listening") {
            isUserLine = false
        } else if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
            isUserLine = true
        } else {
            isUserLine = false
        }
    }
    
    private func speakLineDirectly(_ text: String, for character: String) {
        let utterance = AVSpeechUtterance(string: text)

        // Apply the user-picked voice if one is set
        if let id = characterOptions[character]?.voiceID,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        }
        utterance.postUtteranceDelay = 2

        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
            currentUtteranceIndex += 1
            updateProgress()
            startNextLine()
        }
        speechDelegate = delegate
        synthesizer.delegate = delegate
        synthesizer.speak(utterance)
    }
    
    // MARK: - Restart Current Line Function
    private func restartCurrentLine() {
        print("🔄 Restart line button pressed - Current index: \(currentUtteranceIndex)")
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("🛑 Stopped speaking for restart")
        }
        
        // Clear delegates
        synthesizer.delegate = nil
        speechDelegate = nil
        print("🗑️ Cleared delegates for restart")
        
        // Reset speech states
        isSpeaking = false
        isPaused = false
        
        // Create fresh synthesizer to ensure clean state
        synthesizer = AVSpeechSynthesizer()
        print("💫 Created fresh synthesizer for restart")
        
        // Update user line state
        updateUserLineState()
        
        // Start the current line if it's not a user line
        if !isUserLine {
            // Use the delayed speech function to avoid immediate delegate issues
            speakLineForUnpausedSkip()
            print("🎬 Restarted current line")
        } else {
            print("👤 Current line is user's - no restart needed")
        }
        
        print("✅ Line restart complete - index: \(currentUtteranceIndex)")
    }
    
    // MARK: - Hint Helper Functions
    
    private func getHintButtonColor() -> Color {
        // If not user's line, always gray
        if !isUserLine {
            return .gray
        }
        
        // If user's line but full line already revealed, gray it out
        if hintClickCount >= 999 {
            return .gray
        }
        
        // Otherwise, normal yellow color
        return .yellow
    }

    private func getHintButtonDisabled() -> Bool {
        // Disabled if not user's line OR if full line already revealed
        return !isUserLine || hintClickCount >= 999
    }
    
    private func getHintText(for line: String, clickCount: Int) -> String {
        let words = line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // If line has 5 words or fewer, always show the full line
        if words.count <= 5 {
            return line
        }
        
        // For longer lines, show progressively more words
        let wordsToShow: Int
        if clickCount == 1 {
            // First click: show first 3-4 words (about 1/3 of line)
            wordsToShow = max(3, words.count / 3)
        } else {
            // Second click: show about 2/3 of the line
            wordsToShow = max(4, (words.count * 2) / 3)
        }
        
        let revealedWords = Array(words.prefix(wordsToShow))
        return revealedWords.joined(separator: " ") + "..."
    }

    private func shouldShowFullLineButton(for line: String, clickCount: Int) -> Bool {
        let words = line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // If line is short, never show "reveal full line" button
        if words.count <= 5 {
            return false
        }
        
        // Show "reveal full line" button after second click
        return clickCount >= 2
    }
    
    private func handleHintButtonPressed() {
        guard currentUtteranceIndex < dialogue.count else { return }
        
        let currentLine = dialogue[currentUtteranceIndex]
        let words = currentLine.line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // Reset hint if we're on a different line
        if currentHintLineIndex != currentUtteranceIndex {
            hintClickCount = 0
            currentHintLineIndex = currentUtteranceIndex
            revealedWords = []
        }
        
        // For lines with 5 words or fewer, always show the full line immediately
        if words.count <= 5 {
            revealedWords = words
            hintClickCount = 999 // Set high number to indicate full reveal
            return
        }
        
        // For longer lines, increment click count and show progressive hints
        hintClickCount += 1
        
        // Generate the hint text
        let hintText = getHintText(for: currentLine.line, clickCount: hintClickCount)
        revealedWords = hintText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty && $0 != "..." }
    }
    
    private func handleRevealFullLinePressed() {
        guard currentUtteranceIndex < dialogue.count else { return }
        
        let currentLine = dialogue[currentUtteranceIndex]
        let words = currentLine.line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        revealedWords = words
        hintClickCount = 999 // Set high number to indicate full reveal
    }

    private func resetHintForNewLine() {
        hintClickCount = 0
        currentHintLineIndex = -1
        revealedWords = []
    }
    
    private func shouldShowHintText(for index: Int) -> Bool {
        return index == currentUtteranceIndex &&
               showHints &&
               !revealedWords.isEmpty &&
               currentHintLineIndex == index
    }
    
    // MARK: - Script Conversion Function
    func convertScriptToCorrectFormat(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var convertedLines: [String] = []
        var i = 0

        while i < lines.count {
            var currentLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            currentLine = currentLine.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)

            if currentLine.isEmpty {
                i += 1
                continue
            }

            let digitSet = CharacterSet.decimalDigits
            let currentCharacterSet = CharacterSet(charactersIn: currentLine)
            if digitSet.isSuperset(of: currentCharacterSet) {
                i += 1
                continue
            }

            if currentLine == currentLine.uppercased() && !currentLine.contains(":") {
                if i + 1 < lines.count {
                    var nextLine = lines[i+1].trimmingCharacters(in: .whitespacesAndNewlines)
                    nextLine = nextLine.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)

                    if !nextLine.isEmpty && nextLine != nextLine.uppercased() {
                        let combinedLine = "\(currentLine): \(nextLine)"
                        convertedLines.append(combinedLine)
                        i += 2
                        continue
                    }
                }
            }

            if currentLine.contains(":") {
                convertedLines.append(currentLine)
            }

            i += 1
        }

        return convertedLines.joined(separator: "\n")
    }
    
    // MARK: - Rating System Functions
    
    private func openAppStoreRating() {
        // This will open the App Store rating page for your app
        // You'll need to replace "YOUR_APP_ID" with your actual App Store app ID
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
        print("⭐ Opened App Store rating page")
    }
    
    private func startUsageTracking() {
        // FOR TESTING ONLY - remove this line in production
        resetRatingStatusForTesting()
        
        // Check if we've already prompted for rating
        hasPromptedForRating = UserDefaults.standard.bool(forKey: "hasPromptedForRating")
        
        print("⭐ hasPromptedForRating: \(hasPromptedForRating)")
        
        // Only start tracking if we haven't prompted yet
        guard !hasPromptedForRating else {
            print("⭐ Rating already prompted - skipping usage tracking")
            return
        }
        
        print("⭐ Starting usage tracking - will prompt after \(ratingPromptDelay) seconds")
        usageStartTime = Date()
        
        // Start timer that checks every 5 seconds
        appUsageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.checkUsageTime()
        }
        print("⭐ Timer started successfully")
    }

    private func stopUsageTracking() {
        print("⭐ Stopping usage tracking")
        appUsageTimer?.invalidate()
        appUsageTimer = nil
        usageStartTime = nil
    }

    private func checkUsageTime() {
        guard let startTime = usageStartTime else {
            print("⭐ No start time found")
            return
        }
        
        let currentUsage = Date().timeIntervalSince(startTime)
        print("⭐ Current usage time: \(Int(currentUsage)) seconds (threshold: \(Int(ratingPromptDelay)))")
        
        if currentUsage >= ratingPromptDelay {
            print("⭐ Usage threshold reached - showing rating prompt")
            stopUsageTracking()
            
            // STEP 2: Pause speech and remember the state before showing popup
            pauseSpeechForRatingPopup()
            
            DispatchQueue.main.async {
                self.showRatingPrompt = true
                print("⭐ showRatingPrompt set to true")
            }
        }
    }
    
    private func pauseSpeechForRatingPopup() {
        print("⭐ Pausing speech for rating popup")
        print("⭐ Current state - isSpeaking: \(synthesizer.isSpeaking), isPaused: \(isPaused)")
        
        // Remember the current speech state
        wasPlayingBeforeRating = synthesizer.isSpeaking && !isPaused
        wasPausedBeforeRating = isPaused
        
        print("⭐ Remembered state - wasPlaying: \(wasPlayingBeforeRating), wasPaused: \(wasPausedBeforeRating)")
        
        // Pause any active speech
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
            isPaused = true
            print("⭐ Paused active speech for rating popup")
        }
    }
    
    private func resetRatingStatusForTesting() {
        UserDefaults.standard.removeObject(forKey: "hasPromptedForRating")
        hasPromptedForRating = false
        print("⭐ [TESTING] Reset rating status - can prompt again")
    }
    
    private func handleStarTap(_ starNumber: Int) {
        print("⭐ Star \(starNumber) tapped, current rating: \(selectedStarRating)")
        
        // Mark that user has interacted with stars
        hasTappedStars = true
        
        if selectedStarRating == starNumber {
            // Tapping the same star deselects all stars
            selectedStarRating = 0
            print("⭐ Deselected all stars")
        } else {
            // Tapping a different star selects that star and all previous ones
            selectedStarRating = starNumber
            print("⭐ Selected \(starNumber) stars")
        }
    }

    private func markRatingPrompted() {
        hasPromptedForRating = true
        UserDefaults.standard.set(true, forKey: "hasPromptedForRating")
        print("⭐ Marked rating as prompted in UserDefaults - will not show again")
        
        // MARK: - FOR TESTING ONLY
        // remove this in production
        // This allows testing the rating prompt multiple times
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UserDefaults.standard.removeObject(forKey: "hasPromptedForRating")
            self.hasPromptedForRating = false
            print("⭐ [TESTING] Reset rating status after 1 second for testing purposes")
        }
    }

    // MARK: - Helper Functions
    func handleFileSelection(url: URL) {
        do {
            if inputType == .pdf {
                if let pdfDocument = PDFDocument(url: url) {
                    let pageCount = pdfDocument.pageCount
                    let documentContent = NSMutableAttributedString()

                    for i in 0..<pageCount {
                        if let page = pdfDocument.page(at: i),
                           let pageContent = page.attributedString {
                            documentContent.append(pageContent)
                        }
                    }
                    self.fileContent = documentContent.string
                } else {
                    self.fileContent = "Error loading PDF content."
                }
            } else {
                self.fileContent = try String(contentsOf: url, encoding: .utf8)
            }

            // Just set the file info without validation - validation happens on Continue button
            self.uploadedFileName = url.lastPathComponent
            self.hasUploadedFile = true
            self.hasPressedContinue = false
        } catch {
            self.fileContent = "Error loading file content."
            print("❌ Error loading file content: \(error.localizedDescription)")
            // Reset file state on actual file loading error
            self.selectedFileURL = nil
        }
    }

    func extractDialogue(from text: String) -> [(character: String, line: String)] {
        var extractedDialogue: [(String, String)] = []
        let lines = text.split(separator: "\n")

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let colonIndex = trimmedLine.firstIndex(of: ":") else {
                continue
            }

            let characterName = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let content = trimmedLine[trimmedLine.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)

            extractedDialogue.append((characterName, content))
        }

        return extractedDialogue
    }
    
    
    // MARK: - Speech Functions
    func initializeSpeech() {
        // Don't change currentUtteranceIndex here - it should be set before calling this function
        isSpeaking = false
        isPaused = true  // Changed: Start paused instead of playing

        synthesizer = AVSpeechSynthesizer()
        speechDelegate = nil

        // Set the correct user line state but don't start speaking
        updateUserLineState()
        
        print("🎬 Speech initialized in paused state - press play to start")
    }

    private func startNextLine() {
        guard currentUtteranceIndex < dialogue.count else {
            showScriptCompletionAlert = true
            return
        }

        let entry = dialogue[currentUtteranceIndex]
        if selectedCharacters.contains("Just Listening") {
            isUserLine = false
            speakLine(entry.line, for: entry.character)
        } else if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
            if displayMyLines {
                isUserLine = true
            } else {
                isUserLine = true
            }
        } else {
            isUserLine = false
            speakLine(entry.line, for: entry.character)
        }
    }

    private func userLineFinished() {
        resetHintForNewLine()
        currentUtteranceIndex += 1
        updateProgress()
        
        // Check if we were in a paused state (like after skipping)
        if isPaused {
            // Stay paused, just update the UI state for the new line
            updateUserLineState()
            print("📍 User line finished, staying paused at index: \(currentUtteranceIndex)")
        } else {
            // Normal flow - continue to next line
            startNextLine()
            print("📍 User line finished, continuing to index: \(currentUtteranceIndex)")
        }
    }

    /// Speaks the line using the chosen voice for its character
    private func speakLine(_ text: String, for character: String) {
        print("🗣️ === speakLine() ENTRY ===")
        print("🗣️ character: \(character)")
        print("🗣️ currentUtteranceIndex: \(currentUtteranceIndex)")
        print("🗣️ text: '\(text)'")
        
        let utterance = AVSpeechUtterance(string: text)

        // Apply the user-picked voice if one is set
        if let id = characterOptions[character]?.voiceID,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
            print("🗣️ Applied voice: \(voice.name)")
        }
        utterance.postUtteranceDelay = 0.5

        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
            print("🔔 === REGULAR speakLine DELEGATE FIRED ===")
            print("🔔 About to increment from \(currentUtteranceIndex)")
            
            currentUtteranceIndex += 1
            updateProgress()
            
            print("🔔 After increment: currentUtteranceIndex = \(currentUtteranceIndex)")
            print("🔔 About to call startNextLine()")
            startNextLine()
            print("🔔 === REGULAR DELEGATE COMPLETE ===")
        }
        
        speechDelegate = delegate
        synthesizer.delegate = delegate
        print("🗣️ About to call synthesizer.speak()")
        synthesizer.speak(utterance)
        print("🗣️ === speakLine() EXIT ===")
    }
    
    private func updateProgress() {
        guard currentSavedScript != nil else { return }
        
        let now = Date()
        let timeSinceLastSave = now.timeIntervalSince(lastSaveTime)
        
        // Only save if it's been at least 0.5 seconds since the last save
        if timeSinceLastSave >= 0.5 {
            performSave()
        } else {
            // Mark that we have a pending save and schedule it
            pendingSave = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.pendingSave {
                    self.performSave()
                }
            }
        }
    }

    func pauseOrResumeSpeech() {
        print("🎵 === pauseOrResumeSpeech() ENTRY ===")
        print("🎵 synthesizer.isSpeaking: \(synthesizer.isSpeaking)")
        print("🎵 isPaused: \(isPaused)")
        print("🎵 currentUtteranceIndex: \(currentUtteranceIndex)")
        print("🎵 isUserLine: \(isUserLine)")
        
        if synthesizer.isSpeaking {
            if isPaused {
                // Resume
                print("🎵 RESUMING...")
                synthesizer.continueSpeaking()
                isPaused = false
                print("🎵 Resumed - isPaused now: \(isPaused)")
            } else {
                // Pause
                print("🎵 PAUSING...")
                synthesizer.pauseSpeaking(at: .word)
                isPaused = true
                print("🎵 Paused - isPaused now: \(isPaused)")
            }
        } else {
            // If not speaking, start from current line
            print("🎵 NOT SPEAKING - starting from current line")
            print("🎵 About to set isPaused = false and call startNextLine()")
            isPaused = false
            startNextLine()
            print("🎵 Started - isPaused now: \(isPaused)")
        }
        
        print("🎵 === pauseOrResumeSpeech() EXIT ===")
    }
    
    

    private func restartScript(keepSettings: Bool) {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.delegate = nil

        isUserLine = false

        if keepSettings {
            // Keep the same starting line when keeping settings
            currentUtteranceIndex = startingLineIndex
            initializeSpeech()
        } else {
            // Reset everything when changing settings
            currentUtteranceIndex = 0
            startingLineIndex = 0
            hasSetStartingLine = false
            isCharacterSelected = false
            isShowingCharacterCustomization = false
            isShowingStartingLineSelection = false
            selectedCharacters = []
            displayLinesAsRead = true
            selectedStartingLineIndex = nil
        }
    }
    
    func colorForCharacter(_ character: String) -> Color {
        characterOptions[character]?.highlight.swiftUIColor ?? .gray
    }
    
    // MARK: - Navigation Helper Methods

    private func handleBackFromScriptReading() {
        // Auto-pause speech when going back
        pauseSpeechForNavigation()
        
        if isLoadedScript {
            // For loaded scripts: just save progress and go back
            if currentSavedScript != nil {
                saveCurrentScript()
                print("💾 Saved loaded script progress")
            }
            isCharacterSelected = false
            isShowingStartingLineSelection = true
            print("⬅️ Loaded script: navigating back to starting line selection")
        } else {
            // For new scripts: preserve everything before going back
            print("⬅️ New script: preserving all settings before going back")
            isCharacterSelected = false
            isShowingStartingLineSelection = true
        }
    }

    private func handleBackFromStartingLineSelection() {
        if isLoadedScript {
            // For loaded scripts: just go back to character customization
            isShowingStartingLineSelection = false
            print("⬅️ Loaded script: going back to character customization")
        } else {
            // For new scripts: go back to character customization
            isShowingStartingLineSelection = false
            print("⬅️ New script: going back to character customization")
        }
    }

    private func handleContinueFromCharacterCustomization() {
        if isLoadedScript {
            // For loaded scripts: preserve the original starting line selection
            if selectedStartingLineIndex == nil {
                selectedStartingLineIndex = startingLineIndex
                print("🔒 Loaded script: restored starting line selection: \(startingLineIndex)")
            }
        } else {
            // For new scripts: preserve whatever starting line was set
            if selectedStartingLineIndex == nil && hasSetStartingLine {
                selectedStartingLineIndex = startingLineIndex
                print("📝 New script: preserved starting line selection: \(startingLineIndex)")
            }
        }
        isShowingStartingLineSelection = true
    }
    

    // MARK: - Hamburger Menu Navigation

    private func navigateToUploadScript() {
        // Close the menu first
        withAnimation {
            isLibraryOpen = false
        }
        
        // Reset all states to go to upload script view
        isLoadedScript = false
        currentSavedScript = nil
        
        // Reset upload states
        uploadedFileName = ""
        fileContent = ""
        selectedFileURL = nil
        dialogue = []
        characters = []
        selectedCharacters = []
        characterOptions = [:]
        scriptName = ""
        
        // Reset navigation states to show upload view
        isShowingHomepage = false
        isShowingScriptLibrary = false
        hasUploadedFile = false
        hasPressedContinue = false
        isShowingCharacterCustomization = false
        isShowingStartingLineSelection = false
        isCharacterSelected = false
        
        print("📱 Navigated to Upload Script from hamburger menu")
    }

    private func navigateToScriptLibrary() {
        // Close the menu first
        withAnimation {
            isLibraryOpen = false
        }
        
        // Set states to show script library
        isShowingHomepage = false
        isShowingScriptLibrary = true
        
        print("📱 Navigated to Script Library from hamburger menu")
    }
    
    
    
    // MARK: - Library Helper Functions
    
    private func deleteScript(_ script: SavedScript) {
        // Find the script in the library and remove it using the existing delete method
        if let index = libraryManager.scripts.firstIndex(where: { $0.id == script.id }) {
            let indexSet = IndexSet(integer: index)
            libraryManager.delete(at: indexSet)
            print("🗑️ Successfully deleted script: \(script.title)")
        }
    }
    
    private func getCharacterHighlightColor(_ characterName: String, script: SavedScript) -> Color {
        // Check if this character has saved highlight options
        if let characterOption = script.settings.characterOptions[characterName] {
            return characterOption.highlight.swiftUIColor
        } else {
            // Fallback to blue if no saved color found
            return .blue
        }
    }
    
    private var adaptiveSecondaryColor: Color {
        colorScheme == .dark ? .secondary : .black
    }
    
    private func performSave() {
        guard let script = currentSavedScript else { return }
        
        let updatedScript = SavedScript(
            id: script.id,
            title: scriptName.isEmpty ? script.title : scriptName,
            rawText: script.rawText,
            settings: ScriptSettings(
                selectedCharacters: Array(selectedCharacters),
                displayLinesAsRead: displayLinesAsRead,
                displayMyLines: displayMyLines,
                showHints: showHints,
                startingLineIndex: startingLineIndex,
                characterOptions: characterOptions  // Add this line
            ),
            progressIndex: currentUtteranceIndex,
            dateSaved: Date()
        )
        
        libraryManager.update(updatedScript)
        currentSavedScript = updatedScript
        lastSaveTime = Date()
        pendingSave = false
        
        print("💾 Progress saved with character options")
    }
    
    private func loadScriptFromLibrary(_ script: SavedScript) {
        print("🚀 Loading script from library: \(script.title)")
        
        // Load script content
        fileContent = script.rawText
        uploadedFileName = script.title
        scriptName = script.title
        
        // Convert and extract dialogue
        let convertedScript = convertScriptToCorrectFormat(from: fileContent)
        dialogue = extractDialogue(from: convertedScript)
        characters = Array(Set(dialogue.map { $0.character })).sorted()
        
        // Load character options
        if !script.settings.characterOptions.isEmpty {
            characterOptions = script.settings.characterOptions
        } else {
            ensureCharacterOptions()
        }
        ensureCharacterOptions()
        
        // Load settings
        selectedCharacters = Set(script.settings.selectedCharacters)
        displayLinesAsRead = script.settings.displayLinesAsRead
        displayMyLines = script.settings.displayMyLines
        showHints = script.settings.showHints
        
        // Load progress and starting line
        startingLineIndex = script.settings.startingLineIndex
        currentUtteranceIndex = script.progressIndex
        hasSetStartingLine = true
        selectedStartingLineIndex = script.settings.startingLineIndex
        
        // Set as current saved script
        currentSavedScript = script
        
        // Set flag that this is a loaded script
        isLoadedScript = true
        
        // Set ALL navigation states required to reach scriptReadingView
        isShowingHomepage = false
        isShowingScriptLibrary = false
        hasUploadedFile = true
        hasPressedContinue = true
        isShowingCharacterCustomization = true
        isShowingStartingLineSelection = true
        isCharacterSelected = true
        
        updateHighlightColors()
        initializeSpeech()
        
        print("📖 Navigation state set - should go to script reading view")
        print("📖 isCharacterSelected: \(isCharacterSelected)")
        print("📖 isShowingStartingLineSelection: \(isShowingStartingLineSelection)")
    }
    
    private func getStartingLineInfo(_ script: SavedScript) -> (character: String, line: String) {
        let convertedScript = convertScriptToCorrectFormat(from: script.rawText)
        let scriptDialogue = extractDialogue(from: convertedScript)
        
        // Use the startingLineIndex from settings, not the progress index
        let startingIndex = script.settings.startingLineIndex
        
        if startingIndex < scriptDialogue.count {
            let entry = scriptDialogue[startingIndex]
            return (character: entry.character, line: entry.line)
        } else {
            return (character: "", line: "Beginning of script")
        }
    }

    private func getCharacterNamesForScript(_ script: SavedScript) -> [String] {
        let convertedScript = convertScriptToCorrectFormat(from: script.rawText)
        let scriptDialogue = extractDialogue(from: convertedScript)
        return Array(Set(scriptDialogue.map { $0.character })).sorted()
    }

    private func getCharacterDisplayName(_ characterName: String, selectedCharacters: [String], characterOptions: [String: CharacterOptions]) -> AttributedString {
        if selectedCharacters.contains("Just Listening") {
            var attributedString = AttributedString("Just Listening")
            attributedString.foregroundColor = .secondary
            return attributedString
        }
        
        if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(characterName) == .orderedSame }) {
            var attributedString = AttributedString(characterName.capitalized)
            if let color = characterOptions[characterName]?.highlight.swiftUIColor {
                attributedString.foregroundColor = Color(color)
            }
            return attributedString
        } else {
            var attributedString = AttributedString(characterName.capitalized)
            attributedString.foregroundColor = .secondary
            return attributedString
        }
    }

    private func getProgressSnippet(_ script: SavedScript) -> [(character: String, line: String, isCurrentLine: Bool)] {
        let convertedScript = convertScriptToCorrectFormat(from: script.rawText)
        let scriptDialogue = extractDialogue(from: convertedScript)
        
        var snippet: [(character: String, line: String, isCurrentLine: Bool)] = []
        let progressIndex = script.progressIndex
        
        // Add line before (if exists)
        if progressIndex > 0 && progressIndex - 1 < scriptDialogue.count {
            let entry = scriptDialogue[progressIndex - 1]
            snippet.append((character: entry.character, line: entry.line, isCurrentLine: false))
        }
        
        // Add current line (if exists)
        if progressIndex < scriptDialogue.count {
            let entry = scriptDialogue[progressIndex]
            snippet.append((character: entry.character, line: entry.line, isCurrentLine: true))
        }
        
        // Add line after (if exists)
        if progressIndex + 1 < scriptDialogue.count {
            let entry = scriptDialogue[progressIndex + 1]
            snippet.append((character: entry.character, line: entry.line, isCurrentLine: false))
        }
        
        return snippet
    }

    private func getColorForCharacterInScript(_ characterName: String, script: SavedScript) -> Color {
        // For library display, we'll use a simplified color system
        // since we don't have the full characterOptions loaded
        let selectedCharacters = script.settings.selectedCharacters
        
        if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(characterName) == .orderedSame }) {
            // User's character - use a default highlight color
            return .blue.opacity(0.3)
        } else {
            // Non-user character - use gray
            return .gray.opacity(0.2)
        }
    }
    
    
    // MARK: - Library Integration Functions
    private func saveCurrentScript() {
        let settings = ScriptSettings(
            selectedCharacters: Array(selectedCharacters),
            displayLinesAsRead: displayLinesAsRead,
            displayMyLines: displayMyLines,
            showHints: showHints,
            startingLineIndex: startingLineIndex,
            characterOptions: characterOptions  // Add this line
        )
        
        let script = SavedScript(
            id: currentSavedScript?.id ?? UUID(),
            title: scriptName.isEmpty ? uploadedFileName : scriptName,
            rawText: fileContent,
            settings: settings,
            progressIndex: currentUtteranceIndex,
            dateSaved: Date()
        )
        
        if currentSavedScript != nil {
            libraryManager.update(script)
        } else {
            libraryManager.add(script)
        }
        
        currentSavedScript = script
        print("💾 Saved script with character options: \(characterOptions.keys)")
    }
    
    private func loadScript(from script: SavedScript) {
        // Load script content
        fileContent = script.rawText
        uploadedFileName = script.title
        scriptName = script.title  // Make sure script name is set
        
        // Convert and extract dialogue
        let convertedScript = convertScriptToCorrectFormat(from: fileContent)
        dialogue = extractDialogue(from: convertedScript)
        characters = Array(Set(dialogue.map { $0.character })).sorted()
        ensureCharacterOptions()
        
        // Load settings - make sure selectedCharacters is properly set
        selectedCharacters = Set(script.settings.selectedCharacters)
        displayLinesAsRead = script.settings.displayLinesAsRead
        displayMyLines = script.settings.displayMyLines
        showHints = script.settings.showHints
        
        print("🔄 Loaded settings - selectedCharacters: \(selectedCharacters)")
        print("🔄 Script settings selectedCharacters: \(script.settings.selectedCharacters)")
        
        // Set progress
        currentUtteranceIndex = script.progressIndex
        startingLineIndex = script.progressIndex  // Make sure starting line is set
        hasSetStartingLine = true  // Make sure this flag is set
        
        // Update state
        currentSavedScript = script
        hasUploadedFile = true
        hasPressedContinue = true
        isShowingCharacterCustomization = true
        isCharacterSelected = true
        isShowingSplash = false
        
        // Make sure colors are updated after character selection
        updateHighlightColors()
        
        // Initialize speech if we're in the script reading view
        if isCharacterSelected {
            initializeSpeech()
        }
        
        print("📖 Loaded script from existing library system: \(script.title)")
    }
}

/// Holds the per-character voice & highlight that the user chooses
struct CharacterOptions: Codable, Equatable {  // Add Equatable here
    var voiceID: String
    var highlight: SerializableColor
}
// MARK: - AVSpeechSynthesizerDelegateWrapper
class AVSpeechSynthesizerDelegateWrapper: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}
