//import SwiftUI
//import AVFoundation
//import UIKit
//
//struct ContentView: View {
//    // MARK: - State Variables
//    @State private var isShowingSplash: Bool = true
//    @State private var fileContent: String = ""
//    @State private var dialogue: [(character: String, line: String)] = []
//    @State private var characters: [String] = []
//    // Replace single-character selection with a set for multi-selection
//    @State private var selectedCharacters: Set<String> = []
//    @State private var isCharacterSelected: Bool = false
//
//    // Track the line reading state
//    @State private var currentUtteranceIndex: Int = 0
//    @State private var isSpeaking: Bool = false
//    @State private var isPaused: Bool = false
//
//    // This flag indicates whether the current line belongs to the user
//    @State private var isUserLine: Bool = false
//
//    // Synthesis
//    @State private var synthesizer = AVSpeechSynthesizer()
//    @State private var speechDelegate: AVSpeechSynthesizerDelegateWrapper?
//
//    // When the script completes, show an alert
//    @State private var showScriptCompletionAlert: Bool = false
//
//    // Toggle for displaying lines as read
//    @State private var displayLinesAsRead: Bool = true
//
//    // MARK: - New State Variables for File Upload
//    @State private var isShowingDocumentPicker: Bool = false
//    @State private var selectedFileURL: URL? = nil
//    @State private var hasUploadedFile: Bool = false
//
//    var body: some View {
//        NavigationView {
//            if isShowingSplash {
//                // MARK: Splash Screen
//                ZStack {
//                    VStack {
//                        Spacer(minLength: 20)
//                        // Logo and Welcome Text Group
//                        VStack(spacing: 10) {
//                            // Replace static image with your Lottie animation if needed
//                            Image("SplashLogo")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 250, height: 250)
//
//                            // Welcome Message
//                            VStack(alignment: .center, spacing: 5) {
//                                Text("Welcome to")
//                                    .font(.system(size: 40, weight: .bold))
//                                    .multilineTextAlignment(.center)
//
//                                Text("SceneAloud!")
//                                    .font(.system(size: 40, weight: .bold))
//                                    .multilineTextAlignment(.center)
//                                    .padding(.top, 5)
//                            }
//                            
//                            // Instruction Text
//                            Text("Tap the screen to continue")
//                                .font(.body)
//                                .padding()
//                                .cornerRadius(10)
//                                .padding(.top, 0)
//                        }
//                        Spacer()
//                        VStack(spacing: 5) {
//                            Text("Created by Lucy Brown")
//                            Text("Sound Design and Logo by Abrielle Smith")
//                        }
//                        .font(.footnote)
//                        .foregroundColor(.gray)
//                        .padding(.bottom, 20)
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .background(Color(UIColor.systemBackground))
//                }
//                .onTapGesture {
//                    #if os(iOS)
//                    withAnimation {
//                        isShowingSplash = false
//                    }
//                    #endif
//                }
//            } else if !hasUploadedFile {
//                // MARK: Upload Page
//                VStack(spacing: 20) {
//                    Text("Upload Your Script")
//                        .font(.largeTitle)
//                        .bold()
//                        .padding(.top, 40)
//
//                    Text("Please upload a text file (.txt) that follows the required format.")
//                        .font(.body)
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal, 40)
//
//                    // Upload Button
//                    Button(action: {
//                        isShowingDocumentPicker = true
//                    }) {
//                        HStack {
//                            Image(systemName: "doc.text.fill")
//                                .font(.title)
//                            Text("Select Script File")
//                                .font(.headline)
//                        }
//                        .padding()
//                        .foregroundColor(.white)
//                        .background(Color.blue)
//                        .cornerRadius(10)
//                    }
//                    .sheet(isPresented: $isShowingDocumentPicker) {
//                        DocumentPicker(filePath: $selectedFileURL)
//                    }
//                    .onChange(of: selectedFileURL) { _, newValue in
//                        if let url = newValue {
//                            handleFileSelection(url: url)
//                        }
//                    }
//                    
//                    Spacer()
//                }
//                .padding()
//            } else if !isCharacterSelected {
//                // MARK: Settings Page
//                VStack(alignment: .leading) {
//                    // Settings Header
//                    Text("Settings")
//                        .font(.largeTitle)
//                        .bold()
//                        .padding(.top, 20)
//                    
//                    // Multi-selection of characters
//                    Text("Select your characters")
//                        .font(.title2)
//                        .padding(.vertical, 5)
//                    
//                    // Instead of a Picker, we display a list of toggles for each character.
//                    ForEach(characters, id: \.self) { character in
//                        Toggle(character.capitalized, isOn: Binding(
//                            get: { selectedCharacters.contains(character) },
//                            set: { newValue in
//                                if newValue {
//                                    selectedCharacters.insert(character)
//                                } else {
//                                    selectedCharacters.remove(character)
//                                }
//                            }
//                        ))
//                        .padding(.vertical, 2)
//                    }
//                    
//                    // Toggle Display Lines
//                    VStack(alignment: .leading, spacing: 10) {
//                        Text("Display lines as read")
//                            .font(.title2)
//                        
//                        Toggle("", isOn: $displayLinesAsRead)
//                            .labelsHidden()
//                    }
//                    .padding(.top, 20)
//                    
//                    Spacer()
//                    
//                    // Done Button
//                    Button(action: {
//                        // Move on to the script reading page
//                        // You might want to enforce at least one character selection here.
//                        isCharacterSelected = true
//                        print("✅ Characters Selected: \(selectedCharacters)")
//                    }) {
//                        Text("Done")
//                            .font(.headline)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.blue)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                    .padding(.bottom, 20)
//                }
//                .padding(.horizontal, 20)
//                .frame(maxHeight: .infinity, alignment: .top)
//                .navigationTitle("Settings")
//                .navigationBarTitleDisplayMode(.inline)
//                .toolbar {
//                    // === New "Back to Upload" button ===
//                    ToolbarItem(placement: .navigationBarLeading) {
//                        Button(action: {
//                            hasUploadedFile = false
//                            selectedFileURL = nil
//                        }) {
//                            HStack {
//                                Image(systemName: "arrow.left")
//                                Text("Back to Upload")
//                            }
//                        }
//                    }
//                }
//            } else {
//                // MARK: Script Reading Page
//                VStack {
//                    ScrollViewReader { proxy in
//                        ScrollView {
//                            VStack(alignment: .leading, spacing: 10) {
//                                ForEach(dialogue.indices, id: \.self) { index in
//                                    let entry = dialogue[index]
//                                    
//                                    if displayLinesAsRead {
//                                        if index <= currentUtteranceIndex {
//                                            lineView(for: entry, at: index)
//                                        }
//                                    } else {
//                                        lineView(for: entry, at: index)
//                                    }
//                                }
//                            }
//                            .padding()
//                            .onChange(of: currentUtteranceIndex) { _ in
//                                withAnimation {
//                                    proxy.scrollTo(currentUtteranceIndex, anchor: .top)
//                                }
//                            }
//                        }
//                        .background(Color(UIColor.systemBackground))
//                    }
//                    .background(Color(UIColor.systemBackground))
//                    
//                    // Action Buttons
//                    VStack {
//                        if isUserLine {
//                            Button(action: {
//                                userLineFinished()
//                            }) {
//                                Text("Continue")
//                                    .font(.headline)
//                                    .frame(maxWidth: .infinity)
//                                    .padding()
//                                    .background(Color.orange)
//                                    .foregroundColor(.white)
//                                    .cornerRadius(10)
//                            }
//                            .padding(.horizontal)
//                        } else {
//                            Button(action: pauseOrResumeSpeech) {
//                                Text(isPaused ? "Resume" : "Pause")
//                                    .font(.headline)
//                                    .frame(maxWidth: .infinity)
//                                    .padding()
//                                    .background(isPaused ? Color.green : Color.yellow)
//                                    .foregroundColor(.white)
//                                    .cornerRadius(10)
//                            }
//                            .padding(.horizontal)
//                        }
//                    }
//                    .padding(.bottom, 20)
//                }
//                .navigationTitle("SceneAloud")
//                .navigationBarTitleDisplayMode(.inline)
//                .toolbar {
//                    ToolbarItem(placement: .navigationBarLeading) {
//                        Button(action: {
//                            restartScript(keepSettings: false)
//                        }) {
//                            HStack {
//                                Image(systemName: "arrow.left")
//                                Text("Back")
//                            }
//                        }
//                    }
//                }
//                .onAppear(perform: initializeSpeech)
//            }
//        }
//        .alert(isPresented: $showScriptCompletionAlert) {
//            Alert(
//                title: Text("You’ve reached the end!"),
//                message: Text("Would you like to keep the same settings or change your settings?"),
//                primaryButton: .default(Text("Keep Settings")) {
//                    restartScript(keepSettings: true)
//                },
//                secondaryButton: .default(Text("Change Settings")) {
//                    restartScript(keepSettings: false)
//                }
//            )
//        }
//    }
//    
//    // MARK: - Helper Functions
//    
//    func handleFileSelection(url: URL) {
//        do {
//            let content = try String(contentsOf: url, encoding: .utf8)
//            self.fileContent = content
//            self.dialogue = self.extractDialogue(from: content)
//            
//            if dialogue.isEmpty {
//                print("⚠️ The file is empty or has no valid lines with a colon.")
//            }
//            
//            var extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
//            
//            // Commented out: remove the addition of "NA" (Not Applicable)
//            /*
//            if extractedCharacters.contains("NA") {
//                print("⚠️ Warning: 'NA' found in script characters. Removing to prevent conflicts.")
//                extractedCharacters.removeAll { $0 == "NA" }
//            }
//            */
//            
//            self.characters = extractedCharacters
//            
//            // Commented out the insertion of "NA" into characters list
//            /*
//            self.characters.insert("NA", at: 0)
//            if !self.characters.contains("NA") {
//                self.characters.insert("NA", at: 0)
//            }
//            */
//            
//            print("✅ Characters Loaded: \(characters)")
//            
//            self.hasUploadedFile = true
//        } catch {
//            self.fileContent = "Error loading file content."
//            print("❌ Error loading file content: \(error.localizedDescription)")
//        }
//    }
//    
//    @ViewBuilder
//    private func lineView(for entry: (character: String, line: String), at index: Int) -> some View {
//        VStack(alignment: .leading, spacing: 4) {
//            Text(entry.character)
//                .font(.headline)
//                .foregroundColor(.primary)
//            
//            // Check with case-insensitive comparison
//            if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
//                Text("It’s your line! Press to continue.")
//                    .font(.body)
//                    .padding(5)
//                    .frame(maxWidth: .infinity, alignment: .leading) // forces left alignment
//                    .background(
//                        index == currentUtteranceIndex ? colorForCharacter(entry.character).opacity(0.7) : Color.clear
//                    )
//                    .cornerRadius(5)
//            } else {
//                Text(entry.line)
//                    .font(.body)
//                    .padding(5)
//                    .background(
//                        index == currentUtteranceIndex ? Color.yellow.opacity(0.7) : Color.clear
//                    )
//                    .cornerRadius(5)
//            }
//        }
//        .padding(.bottom, 5)
//        .id(index)
//    }
//    
//    func extractDialogue(from text: String) -> [(character: String, line: String)] {
//        var extractedDialogue: [(String, String)] = []
//        let lines = text.split(separator: "\n")
//        
//        for line in lines {
//            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
//            guard let colonIndex = trimmedLine.firstIndex(of: ":") else {
//                continue
//            }
//            
//            let characterName = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
//            let content = trimmedLine[trimmedLine.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
//            
//            extractedDialogue.append((characterName, content))
//        }
//        
//        return extractedDialogue
//    }
//    
//    // MARK: - Speech
//    func initializeSpeech() {
//        currentUtteranceIndex = 0
//        isSpeaking = false
//        isPaused = false
//        
//        synthesizer = AVSpeechSynthesizer()
//        speechDelegate = nil
//        
//        startNextLine()
//    }
//    
//    private func startNextLine() {
//        guard currentUtteranceIndex < dialogue.count else {
//            showScriptCompletionAlert = true
//            return
//        }
//        
//        let entry = dialogue[currentUtteranceIndex]
//        // Use case-insensitive check for selected characters
//        if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
//            isUserLine = true
//        } else {
//            isUserLine = false
//            speakLine(entry.line)
//        }
//    }
//    
//    private func userLineFinished() {
//        currentUtteranceIndex += 1
//        startNextLine()
//    }
//    
//    private func speakLine(_ text: String) {
//        let utterance = AVSpeechUtterance(string: text)
//        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
//        utterance.postUtteranceDelay = 0.5
//        
//        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
//            currentUtteranceIndex += 1
//            startNextLine()
//        }
//        speechDelegate = delegate
//        synthesizer.delegate = delegate
//        
//        synthesizer.speak(utterance)
//    }
//    
//    func pauseOrResumeSpeech() {
//        guard synthesizer.isSpeaking else { return }
//        if isPaused {
//            isPaused = false
//            synthesizer.continueSpeaking()
//        } else {
//            synthesizer.pauseSpeaking(at: .word)
//            isPaused = true
//        }
//    }
//    
//    // MARK: - Restart Script
//    private func restartScript(keepSettings: Bool) {
//        synthesizer.stopSpeaking(at: .immediate)
//        synthesizer.delegate = nil
//        
//        currentUtteranceIndex = 0
//        isUserLine = false
//        
//        if keepSettings {
//            initializeSpeech()
//        } else {
//            isCharacterSelected = false
//            selectedCharacters = [] // Reset selection
//            displayLinesAsRead = true
//        }
//    }
//    
//    // MARK: - Color Mapping for Characters
//    func colorForCharacter(_ character: String) -> Color {
//        // Define a palette of colors excluding green and yellow.
//        let colors: [Color] = [.orange, .blue, .pink, .purple, .red, .teal]
//        // To have a consistent mapping, sort the selected characters.
//        let sortedSelections = selectedCharacters.sorted()
//        if let index = sortedSelections.firstIndex(of: character) {
//            return colors[index % colors.count]
//        }
//        return Color.gray
//    }
//}
//
//// MARK: - AVSpeechSynthesizerDelegateWrapper
//class AVSpeechSynthesizerDelegateWrapper: NSObject, AVSpeechSynthesizerDelegate {
//    private let completion: () -> Void
//    
//    init(completion: @escaping () -> Void) {
//        self.completion = completion
//    }
//    
//    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
//                           didFinish utterance: AVSpeechUtterance) {
//        completion()
//    }
//}
