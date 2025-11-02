// lib/screens/ai_diagnosis_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiDiagnosisScreen extends StatefulWidget {
  const AiDiagnosisScreen({super.key});

  @override
  State<AiDiagnosisScreen> createState() => _AiDiagnosisScreenState();
}

class _AiDiagnosisScreenState extends State<AiDiagnosisScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  late final String _apiKey;
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      _showErrorMessage('API Key not found. Please add OPENAI_API_KEY to your .env file.');
      return;
    }

    const String systemInstruction = """
      You are an AI assistant named AUTOFIX Bot, specialized in diagnosing common vehicle breakdown and maintenance problems. Your primary goal is to help users understand what might be wrong with their car and provide general troubleshooting advice. If a query is clearly outside this scope, politely state you can only assist with car-related problems. Do not ask for personal information.
      """;
    
    // The "system" message sets the behavior for the whole conversation
    _chatHistory.add({'role': 'system', 'content': systemInstruction});
    
    const String firstMessage = 'Hello! I am AUTOFIX Bot. How can I help you with your vehicle today?';
    _messages.insert(0, ChatMessage(text: firstMessage, isUser: false));
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading || _apiKey.isEmpty) return;

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true));
      _textController.clear();
      _isLoading = true;
    });

    _chatHistory.add({'role': 'user', 'content': text});

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey', // OpenAI uses a Bearer token
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // The standard, fast model from OpenAI
          'messages': _chatHistory,
        }),
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final responseText = decodedResponse['choices'][0]['message']['content'] as String;

        _chatHistory.add({'role': 'assistant', 'content': responseText});

        setState(() {
          _messages.insert(0, ChatMessage(text: responseText, isUser: false));
          _isLoading = false;
        });
      } else {
        final errorBody = jsonDecode(response.body);
        throw 'API Error (${response.statusCode}): ${errorBody['error']['message']}';
      }
    } catch (e) {
      _showErrorMessage(e.toString());
      setState(() {
        _messages.insert(0, ChatMessage(text: 'Error: Could not get a response.', isUser: false));
        _isLoading = false;
      });
      _chatHistory.removeLast();
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
      drawer: const app_nav.NavigationDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3.0),
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

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}