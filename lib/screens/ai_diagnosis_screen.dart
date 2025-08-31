// lib/screens/ai_diagnosis_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav; // Import main.dart for NavigationDrawer
import 'package:google_generative_ai/google_generative_ai.dart'; // Import Gemini SDK
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv for API key

class AiDiagnosisScreen extends StatefulWidget {
  const AiDiagnosisScreen({super.key});

  @override
  State<AiDiagnosisScreen> createState() => _AiDiagnosisScreenState();
}

class _AiDiagnosisScreenState extends State<AiDiagnosisScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late GenerativeModel _model;
  late ChatSession _chat; // Use ChatSession for multi-turn conversations

  @override
  void initState() {
    super.initState();
    _initializeGeminiModel();
  }

  void _initializeGeminiModel() {
    final String? apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      // Provide user-friendly message instead of throwing an unhandled exception
      _showErrorMessage(
          'API Key not found. Please add GEMINI_API_KEY to your .env file.');
      return;
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // Changed back to 'gemini-1.5-flash' to avoid "model not found" error
      apiKey: apiKey,
    );

    // Initialize the chat session with a strong system instruction
    // This is vital for making the chatbot focus ONLY on vehicle breakdowns
    final String systemInstruction = """
      You are an AI assistant named AUTOFIX Bot, specialized in diagnosing common vehicle breakdown and maintenance problems. 
      Your primary goal is to help users understand what might be wrong with their car based on their description of symptoms, 
      and provide general troubleshooting advice.

      When responding:
      - Always acknowledge the user's vehicle problem.
      - Ask clarifying questions if the description is vague.
      - Suggest possible causes for the symptoms (e.g., "This could be a battery issue, a starter problem, or a loose connection.").
      - Recommend general, safe troubleshooting steps the user can perform (e.g., "Check battery terminals for corrosion," "Listen for specific sounds.").
      - Advise seeking professional mechanic help for complex, serious, or unsafe issues.
      - Maintain a helpful and informative tone.
      - **CRITICAL**: If a query is clearly **outside the scope of vehicle breakdowns or maintenance**, politely state that you can only assist with car-related problems.
        Example: "I can only help with vehicle breakdown and maintenance questions. Please describe your car's issue."
      - **DO NOT** provide medical advice, financial advice, legal advice, or any information unrelated to vehicles.
      - **DO NOT** promise a definitive fix or guarantee accuracy.
      - **DO NOT** ask for personal information.
      - Keep responses focused and concise.
      """;

    _chat = _model.startChat(history: [
      Content.text(systemInstruction),
      // Optionally, add few-shot examples here to further guide the model
      // Example:
      // Content.text('User: My car makes a loud grinding noise when I brake.',
      //             'Bot: A grinding noise during braking often indicates worn brake pads or rotors. It\'s important to get this checked by a mechanic as soon as possible for your safety. Does the sound happen constantly or only when you press the brake pedal?'),
    ]);
  }

  // --- Displays a simple error message to the user ---
  void _showErrorMessage(String message) {
    if (mounted) { // Ensure widget is still in the tree before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Core function to send message to Gemini and get response ---
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return; // Prevent sending empty messages or multiple messages

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true)); // Add user message
      _textController.clear();
      _isLoading = true; // Show loading indicator
    });

    try {
      final response = await _chat.sendMessage(Content.text(text));

      setState(() {
        _messages.add(ChatMessage(text: response.text ?? 'No response.', isUser: false));
        _isLoading = false; // Hide loading indicator
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Error: ${e.toString()}', isUser: false));
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Diagnosis Chatbot',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const app_nav.NavigationDrawer(), // Your NavigationDrawer
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true, // Show latest messages at the bottom
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index]; // Display in reverse order
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2), // changes position of shadow
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75, // Max width for chat bubbles
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              color: Colors.blue,
              backgroundColor: Colors.blueAccent,
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Describe your vehicle\'s issue...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide(color: Colors.blue.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: const BorderSide(color: Colors.blue, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  backgroundColor: Colors.blue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24.0,
                          height: 24.0,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simple data model for chat messages
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
