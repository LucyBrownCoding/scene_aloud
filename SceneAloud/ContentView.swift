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


struct SerializableColor: Codable {
    var r, g, b, a: Double          // 0…1 range

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
    
    @State private var showHints: Bool = true
    @State private var hintClickCount: Int = 0
    @State private var currentHintLineIndex: Int = -1
    @State private var revealedWords: [String] = []


    // Update your AlertType enum to include hintsInfo
    enum AlertType: Identifiable {
        case noCharacterSelected
        case displayLinesAsReadInfo
        case notApplicableInfo
        case displayMyLinesInfo
        case lastLineWarning
        case hintsInfo // NEW

        var id: Int {
            switch self {
            case .noCharacterSelected: return 0
            case .displayLinesAsReadInfo: return 1
            case .notApplicableInfo: return 2
            case .displayMyLinesInfo: return 3
            case .lastLineWarning: return 4
            case .hintsInfo: return 5 // NEW
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
            NavigationView {
                mainContentView
            }
            .navigationBarHidden(isShowingSplash)
            
            // Library slide-in panel (updated to use LibraryManager)
            if isLibraryOpen {
                // Dark overlay background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isLibraryOpen = false
                        }
                    }
                
                // Library panel
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Library")
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
                    
                    // Scripts list
                    if libraryManager.scripts.isEmpty {
                        VStack {
                            Spacer()
                            Text("No saved scripts")
                                .foregroundColor(.secondary)
                                .font(.body)
                            Text("Scripts will appear here after you save them")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(libraryManager.scripts.sorted(by: { $0.dateSaved > $1.dateSaved })) { script in
                                    Button(action: {
                                        libraryManager.select(script)
                                    }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(script.title)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                Text(script.dateSaved, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            HStack {
                                                // Progress indicator
                                                let totalLines = script.rawText.components(separatedBy: .newlines)
                                                    .filter { $0.contains(":") }.count
                                                if totalLines > 0 {
                                                    Text("Progress: \(script.progressIndex)/\(totalLines)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                // Character count
                                                Text("\(script.settings.selectedCharacters.count) characters")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                    
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
        .onChange(of: libraryManager.selectedScript) { _, newValue in
            if let script = newValue {
                loadScript(from: script)
                libraryManager.selectedScript = nil // Reset selection
                withAnimation {
                    isLibraryOpen = false
                }
            }
        }
    }

    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        if isShowingSplash {
            splashView
        } else if !hasUploadedFile {
            HamburgerOverlay(showSideMenu: $isLibraryOpen) {
                uploadView
            }
        } else if !hasPressedContinue {
            HamburgerOverlay(showSideMenu: $isLibraryOpen) {
                continueView
            }
        } else if !isShowingCharacterCustomization {
            settingsView
        } else if !isShowingStartingLineSelection {
            characterCustomizationView
        } else if !isCharacterSelected {
            startingLineSelectionView
        } else {
            scriptReadingView
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
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)

                    Text("SceneAloud!")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                }
                .padding(.top, 40)

                Spacer()

                VStack(spacing: 5) {
                    Text("Created by Lucy Brown")
                    Text("Sound Design and Logo by Abrielle Smith")
                }
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            isShowingSplash = false
        }
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

    // MARK: - Typed Input View
    @ViewBuilder
    private var typedInputView: some View {
        TextEditor(text: $fileContent)
            .frame(height: 200)
            .border(Color.gray, width: 1)
            .padding(.horizontal, 40)

        Button(action: {
            let convertedScript = convertScriptToCorrectFormat(from: fileContent)
            self.dialogue = self.extractDialogue(from: convertedScript)
            let extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
            self.characters = extractedCharacters
            ensureCharacterOptions()
            updateHighlightColors() // Set initial colors
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

            Button(action: { hasPressedContinue = true }) {
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
    }

    // MARK: - Settings View
    @ViewBuilder
    private var settingsView: some View {
            HamburgerOverlay(showSideMenu: $isLibraryOpen) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading) {
                            // Removed the large bold "Settings" title
                            // Now only uses the navigation title at the top
                            
                            Text("Select your characters")
                                .font(.title2)
                                .padding(.vertical, 5)

                            characterSelectionSection

                            displaySettingsSection

                            Spacer()

                            Button(action: {
                                if selectedCharacters.isEmpty {
                                    activeAlert = .noCharacterSelected
                                } else {
                                    updateHighlightColors() // Update colors before going to customization
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
                            .padding(.bottom, 10)
                            
                            // Save Script Button
                            Button(action: {
                                saveCurrentScript()
                            }) {
                                Text("Save Script")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.bottom, 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10) // Adjusted top padding since we removed the large title
                    }
                }
                .alert(item: $activeAlert) { alert in
                    alertForType(alert)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationTitle("Settings") // This creates the small title at the top
                .navigationBarTitleDisplayMode(.inline) // Ensures small title format
                .toolbar {
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
                }
                .onChange(of: selectedCharacters) { _, newValue in
                    if newValue.contains("Not Applicable") {
                        displayMyLines = false
                        showHints = false  // Turn off hints when "Not Applicable" is selected
                    }
                    // Update highlight colors when character selection changes
                    updateHighlightColors()
                }
                .onChange(of: displayMyLines) { _, newValue in
                    if newValue {
                        showHints = false  // Turn off hints when "Display My Lines" is turned on
                    }
                }
                .onChange(of: showHints) { _, newValue in
                    if newValue {
                        displayMyLines = false  // Turn off "Display My Lines" when hints is turned on
                    }
                }
            }
        }

    // MARK: - Character Selection Section
    @ViewBuilder
    private var characterSelectionSection: some View {
        HStack {
            Text("Not Applicable")
            Button(action: { activeAlert = .notApplicableInfo }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
            Toggle("", isOn: Binding(
                get: { selectedCharacters.contains("Not Applicable") },
                set: { newValue in
                    if newValue {
                        selectedCharacters = ["Not Applicable"]
                    } else {
                        selectedCharacters.remove("Not Applicable")
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
                        selectedCharacters.remove("Not Applicable")
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
                    .disabled(selectedCharacters.contains("Not Applicable"))
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
                .disabled(selectedCharacters.contains("Not Applicable"))
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
        let isNotApplicable = selectedCharacters.contains("Not Applicable")
        
        if isUserCharacter && !isNotApplicable {
            // User is playing this character and not "Not Applicable" - allow color selection
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
            // User is not playing this character or "Not Applicable" is selected - show locked gray
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
        HamburgerOverlay(showSideMenu: $isLibraryOpen) {
            VStack {
                characterCustomizationList
                characterCustomizationButtonSection
            }
            .navigationTitle("Character Customization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        pauseSpeechForNavigation()
                        stopVoicePreview()
                        isShowingCharacterCustomization = false
                    } label: {
                        Label("Back", systemImage: "arrow.left")
                    }
                }
            }
            .onAppear {
                ensureCharacterOptions()
                updateHighlightColors()
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
        }
    }

    
    // MARK: - Character Customization Button Section
    @ViewBuilder
    private var characterCustomizationButtonSection: some View {
        VStack {
            Button(action: {
                isShowingStartingLineSelection = true
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
        HamburgerOverlay(showSideMenu: $isLibraryOpen) {
            VStack(spacing: 0) {
                // Description text at top
                VStack(spacing: 10) {
                    Text("Please select the line you would like to start rehearsing from.")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }
                .background(Color(UIColor.systemBackground))
                
                // Script display
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(dialogue.indices, id: \.self) { index in
                            let entry = dialogue[index]
                            let isSelected = selectedStartingLineIndex == index
                            let isUserCharacter = selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame })
                            let characterColor = colorForCharacter(entry.character)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.character)
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(entry.line)
                                    .font(.body)
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
                            .padding(.bottom, 5)
                            .id(index)
                            .contentShape(Rectangle()) // Makes entire area tappable
                            .onTapGesture {
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
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemBackground))
                
                // Continue button at bottom
                VStack {
                    Button(action: {
                        if let startingIndex = selectedStartingLineIndex {
                            startingLineIndex = startingIndex
                            currentUtteranceIndex = startingIndex
                            hasSetStartingLine = true
                        }
                        isCharacterSelected = true
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedStartingLineIndex != nil ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(selectedStartingLineIndex == nil)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .padding(.top, 10)
                }
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("Select Starting Line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedStartingLineIndex = nil
                        hasSetStartingLine = false
                        isShowingStartingLineSelection = false
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                    }
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
        }
    }
    
    
    // MARK: - Script Reading View
    @ViewBuilder
    private var scriptReadingView: some View {
            HamburgerOverlay(showSideMenu: $isLibraryOpen) {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .onChange(of: currentUtteranceIndex) { _ in
                                withAnimation {
                                    proxy.scrollTo(currentUtteranceIndex, anchor: .top)
                                }
                            }
                        }
                        .background(Color(UIColor.systemBackground))
                    }
                    .background(Color(UIColor.systemBackground))

                    controlButtonsSection
                }
                .navigationTitle("SceneAloud")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            // Auto-pause speech when going back
                            pauseSpeechForNavigation()
                            // Go back to starting line selection
                            isCharacterSelected = false
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                        }
                    }
                }
                .onAppear(perform: initializeSpeech)
                .onDisappear {
                    // Auto-pause when view disappears for any reason
                    pauseSpeechForNavigation()
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
                            
                            // Button text changes based on state
                            if currentUtteranceIndex < dialogue.count {
                                let currentLine = dialogue[currentUtteranceIndex]
                                let words = currentLine.line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                                
                                if words.count <= 5 {
                                    Text("Reveal My Line")
                                        .font(.body)
                                } else if shouldShowFullLineButton(for: currentLine.line, clickCount: hintClickCount) {
                                    Text("Reveal Full Line")
                                        .font(.body)
                                } else {
                                    Text("Hint")
                                        .font(.body)
                                }
                            } else {
                                Text("Hint")
                                    .font(.body)
                            }
                        }
                        .foregroundColor(isUserLine ? .yellow : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background((isUserLine ? Color.yellow : Color.gray).opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(!isUserLine)
                    
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

    // MARK: - Alert Helper
    private func alertForType(_ alert: AlertType) -> Alert {
        switch alert {
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
                title: Text("Not Applicable"),
                message: Text("When 'Not Applicable' is selected, you will just be listening to the script and will not be participating."),
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
        case .hintsInfo:
            return Alert(
                title: Text("Hints"),
                message: Text("When turned on, 'Hints' allows you to ask for the first few words of your line to be revealed if you are having trouble remembering it."),
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

                if selectedCharacters.contains("Not Applicable") {
                    // When "Not Applicable" is selected, check THIS character's color individually
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
                        .background(
                            index == currentUtteranceIndex ?
                            characterColor.opacity(0.7) :
                            (isThisCharacterGray ? Color.clear : characterColor.opacity(0.2))
                        )
                        .cornerRadius(5)
                }
            }
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
        
        // Only check among characters the user is playing (excluding "Not Applicable")
        let userCharacters = selectedCharacters.filter { $0 != "Not Applicable" }
        
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
    
    // Updated ensureCharacterOptions function (UPDATED - Proper Voice Defaults)
    /// Makes sure every character has a default entry in `characterOptions`
    private func ensureCharacterOptions() {
        // Determine the appropriate gray color based on color scheme
        let defaultGrayColor: Color
        if colorScheme == .dark {
            // Dark mode: use darker gray
            defaultGrayColor = Color.gray.opacity(0.3)
        } else {
            // Light mode: use lighter gray
            defaultGrayColor = Color.gray.opacity(0.15)
        }
        
        // Create basic options for characters that don't have them yet
        for name in characters where characterOptions[name] == nil {
            characterOptions[name] = CharacterOptions(
                voiceID: "", // Will be assigned in assignUniqueVoices
                highlight: SerializableColor(defaultGrayColor)
            )
        }
        
        // Assign unique voices to all characters
        assignUniqueVoices()
        
    }

    // MARK: - Update highlight colors when selection changes
    private func updateHighlightColors() {
            // Carefully selected colors that are visually very distinct from each other
            let allColors: [Color] = [
                Color.red,                                    // Bright red
                Color.blue,                                   // Bright blue
                Color.green,                                  // Bright green
                Color.yellow,                                 // Bright yellow
                Color.purple,                                 // Bright purple
                Color.orange,                                 // Bright orange
                Color.pink,                                   // Bright pink
                Color.cyan,                                   // Bright cyan
                Color.brown,                                  // Brown
                Color.gray,                                   // Gray
                Color(red: 0.0, green: 0.0, blue: 0.0),     // Black
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
            
            // Get only the selected characters in a consistent order
            let selectedCharactersList = characters.filter { character in
                selectedCharacters.contains(where: { $0.caseInsensitiveCompare(character) == .orderedSame })
            }
            
            // Determine the appropriate gray color based on color scheme
            let nonSelectedGrayColor: Color
            if colorScheme == .dark {
                // Dark mode: use darker gray
                nonSelectedGrayColor = Color.gray.opacity(0.3)
            } else {
                // Light mode: use lighter gray
                nonSelectedGrayColor = Color.gray.opacity(0.15)
            }
            
            // First, set all characters to appropriate gray
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
        
        // Stop any speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("🛑 Stopped speaking")
        }
        synthesizer.delegate = nil
        speechDelegate = nil
        
        // Move index back OR stay at current if at beginning
        if currentUtteranceIndex > startingLineIndex {
            currentUtteranceIndex -= 1
            resetHintForNewLine()
            print("⬅️ Moved back to index: \(currentUtteranceIndex)")
        } else {
            print("🔄 At starting line (\(startingLineIndex)), staying at current line ready to restart at index: \(currentUtteranceIndex)")
            // Stay at same index - when user presses play it will restart this line
        }
        
        // Update states
        updateProgress()
        updateUserLineState()
        
        // Stay paused
        isPaused = true
        isSpeaking = false
        
        print("✅ Paused skip back complete - index: \(currentUtteranceIndex), isPaused: \(isPaused)")
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
            print("🔄 At starting line (\(startingLineIndex)), will restart current line at index: \(currentUtteranceIndex)")
            // Stay at same index but we'll restart it below
        }
        
        // Update states
        updateProgress()
        updateUserLineState()
        
        // Start speaking immediately if not user line
        isPaused = false
        isSpeaking = false
        
        if !isUserLine {
            print("🎬 About to call speakLineForUnpausedSkip() for restart/previous line")
            speakLineForUnpausedSkip()
            print("🎬 Called speakLineForUnpausedSkip()")
        } else {
            print("👤 Line is user's line - waiting for user")
        }
        
        print("✅ Unpaused skip back complete - index: \(currentUtteranceIndex), speaking: \(!isUserLine)")
    }

    private func skipForwardWhileUnpaused() {
        print("▶️ Skipping forward while unpaused")
        
        // Stop current speech
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
        
        // Start speaking immediately if not user line
        isPaused = false
        isSpeaking = false
        
        if !isUserLine {
            speakLineForUnpausedSkip()
        }
        
        print("✅ Unpaused skip forward complete - index: \(currentUtteranceIndex), speaking: \(!isUserLine)")
    }
    
    // Special speech function ONLY for unpaused skips
    private func speakLineForUnpausedSkip() {
        guard currentUtteranceIndex < dialogue.count else {
            showScriptCompletionAlert = true
            return
        }

        let entry = dialogue[currentUtteranceIndex]
        print("🎭 Speaking after unpaused skip - character: \(entry.character), index: \(currentUtteranceIndex)")
        
        // Give synthesizer a moment to settle after stop/clear operations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let utterance = AVSpeechUtterance(string: entry.line)

            if let id = self.characterOptions[entry.character]?.voiceID,
               let voice = AVSpeechSynthesisVoice(identifier: id) {
                utterance.voice = voice
            }
            utterance.postUtteranceDelay = 0.5

            // Set up normal delegate
            let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
                print("🔔 Speech delegate fired normally - incrementing from \(currentUtteranceIndex)")
                currentUtteranceIndex += 1
                updateProgress()
                startNextLine()
            }
            self.speechDelegate = delegate
            self.synthesizer.delegate = delegate
            self.synthesizer.speak(utterance)
            
            print("🗣️ Started speaking line after short delay")
        }
    }
    
    
    // MARK: - Skip Helper Functions
    private func updateUserLineState() {
        guard currentUtteranceIndex < dialogue.count else {
            isUserLine = false
            return
        }
        
        let entry = dialogue[currentUtteranceIndex]
        if selectedCharacters.contains("Not Applicable") {
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

            let convertedScript = convertScriptToCorrectFormat(from: fileContent)
            self.dialogue = self.extractDialogue(from: convertedScript)

            if dialogue.isEmpty {
                print("⚠️ The file is empty or has no valid lines with a colon.")
            }

            let extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
            self.characters = extractedCharacters
            ensureCharacterOptions()
            updateHighlightColors() // Set initial colors

            

            self.uploadedFileName = url.lastPathComponent
            self.hasUploadedFile = true
            self.hasPressedContinue = false
        } catch {
            self.fileContent = "Error loading file content."
            print("❌ Error loading file content: \(error.localizedDescription)")
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
        if selectedCharacters.contains("Not Applicable") {
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
        let utterance = AVSpeechUtterance(string: text)

        // Apply the user-picked voice if one is set
        if let id = characterOptions[character]?.voiceID,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        }
        utterance.postUtteranceDelay = 0.5

        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
            currentUtteranceIndex += 1
            updateProgress()
            startNextLine()
        }
        speechDelegate = delegate
        synthesizer.delegate = delegate
        synthesizer.speak(utterance)
    }
    
    private func updateProgress() {
        if let script = currentSavedScript {
            let updatedScript = SavedScript(
                id: script.id,
                title: script.title,
                rawText: script.rawText,
                settings: script.settings,
                progressIndex: currentUtteranceIndex,
                dateSaved: script.dateSaved
            )
            libraryManager.update(updatedScript)
            currentSavedScript = updatedScript
        }
    }

    func pauseOrResumeSpeech() {
        print("🎵 Pause/Resume called - isSpeaking: \(synthesizer.isSpeaking), isPaused: \(isPaused)")
        
        if synthesizer.isSpeaking {
            if isPaused {
                // Resume
                print("▶️ Resuming...")
                synthesizer.continueSpeaking()
                isPaused = false
                print("▶️ Resumed - isPaused now: \(isPaused)")
            } else {
                // Pause
                print("⏸️ Pausing...")
                synthesizer.pauseSpeaking(at: .word)
                isPaused = true
                print("⏸️ Paused - isPaused now: \(isPaused)")
            }
        } else {
            // If not speaking, start from current line
            print("🎬 Not speaking - starting from current line")
            isPaused = false
            startNextLine()
            print("🎬 Started - isPaused now: \(isPaused)")
        }
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
    
    // MARK: - Library Integration Functions
    private func saveCurrentScript() {
        let settings = ScriptSettings(
            selectedCharacters: Array(selectedCharacters),
            displayLinesAsRead: displayLinesAsRead,
            displayMyLines: displayMyLines
        )
        
        let script = SavedScript(
            id: currentSavedScript?.id ?? UUID(),
            title: uploadedFileName,
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
    }
    
    private func loadScript(from script: SavedScript) {
        // Load script content
        fileContent = script.rawText
        uploadedFileName = script.title
        
        // Convert and extract dialogue
        let convertedScript = convertScriptToCorrectFormat(from: fileContent)
        dialogue = extractDialogue(from: convertedScript)
        characters = Array(Set(dialogue.map { $0.character })).sorted()
        ensureCharacterOptions()
        
        // Load settings
        selectedCharacters = Set(script.settings.selectedCharacters)
        displayLinesAsRead = script.settings.displayLinesAsRead
        displayMyLines = script.settings.displayMyLines
        
        // Set progress
        currentUtteranceIndex = script.progressIndex
        
        // Update state
        currentSavedScript = script
        hasUploadedFile = true
        hasPressedContinue = true
        isShowingCharacterCustomization = true
        isCharacterSelected = true
        isShowingSplash = false
        
        // Initialize speech if we're in the script reading view
        if isCharacterSelected {
            initializeSpeech()
        }
    }
}

/// Holds the per-character voice & highlight that the user chooses
struct CharacterOptions: Codable {
    var voiceID: String
    var highlight: SerializableColor      // instead of Color
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
