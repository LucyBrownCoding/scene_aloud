//import SwiftUI
//import AVFoundation
//import UIKit
//import PDFKit  // Added for PDF support
//import UniformTypeIdentifiers
//
//
//// New enum for script input type
//enum ScriptInputType: String, CaseIterable, Identifiable {
//    case pdf = "PDF"
//    case text = "Text File"
//    case typed = "Type It"
//    
//    var id: String { self.rawValue }
//}
//
//struct ContentView: View {
//    // MARK: - State Variables
//    @State private var isShowingSplash: Bool = true
//    @State private var fileContent: String = ""
//    @State private var dialogue: [(character: String, line: String)] = []
//    @State private var characters: [String] = []
//    @State private var selectedCharacters: Set<String> = []
//    @State private var isCharacterSelected: Bool = false
//
//    @State private var currentUtteranceIndex: Int = 0
//    @State private var isSpeaking: Bool = false
//    @State private var isPaused: Bool = false
//    @State private var isUserLine: Bool = false
//
//    @State private var synthesizer = AVSpeechSynthesizer()
//    @State private var speechDelegate: AVSpeechSynthesizerDelegateWrapper?
//
//    @State private var showScriptCompletionAlert: Bool = false
//    @State private var displayLinesAsRead: Bool = true
//
//    // MARK: - New State Variables for Script Input
//    @State private var isShowingDocumentPicker: Bool = false
//    @State private var selectedFileURL: URL? = nil
//    @State private var hasUploadedFile: Bool = false
//    @State private var inputType: ScriptInputType = .text  // Default to text file input
//
//    var body: some View {
//        NavigationView {
//            if isShowingSplash {
//                // MARK: Splash Screen
//                ZStack {
//                    VStack {
//                        Spacer(minLength: 20)
//                        VStack(spacing: 10) {
//                            Image("SplashLogo")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 250, height: 250)
//                            
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
//                // MARK: Upload/Input Page
//                VStack(spacing: 20) {
//                    Text("Upload Your Script")
//                        .font(.largeTitle)
//                        .bold()
//                        .padding(.top, 40)
//                    
//                    Text("Is your script a PDF, a text file, or will you type it?")
//                        .font(.body)
//                        .multilineTextAlignment(.center)
//                        .padding(.horizontal, 40)
//                    
//                    // Picker to select the input type
//                    Picker("Script Input Type", selection: $inputType) {
//                        ForEach(ScriptInputType.allCases) { type in
//                            Text(type.rawValue).tag(type)
//                        }
//                    }
//                    .pickerStyle(SegmentedPickerStyle())
//                    .padding(.horizontal, 40)
//                    
//                    // Show appropriate view based on inputType
//                    if inputType == .typed {
//                        // For typed input, show a TextEditor.
//                        TextEditor(text: $fileContent)
//                            .frame(height: 200)
//                            .border(Color.gray, width: 1)
//                            .padding(.horizontal, 40)
//                        
//                        Button(action: {
//                            self.dialogue = self.extractDialogue(from: fileContent)
//                            let extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
//                            self.characters = extractedCharacters
//                            self.hasUploadedFile = true
//                        }) {
//                            Text("Submit Script")
//                                .font(.headline)
//                                .padding()
//                                .foregroundColor(.white)
//                                .background(Color.blue)
//                                .cornerRadius(10)
//                        }
//                        .padding(.top, 10)
//                    } else if inputType == .pdf {
//                        // For PDF input, show a message with a ChatGPT prompt instead of allowing PDF uploads.
//                        VStack(spacing: 20) {
//                            Text("Hello! To keep this app free, PDF conversion isn’t supported. Instead, copy the prompt below into ChatGPT(or any similar AI tool) and attach your script PDF to convert your PDF to a text file for free.")
//                                .font(.body)
//                                .multilineTextAlignment(.center)
//                                .padding(.horizontal, 40)
//                            
//                            Button(action: {
//                                        UIPasteboard.general.string = """
//                                        I have a PDF file attached that contains a script. Please extract all the text from every page, preserving the original layout (including line breaks and paragraphs), and output only the extracted text in plain text file—nothing else.
//                                        """
//                                    }) {
//                                        Text("Copy ChatGPT Prompt")
//                                            .font(.headline)
//                                            .padding()
//                                            .foregroundColor(.white)
//                                            .background(Color.blue)
//                                            .cornerRadius(10)
//                                    }
//                                    
//                                    Button(action: {
//                                        if let url = URL(string: "https://chat.openai.com/") {
//                                            UIApplication.shared.open(url)
//                                        }
//                                    }) {
//                                        Text("Go to ChatGPT")
//                                            .font(.headline)
//                                            .padding()
//                                            .foregroundColor(.white)
//                                            .background(Color.green)
//                                            .cornerRadius(10)
//                                    }
//                        }
//                    } else {
//                        // For text file input, show the file selection button.
//                        Button(action: {
//                            isShowingDocumentPicker = true
//                        }) {
//                            HStack {
//                                Image(systemName: "doc.text.fill")
//                                    .font(.title)
//                                Text("Select Text File")
//                                    .font(.headline)
//                            }
//                            .padding()
//                            .foregroundColor(.white)
//                            .background(Color.blue)
//                            .cornerRadius(10)
//                        }
//                        .sheet(isPresented: $isShowingDocumentPicker) {
//                            DocumentPicker(filePath: $selectedFileURL, allowedContentTypes: [UTType.plainText])
//                        }
//                        .onChange(of: selectedFileURL) { _, newValue in
//                            if let url = newValue {
//                                handleFileSelection(url: url)
//                            }
//                        }
//                    }
//                    
//                    Spacer()
//                }
//                .padding()
//            } else if !isCharacterSelected {
//                // MARK: Settings Page
//                VStack(alignment: .leading) {
//                    Text("Settings")
//                        .font(.largeTitle)
//                        .bold()
//                        .padding(.top, 20)
//                    
//                    Text("Select your characters")
//                        .font(.title2)
//                        .padding(.vertical, 5)
//                    
//                    Toggle("Not Applicable", isOn: Binding(
//                        get: { selectedCharacters.contains("Not Applicable") },
//                        set: { newValue in
//                            if newValue {
//                                selectedCharacters = ["Not Applicable"]
//                            } else {
//                                selectedCharacters.remove("Not Applicable")
//                            }
//                        }
//                    ))
//                    .padding(.vertical, 2)
//                    
//                    ForEach(characters, id: \.self) { character in
//                        Toggle(character.capitalized, isOn: Binding(
//                            get: { selectedCharacters.contains(character) },
//                            set: { newValue in
//                                if newValue {
//                                    selectedCharacters.remove("Not Applicable")
//                                    selectedCharacters.insert(character)
//                                } else {
//                                    selectedCharacters.remove(character)
//                                }
//                            }
//                        ))
//                        .padding(.vertical, 2)
//                    }
//                    
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
//                    Button(action: {
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
//            if inputType == .pdf {
//                // Extract text from a PDF using attributed strings.
//                if let pdfDocument = PDFDocument(url: url) {
//                    let pageCount = pdfDocument.pageCount
//                    let documentContent = NSMutableAttributedString()
//                    
//                    // Iterate over all pages.
//                    for i in 0..<pageCount {
//                        if let page = pdfDocument.page(at: i),
//                           let pageContent = page.attributedString {
//                            documentContent.append(pageContent)
//                        }
//                    }
//                    self.fileContent = documentContent.string
//                } else {
//                    self.fileContent = "Error loading PDF content."
//                }
//            } else {
//                // For text files, simply load the content as before.
//                self.fileContent = try String(contentsOf: url, encoding: .utf8)
//            }
//            
//            // Process the extracted content.
//            self.dialogue = self.extractDialogue(from: fileContent)
//            
//            if dialogue.isEmpty {
//                print("⚠️ The file is empty or has no valid lines with a colon.")
//            }
//            
//            let extractedCharacters = Array(Set(dialogue.map { $0.character })).sorted()
//            self.characters = extractedCharacters
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
//            if selectedCharacters.contains("Not Applicable") {
//                Text(entry.line)
//                    .font(.body)
//                    .padding(5)
//                    .background(
//                        index == currentUtteranceIndex ? Color.yellow.opacity(0.7) : Color.clear
//                    )
//                    .cornerRadius(5)
//            } else if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
//                Text("It’s your line! Press to continue.")
//                    .font(.body)
//                    .padding(5)
//                    .frame(maxWidth: .infinity, alignment: .leading)
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
//        if selectedCharacters.contains("Not Applicable") {
//            isUserLine = false
//            speakLine(entry.line)
//        } else if selectedCharacters.contains(where: { $0.caseInsensitiveCompare(entry.character) == .orderedSame }) {
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
//            selectedCharacters = []
//            displayLinesAsRead = true
//        }
//    }
//    
//    func colorForCharacter(_ character: String) -> Color {
//        let colors: [Color] = [.orange, .blue, .pink, .purple, .red, .teal]
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
