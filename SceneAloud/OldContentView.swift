////
////  ContentView.swift
////  SceneAloud
////
//
//import SwiftUI
//import AVFoundation
//
//struct ContentView: View {
//    @State private var fileContent: String = ""
//    @State private var dialogue: [(character: String, line: String)] = [] // Store character and lines
//    @State private var isSpeaking: Bool = true // Start speaking by default
//    @State private var isPaused: Bool = false // Track paused state
//    @State private var currentUtteranceIndex: Int = 0 // Track current utterance
//    private let synthesizer = AVSpeechSynthesizer()
//    @State private var speechDelegate: AVSpeechSynthesizerDelegateWrapper? // Hold strong reference
//    
//    var body: some View {
//        VStack {
//            if dialogue.isEmpty {
//                Text("Loading content...")
//                    .padding()
//            } else {
//                ScrollView {
//                    VStack(alignment: .leading) {
//                        ForEach(dialogue, id: \.line) { entry in
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text(entry.character) // Display character name
//                                    .font(.headline)
//                                    .foregroundColor(.white) // White text
//                                
//                                Text(entry.line) // Display line
//                                    .padding(5)
//                                    .background(Color.yellow.opacity(0.7)) // Yellow highlight
//                                    .cornerRadius(5)
//                            }
//                            .padding(.bottom, 10)
//                        }
//                    }
//                }
//                .frame(maxHeight: .infinity)
//                .padding()
//                .background(Color.black) // Set a background for better contrast
//                .edgesIgnoringSafeArea(.bottom)
//            }
//            
//            HStack {
//                // Pause/Resume Button
//                Button(action: pauseOrResumeSpeech) {
//                    Text(isPaused ? "Resume Speaking" : "Pause Speaking")
//                        .padding()
//                        .background(isPaused ? Color.green : Color.yellow)
//                        .foregroundColor(.white)
//                        .cornerRadius(8)
//                }
//                
//                // Reset Button
//                Button(action: resetFirstLine) {
//                    Text("Reset")
//                        .padding()
//                        .background(Color.red)
//                        .foregroundColor(.white)
//                        .cornerRadius(8)
//                }
//            }
//        }
//        .padding()
//        .onAppear(perform: initializeSpeech)
//    }
//    
//    func loadFileContent() {
//        if let filePath = Bundle.main.path(forResource: "cinderella", ofType: "txt") {
//            do {
//                let content = try String(contentsOfFile: filePath, encoding: .utf8)
//                fileContent = content
//                dialogue = extractDialogue(from: content)
//            } catch {
//                fileContent = "Error loading file content."
//            }
//        } else {
//            fileContent = "File not found."
//        }
//    }
//    
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
//    func initializeSpeech() {
//        loadFileContent()
//        if !dialogue.isEmpty {
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
//                isSpeaking = false
//            }
//        }
//    }
//    
//    func resetFirstLine() {
//        synthesizer.stopSpeaking(at: .immediate)
//        currentUtteranceIndex = 0
//        isSpeaking = false
//        isPaused = false
//
//        guard !dialogue.isEmpty else { return }
//
//        let entry = dialogue[currentUtteranceIndex]
//        let utterance = AVSpeechUtterance(string: entry.line)
//        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
//        utterance.postUtteranceDelay = 1.0
//
//        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
//            speakNextUtterance()
//        }
//        speechDelegate = delegate
//        synthesizer.delegate = delegate
//
//        synthesizer.speak(utterance)
//        isSpeaking = true
//        currentUtteranceIndex += 1
//    }
//    
//    func startSpeaking() {
//        guard currentUtteranceIndex < dialogue.count else {
//            isSpeaking = false
//            return
//        }
//
//        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
//            speakNextUtterance()
//        }
//        speechDelegate = delegate
//        synthesizer.delegate = delegate
//
//        isSpeaking = true
//        speakNextUtterance()
//    }
//
//    func speakNextUtterance() {
//        guard currentUtteranceIndex < dialogue.count else {
//            isSpeaking = false
//            return
//        }
//
//        let entry = dialogue[currentUtteranceIndex]
//        let utterance = AVSpeechUtterance(string: entry.line)
//        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
//        utterance.postUtteranceDelay = 1.0
//
//        synthesizer.speak(utterance)
//        currentUtteranceIndex += 1
//    }
//}
//
//// Add this class below ContentView
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
