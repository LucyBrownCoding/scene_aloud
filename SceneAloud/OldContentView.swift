//import SwiftUI
//import AVFoundation
//
//struct ContentView: View {
//    // MARK: - State Variables
//    @State private var fileContent: String = ""
//    @State private var dialogue: [(character: String, line: String)] = []
//    @State private var characters: [String] = []
//    @State private var selectedCharacter: String?
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
//    // We store lines displayed on screen
//    @State private var visibleLines: [(character: String, line: String)] = []
//
//    // When the script completes, show an alert
//    @State private var showScriptCompletionAlert: Bool = false
//
//    // Toggle for displaying lines as read
//    @State private var displayLinesAsRead: Bool = true
//
//    // MARK: - Main Body
//    var body: some View {
//        NavigationView {
//            if !isCharacterSelected {
//                VStack(alignment: .leading) {
//                    // Settings Header
//                    Text("Settings")
//                        .font(.largeTitle)
//                        .bold()
//                        .padding(.top, 20)
//
//                    // Group the character picker and toggle into a single block
//                    VStack(alignment: .leading, spacing: 30) {
//                        // Select a Character
//                        VStack(alignment: .leading, spacing: 10) {
//                            Text("Select a Character")
//                                .font(.title2)
//
//                            Picker("Choose your character", selection: $selectedCharacter) {
//                                ForEach(characters, id: \.self) { character in
//                                    Text(character.capitalized)
//                                        .tag(character as String?)
//                                }
//                            }
//                            .pickerStyle(WheelPickerStyle())
//                            .frame(height: 120)
//                            .clipped()
//                        }
//
//                        // Toggle Display Lines
//                        VStack(alignment: .leading, spacing: 10) {
//                            Text("Display lines as read")
//                                .font(.title2)
//
//                            Toggle("", isOn: $displayLinesAsRead)
//                                .labelsHidden()
//                        }
//                    }
//                    .padding(.top, 20) // Additional spacing between header and settings
//
//                    // Spacer can be smaller or removed if you want less gap before "Done"
//                    Spacer()
//
//                    // Done Button
//                    Button(action: {
//                        if let selected = selectedCharacter {
//                            print("✅ Character Selected: \(selected)")
//                            isCharacterSelected = true
//                        }
//                    }) {
//                        Text("Done")
//                            .font(.headline)
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(selectedCharacter == nil ? Color.gray : Color.blue)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                    .disabled(selectedCharacter == nil)
//                    .padding(.bottom, 20)
//                }
//                .padding(.horizontal, 20)
//                .frame(maxHeight: .infinity, alignment: .top)
//            } else {
//                // Script Reading Screen
//                VStack {
//                    ScrollViewReader { proxy in
//                        ScrollView {
//                            VStack(alignment: .leading, spacing: 10) {
//                                ForEach(dialogue.indices, id: \.self) { index in
//                                    let entry = dialogue[index]
//
//                                    if displayLinesAsRead {
//                                        // Display lines up to the current utterance
//                                        if index <= currentUtteranceIndex {
//                                            lineView(for: entry, at: index)
//                                        }
//                                    } else {
//                                        // Display all lines
//                                        lineView(for: entry, at: index)
//                                    }
//                                }
//                            }
//                            .padding()
//                            .onChange(of: currentUtteranceIndex) {
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
//                .onAppear(perform: initializeSpeech)
//            }
//        }
//        .onAppear(perform: loadFileContent)
//        .alert(isPresented: $showScriptCompletionAlert) {
//            Alert(
//                title: Text("You’ve reached the end!"),
//                message: Text("Would you like to keep the same settings or change your settings?"),
//                primaryButton: .default(Text("Keep Settings")) {
//                    // Restart script with the same character and toggle
//                    restartScript(keepSettings: true)
//                },
//                secondaryButton: .default(Text("Change Settings")) {
//                    // Go back to the settings screen so user can modify character/toggle
//                    restartScript(keepSettings: false)
//                }
//            )
//        }
//    }
//
//    // MARK: - Helper View
//    @ViewBuilder
//    private func lineView(for entry: (character: String, line: String), at index: Int) -> some View {
//        VStack(alignment: .leading, spacing: 4) {
//            Text(entry.character)
//                .font(.headline)
//                .foregroundColor(.primary)
//
//            if entry.character == selectedCharacter {
//                Text("It’s your line! Press to continue.")
//                    .font(.body)
//                    .padding(5)
//                    .background(
//                        index == currentUtteranceIndex ? Color.yellow.opacity(0.7) : Color.clear
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
//    // MARK: - Loading Data
//    func loadFileContent() {
//        if let filePath = Bundle.main.path(forResource: "cinderella", ofType: "txt") {
//            do {
//                let content = try String(contentsOfFile: filePath, encoding: .utf8)
//                self.fileContent = content
//                self.dialogue = self.extractDialogue(from: content)
//
//                if dialogue.isEmpty {
//                    print("⚠️ The file is empty or has no valid lines with a colon.")
//                }
//
//                self.characters = Array(Set(dialogue.map { $0.character })).sorted()
//                // Optionally, you could reset the default selected character here
//                if let firstCharacter = characters.first {
//                    self.selectedCharacter = firstCharacter
//                }
//
//                print("✅ Characters Loaded: \(characters)")
//            } catch {
//                self.fileContent = "Error loading file content."
//                print("❌ Error loading file content: \(error.localizedDescription)")
//            }
//        } else {
//            self.fileContent = "File not found."
//            print("❌ File not found in bundle.")
//        }
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
//    func initializeSpeech() {
//        currentUtteranceIndex = 0
//        visibleLines = []
//        isSpeaking = false
//        isPaused = false
//        synthesizer = AVSpeechSynthesizer()
//        speechDelegate = nil
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
//        visibleLines.append(entry)
//
//        if entry.character == selectedCharacter {
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
//
//        speechDelegate = delegate
//        synthesizer.delegate = delegate
//
//        synthesizer.stopSpeaking(at: .immediate)
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
//        visibleLines.removeAll()
//        currentUtteranceIndex = 0
//        isUserLine = false
//
//        if keepSettings {
//            // Keep the same character and toggle values
//            initializeSpeech()
//        } else {
//            // Allow user to modify settings again
//            isCharacterSelected = false
//            // Optionally reset toggle or character to nil if you prefer a "fresh" start
//            // selectedCharacter = nil
//            // displayLinesAsRead = true
//        }
//    }
//}
//
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
