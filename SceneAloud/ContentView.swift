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

// MARK: - Model used by the Library overlay
struct ScriptRecord: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let content: String
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

    // Unified alert enum
    enum AlertType: Identifiable {
        case noCharacterSelected
        case displayLinesInfo
        case notApplicableInfo
        case displayMyLinesInfo

        var id: Int {
            switch self {
            case .noCharacterSelected: return 0
            case .displayLinesInfo: return 1
            case .notApplicableInfo: return 2
            case .displayMyLinesInfo: return 3
            }
        }
    }

    @State private var activeAlert: AlertType? = nil

    @State private var isShowingDocumentPicker: Bool = false
    @State private var selectedFileURL: URL? = nil
    @State private var hasUploadedFile: Bool = false
    @State private var hasPressedContinue: Bool = false
    @State private var uploadedFileName: String = ""
    @State private var inputType: ScriptInputType = .text  // Default to text file input
    @State private var splashPlayer = AVPlayer()
    @State private var videoFinished = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLibraryOpen: Bool = false
    @State private var selectedLibraryItem: ScriptRecord? = nil   // ScriptRecord is your model

@ViewBuilder private var mainBody: some View {
        ZStack(alignment: .leading) {
            NavigationView {
        if isShowingSplash {
                ZStack {
                    // Full-screen background so taps register everywhere
                    Color(colorScheme == .dark ? .black : .white)
                        .ignoresSafeArea()

                    // Overlay content: welcome text at the top and bottom section with credits
                    VStack {
                        // Top-aligned welcome text
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

                        // Bottom section: credits
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)     // Fill entire screen
                .contentShape(Rectangle())                              // Make blank areas tappable
                .onTapGesture {
                    isShowingSplash = false
                }
            } else if !hasUploadedFile {
                // MARK: Upload/Input Page
                VStack(spacing: 20) {
                    Text("Upload Your Script")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 20)

                    Text("Is your script a PDF, a text file, or will you type it?")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // Picker to select the input type
                    Picker("Script Input Type", selection: $inputType) {
                        ForEach(ScriptInputType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 40)

                    // Show appropriate view based on inputType
                    if inputType == .typed {
                        // For typed input, show a TextEditor.
                        TextEditor(text: $fileContent)
                            .frame(height: 200)
                            .border(Color.gray, width: 1)
                            .padding(.horizontal, 40)

                        Button(action: {
                            // First, convert the script text to the correct format.
                            let convertedScript = convertScriptToCorrectFormat(from: fileContent)
                            // Then extract the dialogue.
                            self.dialogue = self.extractDialogue(from: convertedScript)
                            let extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
                            self.characters = extractedCharacters
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
                    } else if inputType == .pdf {
                        // For PDF input, show a message with a ChatGPT prompt instead of allowing PDF uploads.
                        VStack(spacing: 20) {
                            Text("Hello! To keep this app free, PDF conversion isn’t supported. Instead, copy the prompt below into ChatGPT or Claude AI(or any similar AI tool) and attach your script PDF to convert your PDF to a text file for free.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)

                            Button(action: {
                                        UIPasteboard.general.string = """
                                        I have a PDF file attached that contains the script for a play.  The script contains scene descriptions, parenthetical notations, and most importantly, the lines each character should read.  Scene descriptions will often be written in italics.

                                        Your job is to extract the character lines, and nothing else.   It is important for you to extract all of the lines until you reach the end of the play.  The end of the play will often be indicated by "END OF PLAY" or something similar.

                                        Please return the lines in the following format:

                                        "Character name: Line"

                                        If the text in the PDF isn’t extractable using standard methods, please use OCR to extract the text from the pages.
                                        If the process takes too long and is interrupted, to make this more manageable, extract the character lines one page at a time.

                                        You do not need to ask me if it is ok to use more sophisticated OCR techniques, and you don’t need to ask me each time you finish a page.
                                        I want you to extract all of the lines until you reach the end of the play.  If you need to do this page by page, do so without asking me if it’s ok.

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
                    } else {
                        // For text file input, show the file selection button.
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

                    Spacer()
                }
                .padding()
            } else if !hasPressedContinue {       // NEW Continue page
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
                            // Remove the uploaded script and return to the original upload screen
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
            } else if !isCharacterSelected {
                // MARK: Settings Page
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading) {
                            Text("Settings")
                                .font(.largeTitle)
                                .bold()

                            Text("Select your characters")
                                .font(.title2)
                                .padding(.vertical, 5)

                            // Not Applicable row with info button (moved after label)
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

                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Display lines as read")
                                        .font(.title2)
                                    Button(action: {
                                        activeAlert = .displayLinesInfo
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

                            // "Display my lines" row with info button and toggle, disable if Not Applicable is selected
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
                                Spacer()
                                Toggle("", isOn: $displayMyLines)
                                    .labelsHidden()
                                    .disabled(selectedCharacters.contains("Not Applicable"))
                            }
                            .padding(.vertical, 2)

                            Spacer()

                            Button(action: {
                                if selectedCharacters.isEmpty {
                                    activeAlert = .noCharacterSelected
                                } else {
                                    isCharacterSelected = true
                                    print("✅ Characters Selected: \(selectedCharacters)")
                                }
                            }) {
                                Text("Done")
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
                        .padding(.top, -8)
                    }
                }
                .alert(item: $activeAlert) { alert in
                    switch alert {
                    case .noCharacterSelected:
                        return Alert(
                            title: Text("No Character Selected"),
                            message: Text("Please select at least one character to continue."),
                            dismissButton: .default(Text("OK")) {
                                activeAlert = nil
                            }
                        )
                    case .displayLinesInfo:
                        return Alert(
                            title: Text("Display Lines Info"),
                            message: Text("The display lines as read option shows all of the script when turned off. When turned on lines will only appear as they are read, making it easier to follow."),
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
                            message: Text("When selected, Display My Lines will display the lines of the character the user has selected to play. When it is not selected, the user will be prompted when it is their line, but they will not be shown it."),
                            dismissButton: .default(Text("OK")) {
                                activeAlert = nil
                            }
                        )
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            // Jump back to the Continue screen but keep the uploaded script info
                            hasPressedContinue = false
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isLibraryOpen.toggle() }) {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Settings")
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                    }
                }
                // Automatically set displayMyLines = false if Not Applicable is selected
                .onChange(of: selectedCharacters) { _, newValue in
                    if newValue.contains("Not Applicable") {
                        displayMyLines = false
                    }
                }
            } else {
                // MARK: Script Reading Page
                VStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(dialogue.indices, id: \.self) { index in
                                    let entry = dialogue[index]

                                    if displayLinesAsRead {
                                        if index <= currentUtteranceIndex {
                                            lineView(for: entry, at: index)
                                        }
                                    } else {
                                        lineView(for: entry, at: index)
                                    }
                                }
                            }
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

                    VStack {
                        if isUserLine {
                            Button(action: {
                                userLineFinished()
                            }) {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        } else {
                            Button(action: pauseOrResumeSpeech) {
                                Text(isPaused ? "Resume" : "Pause")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isPaused ? Color.green : Color.yellow)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .navigationTitle("SceneAloud")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            restartScript(keepSettings: false)
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { isLibraryOpen.toggle() }) {
                            Image(systemName: "line.3.horizontal")
                        }
                    }
                }
                .onAppear(perform: initializeSpeech)
            }
        }
            .navigationBarHidden(isShowingSplash)
            .overlay(                                // slide‑in panel
                HamburgerOverlay(isOpen: $isLibraryOpen,
                                 selectedItem: $selectedLibraryItem)
                    .frame(maxWidth: 300)
                    .offset(x: isLibraryOpen ? 0 : -300)
            )
        }   // END NavigationView
        .alert(isPresented: $showScriptCompletionAlert) {
            Alert(
                title: Text("You’ve reached the end!"),
                message: Text("Would you like to keep the same settings or change your settings?"),
                primaryButton: .default(Text("Keep Settings")) {
                    restartScript(keepSettings: true)
                },
                secondaryButton: .default(Text("Change Settings")) {
                    restartScript(keepSettings: false)
                }
            )
        }
        .onChange(of: selectedLibraryItem) { _, newValue in
            if let record = newValue {
                loadScript(from: record)
                isLibraryOpen = false
            }
        }
    }
    var body: some View {
        mainBody
    }


    // MARK: Script Conversion Function
    // MARK: - Script Conversion Function
    func convertScriptToCorrectFormat(from text: String) -> String {
        // Split the text into individual lines
        let lines = text.components(separatedBy: .newlines)
        var convertedLines: [String] = []
        var i = 0

        while i < lines.count {
            // Trim whitespace and remove any parenthetical text
            var currentLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            currentLine = currentLine.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)

            // Skip empty lines
            if currentLine.isEmpty {
                i += 1
                continue
            }

            // Skip lines that are likely scene numbers (e.g. lines containing only digits)
            let digitSet = CharacterSet.decimalDigits
            let currentCharacterSet = CharacterSet(charactersIn: currentLine)
            if digitSet.isSuperset(of: currentCharacterSet) {
                i += 1
                continue
            }

            // If the current line is all uppercase and does not contain a colon, assume it's a character name
            if currentLine == currentLine.uppercased() && !currentLine.contains(":") {
                // Check if there's a following line for dialogue
                if i + 1 < lines.count {
                    var nextLine = lines[i+1].trimmingCharacters(in: .whitespacesAndNewlines)
                    nextLine = nextLine.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)

                    // If the next line is not empty and is not all uppercase, combine them
                    if !nextLine.isEmpty && nextLine != nextLine.uppercased() {
                        let combinedLine = "\(currentLine): \(nextLine)"
                        convertedLines.append(combinedLine)
                        i += 2
                        continue
                    }
                }
            }

            // If the line already contains a colon, assume it's in the correct format
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
                // (Your PDF extraction code here)
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
                // For text files, load the content as before.
                self.fileContent = try String(contentsOf: url, encoding: .utf8)
            }

            // Convert the file content to the correct format before extracting dialogue.
            let convertedScript = convertScriptToCorrectFormat(from: fileContent)
            self.dialogue = self.extractDialogue(from: convertedScript)

            if dialogue.isEmpty {
                print("⚠️ The file is empty or has no valid lines with a colon.")
            }

            let extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
            self.characters = extractedCharacters

            print("✅ Characters Loaded: \(characters)")

            self.uploadedFileName = url.lastPathComponent
            self.hasUploadedFile = true
            self.hasPressedContinue = false
        } catch {
            self.fileContent = "Error loading file content."
            print("❌ Error loading file content: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func lineView(for entry: (character: String, line: String), at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.character)
                .font(.headline)
                .foregroundColor(.primary)

            if selectedCharacters.contains("Not Applicable") {
                Text(entry.line)
                    .font(.body)
                    .padding(5)
                    .background(
                        index == currentUtteranceIndex ? Color.yellow.opacity(0.7) : Color.clear
                    )
                    .cornerRadius(5)
            } else if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
                if displayMyLines {
                    // Show user's line, never spoken
                    Text(entry.line)
                        .font(.body)
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            index == currentUtteranceIndex ? colorForCharacter(entry.character).opacity(0.7) : Color.clear
                        )
                        .cornerRadius(5)
                } else {
                    Text("It’s your line! Press to continue.")
                        .font(.body)
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            index == currentUtteranceIndex ? colorForCharacter(entry.character).opacity(0.7) : Color.clear
                        )
                        .cornerRadius(5)
                }
            } else {
                Text(entry.line)
                    .font(.body)
                    .padding(5)
                    .background(
                        index == currentUtteranceIndex ? Color.yellow.opacity(0.7) : Color.clear
                    )
                    .cornerRadius(5)
            }
        }
        .padding(.bottom, 5)
        .id(index)
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

    // MARK: - Speech
    func initializeSpeech() {
        currentUtteranceIndex = 0
        isSpeaking = false
        isPaused = false

        synthesizer = AVSpeechSynthesizer()
        speechDelegate = nil

        startNextLine()
    }

    private func startNextLine() {
        guard currentUtteranceIndex < dialogue.count else {
            showScriptCompletionAlert = true
            return
        }

        let entry = dialogue[currentUtteranceIndex]
        if selectedCharacters.contains("Not Applicable") {
            isUserLine = false
            speakLine(entry.line)
        } else if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
            if displayMyLines {
                // Show user's line, never spoken
                isUserLine = true
                // Do NOT speak the line
            } else {
                // Prompt user, do not show line, do not speak
                isUserLine = true
            }
        } else {
            isUserLine = false
            speakLine(entry.line)
        }
    }

    private func userLineFinished() {
        currentUtteranceIndex += 1
        startNextLine()
    }

    private func speakLine(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.postUtteranceDelay = 0.5

        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
            currentUtteranceIndex += 1
            startNextLine()
        }
        speechDelegate = delegate
        synthesizer.delegate = delegate

        synthesizer.speak(utterance)
    }

    func pauseOrResumeSpeech() {
        guard synthesizer.isSpeaking else { return }
        if isPaused {
            isPaused = false
            synthesizer.continueSpeaking()
        } else {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
        }
    }

    private func restartScript(keepSettings: Bool) {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.delegate = nil

        currentUtteranceIndex = 0
        isUserLine = false

        if keepSettings {
            initializeSpeech()
        } else {
            isCharacterSelected = false
            selectedCharacters = []
            displayLinesAsRead = true
        }
    }

    func colorForCharacter(_ character: String) -> Color {
        let colors: [Color] = [.orange, .blue, .pink, .purple, .red, .teal]
        let sortedSelections = selectedCharacters.sorted()
        if let index = sortedSelections.firstIndex(of: character) {
            return colors[index % colors.count]
        }
        return Color.gray
    }
    
    private func loadScript(from record: ScriptRecord) {
        fileContent = record.content
        let convertedScript = convertScriptToCorrectFormat(from: fileContent)
        dialogue = extractDialogue(from: convertedScript)
        characters = Array(Set(dialogue.map { $0.character })).sorted()
        selectedCharacters = []
        uploadedFileName = record.fileName
        hasUploadedFile = true
        hasPressedContinue = false
        isShowingSplash = false
    }
}   // END ZStack


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

