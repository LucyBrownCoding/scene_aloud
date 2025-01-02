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
//    @State private var isSpeaking: Bool = true
//    @State private var isPaused: Bool = false
//    @State private var currentUtteranceIndex: Int = 0
//    private let synthesizer = AVSpeechSynthesizer()
//    @State private var speechDelegate: AVSpeechSynthesizerDelegateWrapper?
//    @State private var visibleLines: [(character: String, line: String)] = []
//
//    // MARK: - Graphics
//    var body: some View {
//        NavigationView {
//            if !isCharacterSelected {
//                // Character Selection Screen
//                VStack {
//                    Text("Select a Character")
//                        .font(.largeTitle)
//                        .padding()
//
//                    Picker("Choose your character", selection: $selectedCharacter) {
//                        ForEach(characters, id: \.self) { character in
//                            Text(character.capitalized)
//                                .tag(character as String?)
//                        }
//                    }
//                    .pickerStyle(WheelPickerStyle())
//                    .padding()
//
//                    Button("Done") {
//                        if let selected = selectedCharacter {
//                            print("✅ Character Selected: \(selected)")
//                            isCharacterSelected = true
//                        }
//                    }
//                    .padding()
//                    .background(selectedCharacter == nil ? Color.gray : Color.blue)
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//                    .disabled(selectedCharacter == nil)
//                }
//            } else {
//                // Script Reading Screen
//                VStack {
//                    ScrollView {
//                        VStack(alignment: .leading) {
//                            ForEach(visibleLines, id: \.line) { entry in
//                                VStack(alignment: .leading, spacing: 4) {
//                                    Text(entry.character)
//                                        .font(.headline)
//                                        .foregroundColor(.primary)
//
//                                    Text(entry.line)
//                                        .padding(5)
//                                        .background(Color.yellow.opacity(0.7))
//                                        .cornerRadius(5)
//                                }
//                                .padding(.bottom, 10)
//                            }
//                        }
//                        .padding()
//                    }
//
//                    Button(action: pauseOrResumeSpeech) {
//                        Text(isPaused ? "Resume" : "Pause")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(isPaused ? Color.green : Color.yellow)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                    .padding(.horizontal)
//                }
//                .navigationTitle("SceneAloud")
//                .onAppear(perform: initializeSpeech)
//            }
//        }
//        .onAppear(perform: loadFileContent)
//    }
//
//    // MARK: - Loading Data
//    func loadFileContent() {
//        if let filePath = Bundle.main.path(forResource: "cinderella", ofType: "txt") {
//            do {
//                let content = try String(contentsOfFile: filePath, encoding: .utf8)
//                self.fileContent = content
//                self.dialogue = self.extractDialogue(from: content)
//                self.characters = Array(Set(dialogue.map { $0.character })).sorted()
//
//                // Automatically select the first character
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
//    // MARK: - Extracting Data
//    func extractDialogue(from text: String) -> [(character: String, line: String)] {
//        var extractedDialogue: [(String, String)] = []
//        let lines = text.split(separator: "\n")
//
//        for line in lines {
//            if let colonIndex = line.firstIndex(of: ":") {
//                let characterName = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
//                let content = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
//
//                extractedDialogue.append((characterName, content))
//            }
//        }
//
//        return extractedDialogue
//    }
//
//    // MARK: - Speech
//    func initializeSpeech() {
//        if !dialogue.isEmpty {
//            visibleLines = [dialogue[0]]
//            currentUtteranceIndex = 0
//            startSpeaking()
//        }
//    }
//
//    func pauseOrResumeSpeech() {
//        if synthesizer.isSpeaking {
//            if isPaused {
//                isPaused = false
//                synthesizer.continueSpeaking()
//            } else {
//                synthesizer.pauseSpeaking(at: .word)
//                isPaused = true
//            }
//        }
//    }
//
//    func startSpeaking() {
//        guard currentUtteranceIndex < dialogue.count else {
//            isSpeaking = false
//            print("✅ All lines spoken.")
//            return
//        }
//
//        let entry = dialogue[currentUtteranceIndex]
//
//        let utterance = AVSpeechUtterance(string: entry.line)
//        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
//        utterance.postUtteranceDelay = 1.0
//
//        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
//            currentUtteranceIndex += 1
//            if currentUtteranceIndex < dialogue.count {
//                visibleLines.append(dialogue[currentUtteranceIndex])
//            }
//            startSpeaking()
//        }
//        speechDelegate = delegate
//        synthesizer.delegate = delegate
//        synthesizer.speak(utterance)
//    }
//}
//
//// MARK: - Speech Delegate Wrapper
//class AVSpeechSynthesizerDelegateWrapper: NSObject, AVSpeechSynthesizerDelegate {
//    private let completion: () -> Void
//
//    init(completion: @escaping () -> Void) {
//        self.completion = completion
//    }
//
//    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
//        completion()
//    }
//}
//
