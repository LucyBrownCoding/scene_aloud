import SwiftUI
import AVFoundation

struct ContentView: View {
    // MARK: - State Variables
    @State private var fileContent: String = ""
    @State private var dialogue: [(character: String, line: String)] = []
    @State private var characters: [String] = []
    @State private var selectedCharacter: String?
    @State private var isCharacterSelected: Bool = false

    // Track the line reading state
    @State private var currentUtteranceIndex: Int = 0
    @State private var isSpeaking: Bool = false
    @State private var isPaused: Bool = false

    // This flag indicates whether the current line belongs to the user
    @State private var isUserLine: Bool = false

    // Synthesis
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var speechDelegate: AVSpeechSynthesizerDelegateWrapper?

    // We store lines displayed on screen
    @State private var visibleLines: [(character: String, line: String)] = []

    // When the script completes, show an alert
    @State private var showScriptCompletionAlert: Bool = false

    // MARK: - Main Body
    var body: some View {
        NavigationView {
            if !isCharacterSelected {
                // Character Selection Screen
                VStack {
                    Text("Select a Character")
                        .font(.largeTitle)
                        .padding()

                    Picker("Choose your character", selection: $selectedCharacter) {
                        ForEach(characters, id: \.self) { character in
                            Text(character.capitalized)
                                .tag(character as String?)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .padding()

                    Button("Done") {
                        if let selected = selectedCharacter {
                            print("✅ Character Selected: \(selected)")
                            isCharacterSelected = true
                        }
                    }
                    // Button changes color & is enabled only if selectedCharacter != nil
                    .padding()
                    .background(selectedCharacter == nil ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(selectedCharacter == nil)
                }
            } else {
                // Script Reading Screen
                VStack {
                    // Display lines spoken so far
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(visibleLines.indices, id: \.self) { index in
                                let entry = visibleLines[index]
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.character)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    // If it's the user's line, show placeholder text
                                    if entry.character == selectedCharacter {
                                        Text("It’s your line! Press to continue.")
                                            .padding(5)
                                            .background(Color.yellow.opacity(0.7))
                                            .cornerRadius(5)
                                    } else {
                                        // Otherwise, show the actual spoken line
                                        Text(entry.line)
                                            .padding(5)
                                            .background(Color.yellow.opacity(0.7))
                                            .cornerRadius(5)
                                    }
                                }
                                .padding(.bottom, 10)
                            }
                        }
                        .padding()
                    }

                    // If it's currently the user's line, show a "Continue" button
                    if isUserLine {
                        Button(action: {
                            // The user has "finished" their line
                            userLineFinished()
                        }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    } else {
                        // Otherwise, show the "Pause/Resume" button for TTS
                        Button(action: pauseOrResumeSpeech) {
                            Text(isPaused ? "Resume" : "Pause")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isPaused ? Color.green : Color.yellow)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                .navigationTitle("SceneAloud")
                .onAppear(perform: initializeSpeech)
            }
        }
        // Load the file content immediately
        .onAppear(perform: loadFileContent)
        // Present an alert if the script has ended
        .alert(isPresented: $showScriptCompletionAlert) {
            Alert(
                title: Text("You’ve reached the end!"),
                message: Text("Would you like to restart with the same character, or choose a different one?"),
                primaryButton: .default(Text("Same Character")) {
                    restartScript(withSameCharacter: true)
                },
                secondaryButton: .default(Text("Different Character")) {
                    restartScript(withSameCharacter: false)
                }
            )
        }
    }

    // MARK: - Loading Data
    func loadFileContent() {
        // Attempt to locate cinderella.txt in your main bundle
        if let filePath = Bundle.main.path(forResource: "cinderella", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                self.fileContent = content
                // Extract dialogue lines from the file
                self.dialogue = self.extractDialogue(from: content)

                // Check if the file was essentially empty or had no valid lines
                if dialogue.isEmpty {
                    print("⚠️ The file is empty or has no valid lines with a colon.")
                }

                // Build a unique list of characters
                self.characters = Array(Set(dialogue.map { $0.character })).sorted()

                // Optionally auto-select the first character
                if let firstCharacter = characters.first {
                    self.selectedCharacter = firstCharacter
                }

                print("✅ Characters Loaded: \(characters)")
            } catch {
                self.fileContent = "Error loading file content."
                print("❌ Error loading file content: \(error.localizedDescription)")
            }
        } else {
            self.fileContent = "File not found."
            print("❌ File not found in bundle.")
        }
    }

    // MARK: - Extracting Data
    func extractDialogue(from text: String) -> [(character: String, line: String)] {
        var extractedDialogue: [(String, String)] = []
        let lines = text.split(separator: "\n")

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let colonIndex = trimmedLine.firstIndex(of: ":") else {
                print("⚠️ No colon found in line: \(trimmedLine)")
                continue
            }

            let characterName = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            let content = trimmedLine[trimmedLine.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)

            extractedDialogue.append((characterName, content))
        }

        return extractedDialogue
    }

    // MARK: - Speech / Line Handling
    func initializeSpeech() {
        // Start fresh
        currentUtteranceIndex = 0
        visibleLines = []
        isSpeaking = false
        isPaused = false

        // Create a fresh AVSpeechSynthesizer for safety
        synthesizer = AVSpeechSynthesizer()
        speechDelegate = nil

        startNextLine()
    }

    /// Called whenever we want to show/speak the next line.
    private func startNextLine() {
        guard currentUtteranceIndex < dialogue.count else {
            print("✅ All lines spoken.")
            // Show the user an alert with options to restart
            showScriptCompletionAlert = true
            return
        }

        let entry = dialogue[currentUtteranceIndex]
        visibleLines.append(entry)

        print("➡️ Now showing line \(currentUtteranceIndex) for: \(entry.character)")

        if entry.character == selectedCharacter {
            // It's the user's line
            print("   This line is the USER’s line (no TTS).")
            isUserLine = true
        } else {
            // It's someone else's line
            print("   This line will be spoken by AVSpeechSynthesizer.")
            isUserLine = false
            speakLine(entry.line)
        }
    }

    /// Called when the user finishes their line and taps "Continue".
    private func userLineFinished() {
        // Move to the next line
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

        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    // Pause/Resume TTS
    func pauseOrResumeSpeech() {
        guard synthesizer.isSpeaking else {
            print("⚠️ Pause/Resume tapped, but there's no TTS in progress.")
            return
        }
        if isPaused {
            isPaused = false
            synthesizer.continueSpeaking()
        } else {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
        }
    }

    // MARK: - Restart Script Logic
    private func restartScript(withSameCharacter: Bool) {
        if withSameCharacter {
            // Restart from the beginning with the same character
            print("🔄 Restarting script with the SAME character.")
            currentUtteranceIndex = 0
            visibleLines.removeAll()
            isUserLine = false

            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.delegate = nil
            initializeSpeech()
            
        } else {
            // Go back to character selection
            print("🔄 Restarting script with a DIFFERENT character.")
            isCharacterSelected = false
            
            // IMPORTANT: We set the first character as soon as we return:
            // This ensures the Done button is immediately enabled if "Cinderella" is first.
            selectedCharacter = characters.first
            
            visibleLines.removeAll()
            currentUtteranceIndex = 0
            isUserLine = false

            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.delegate = nil
        }
    }
}

// MARK: - Speech Delegate Wrapper
class AVSpeechSynthesizerDelegateWrapper: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}
