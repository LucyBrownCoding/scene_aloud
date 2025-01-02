import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var fileContent: String = ""
    @State private var dialogue: [(character: String, line: String)] = [] // Store character and lines
    @State private var characters: [String] = [] // Store unique character names
    @State private var selectedCharacter: String? // The character the user chooses to play
    @State private var isCharacterSelected: Bool = false // Track if the character is selected
    @State private var isSpeaking: Bool = true // Start speaking by default
    @State private var isPaused: Bool = false // Track paused state
    @State private var currentUtteranceIndex: Int = 0 // Track current utterance
    private let synthesizer = AVSpeechSynthesizer()
    @State private var speechDelegate: AVSpeechSynthesizerDelegateWrapper? // Hold strong reference

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
                            Text(character.lowercased().capitalized) // Format as "Narrator", "Cinderella", etc.
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
                    .padding()
                    .background(selectedCharacter == nil ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(selectedCharacter == nil) // Disable button if no character is selected
                }
            } else {
                // Script Reading Screen
                VStack {
                    if dialogue.isEmpty {
                        Text("Loading content...")
                            .padding()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading) {
                                ForEach(dialogue, id: \.line) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.character) // Display character name
                                            .font(.headline)
                                            .foregroundColor(.primary) // Adapt to dark/light mode
                                        
                                        Text(entry.line) // Display line
                                            .padding(5)
                                            .background(Color.yellow.opacity(0.7)) // Highlight
                                            .cornerRadius(5)
                                    }
                                    .padding(.bottom, 10)
                                }
                            }
                            .padding()
                        }
                        .scrollIndicators(.hidden) // Clean up scroll view look
                    }

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
                .navigationTitle("Scene Aloud")
                .navigationBarTitleDisplayMode(.inline)
                .padding(.bottom)
                .onAppear(perform: initializeSpeech)
            }
        }
        .onAppear {
            loadFileContent()
        }
    }

    func loadFileContent() {
        if let filePath = Bundle.main.path(forResource: "cinderella", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                self.fileContent = content
                self.dialogue = self.extractDialogue(from: content)
                self.characters = Array(Set(dialogue.map { $0.character })).sorted()
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

    func extractDialogue(from text: String) -> [(character: String, line: String)] {
        var extractedDialogue: [(String, String)] = []
        let lines = text.split(separator: "\n")
        
        for line in lines {
            if let colonIndex = line.firstIndex(of: ":") {
                let characterName = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let content = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
                
                extractedDialogue.append((characterName, content))
            }
        }
        
        return extractedDialogue
    }

    func initializeSpeech() {
        if !dialogue.isEmpty {
            currentUtteranceIndex = 0
            startSpeaking()
        }
    }

    func pauseOrResumeSpeech() {
        if synthesizer.isSpeaking {
            if isPaused {
                isPaused = false
                synthesizer.continueSpeaking()
            } else {
                synthesizer.pauseSpeaking(at: .word)
                isPaused = true
                isSpeaking = false
            }
        }
    }

    func startSpeaking() {
        guard currentUtteranceIndex < dialogue.count else {
            isSpeaking = false
            print("✅ All lines spoken.")
            return
        }

        let entry = dialogue[currentUtteranceIndex]
        
        // Skip the selected character's lines
        if entry.character == selectedCharacter {
            print("🎭 Skipping \(selectedCharacter ?? "")'s line.")
            currentUtteranceIndex += 1
            startSpeaking() // Move to the next line
            return
        }

        let utterance = AVSpeechUtterance(string: entry.line)
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        } else {
            print("⚠️ 'en-US' voice not available. Using default voice.")
        }
        utterance.postUtteranceDelay = 1.0

        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
            self.startSpeaking()
        }
        speechDelegate = delegate
        synthesizer.delegate = delegate

        synthesizer.speak(utterance)
        currentUtteranceIndex += 1
    }
}
class AVSpeechSynthesizerDelegateWrapper: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}
