//
//  ContentView.swift
//  SceneAloud
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var fileContent: String = ""
    @State private var dialogue: [(character: String, line: String)] = [] // Store character and lines
    @State private var isSpeaking: Bool = true // Start speaking by default
    @State private var isPaused: Bool = false // Track paused state
    @State private var currentUtteranceIndex: Int = 0 // Track current utterance
    private let synthesizer = AVSpeechSynthesizer()
    @State private var speechDelegate: AVSpeechSynthesizerDelegateWrapper? // Hold strong reference
    
    var body: some View {
        NavigationView {
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
                
                // Pause/Resume Button Only
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
    
//    func loadFileContent() {
//        DispatchQueue.global(qos: .userInitiated).async {
//            if let filePath = Bundle.main.path(forResource: "cinderella", ofType: "txt") {
//                do {
//                    let content = try String(contentsOfFile: filePath, encoding: .utf8)
//                    DispatchQueue.main.async {
//                        self.fileContent = content
//                        self.dialogue = self.extractDialogue(from: content)
//                    }
//                } catch {
//                    DispatchQueue.main.async {
//                        self.fileContent = "Error loading file content."
//                    }
//                }
//            } else {
//                DispatchQueue.main.async {
//                    self.fileContent = "File not found."
//                }
//            }
//        }
//    }

    func loadFileContent() {
        if let filePath = Bundle.main.path(forResource: "cinderella", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                self.fileContent = content
                self.dialogue = self.extractDialogue(from: content)
                print("✅ File loaded successfully.")
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
        loadFileContent()
        if !self.dialogue.isEmpty {
            self.currentUtteranceIndex = 0
            startSpeaking()
        }
        else {
            print("No dialog")
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
    
    func startSpeaking() {
        guard currentUtteranceIndex < dialogue.count else {
            isSpeaking = false
            print("✅ All lines spoken.")
            return
        }

        // Speak the current line
        let entry = dialogue[currentUtteranceIndex]
        let utterance = AVSpeechUtterance(string: entry.line)
        
        // Set the voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        } else {
            print("⚠️ 'en-US' voice not available. Using default voice.")
        }

        utterance.postUtteranceDelay = 1.0 // Add a delay between lines

        // Set up the delegate to handle the next utterance
        let delegate = AVSpeechSynthesizerDelegateWrapper { [self] in
            self.speakNextUtterance()
        }
        speechDelegate = delegate
        synthesizer.delegate = delegate

        synthesizer.speak(utterance)
        currentUtteranceIndex += 1
    }
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
    
    func speakNextUtterance() {
        guard currentUtteranceIndex < dialogue.count else {
            isSpeaking = false
            print("✅ All lines spoken.")
            return
        }

        // Speak the next line
        let entry = dialogue[currentUtteranceIndex]
        let utterance = AVSpeechUtterance(string: entry.line)

        // Set the voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        } else {
            print("⚠️ 'en-US' voice not available. Using default voice.")
        }

        utterance.postUtteranceDelay = 1.0 // Add a delay between lines
        synthesizer.speak(utterance)
        currentUtteranceIndex += 1
    }
}

// Add this class below ContentView
class AVSpeechSynthesizerDelegateWrapper: NSObject, AVSpeechSynthesizerDelegate {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}
