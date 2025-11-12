import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- 1. IMPORTED dotenv

// --- Message Class (Helper) ---
class Message {
  final String text;
  final bool isUser;
  Message({required this.text, required this.isUser});
}

// ---------------------------------
// --- Analytics Screen (Chat UI) ---
// ---------------------------------
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _GeminiChatService _gemini = _GeminiChatService();

  final List<Message> _messages = [
    Message(
      text:
      "How can I help you today? Ask me about cycle health, symptoms, or wellness.",
      isUser: false,
    ),
  ];
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Function to send a message
  Future<void> _sendMessage({String? prompt}) async {
    final text = prompt ?? _textController.text.trim();
    if (text.isEmpty) return;

    if (prompt == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _gemini.getChatResponse(text);
      setState(() {
        _messages.add(Message(text: response, isUser: false));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
            Message(text: 'Sorry, I ran into an error: $e', isUser: false));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E6F1), // Pinkish background
      appBar: AppBar(
        backgroundColor: Colors.white, // White app bar
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // --- MODIFIED: Replaced Icon with Image.asset ---
            ClipRRect(
              borderRadius:
              BorderRadius.circular(6.0), // Optional: adds rounded corners
              child: Image.asset(
                'assets/images/os.jpg',
                width: 28, // You can adjust the size
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'CycleOS  Health Assistant',
              style: TextStyle(
                color: Colors.black, // Black type
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                // --- 4. UPDATED to use _ChatMessageBubble ---
                return _ChatMessageBubble(
                  message: message.text,
                  isUser: message.isUser,
                );
              },
            ),
          ),

          // --- MODIFICATION START ---
          // Loading indicator
          if (_isLoading)
            _buildTypingIndicator(), // <-- Yahan change kiya hai
          // --- MODIFICATION END ---

          // Suggestion chips
          if (_messages.length <= 1)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  _buildSuggestionChip(
                    "What are the common symptoms of PCOS?",
                        () => _sendMessage(
                        prompt: "What are the common symptoms of PCOS?"),
                  ),
                  _buildSuggestionChip(
                    "Can you explain the menstrual cycle phases?",
                        () => _sendMessage(
                        prompt: "Can you explain the menstrual cycle phases?"),
                  ),
                ],
              ),
            ),
          // Chat input area
          _buildChatInputField(),
        ],
      ),
    );
  }

  // --- NEW WIDGET: Typing Indicator ---
  Widget _buildTypingIndicator() {
    return Padding(
      // Padding taaki list se align ho
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white, // Bot ka bubble color
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomLeft: const Radius.circular(4),
              bottomRight: const Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min, // Important!
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFFE91E63),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text(
                "Typing...",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // --- END OF NEW WIDGET ---

  Widget _buildSuggestionChip(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white, // White chip color
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.pink[100]!), // Light pink border
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black87, // Black type
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white, // Match app bar
        border: Border(top: BorderSide(color: Color(0xFFF5E6F1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.black), // Black type
                decoration: InputDecoration(
                  hintText: 'Ask TrackAI Health Assistant',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color(0xFFF5E6F1), // Light pink fill
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _sendMessage(),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE91E63), // Pink
                child: const Icon(
                  Icons.send, // Send icon
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------
// --- Chat Message Bubble Widget ---
// ---------------------------------
class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    Key? key,
    required this.message,
    required this.isUser,
  }) : super(key: key);

  final String message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    // --- 5. UPDATED to use MarkdownBody instead of Text ---
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFE91E63) : Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomLeft:
            isUser ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight:
            isUser ? const Radius.circular(4) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: MarkdownBody(
          data: message,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(
              color: isUser ? Colors.white : Colors.black,
              fontSize: 15,
            ),
            strong: TextStyle(
              color: isUser ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
            listBullet: TextStyle(
              color: isUser ? Colors.white : Colors.black,
            ),
          ),
          onTapLink: (text, href, title) {
            if (href != null) {
              launchUrl(Uri.parse(href));
            }
          },
        ),
      ),
    );
  }
}

// ---------------------------------
// --- Gemini Helper Service ---
// ---------------------------------
class _GeminiChatService {
  // Use the model recommended by instructions
  static const String model = "gemini-2.0-flash"; // Updated to latest
  static const String baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/";

  // --- 6. UPDATED to use dotenv ---
  final String? apiKey = dotenv.env['GEMINI_API_KEY'];

  Future<String> getChatResponse(String prompt) async {
    // --- 7. ADDED check for API key ---
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception(
          'API key not found. Please add GEMINI_API_KEY to your .env file.');
    }

    final url = Uri.parse("$baseUrl$model:generateContent?key=$apiKey");

    final requestBody = {
      // --- 8. ADDED System Instruction ---
      'systemInstruction': {
        'parts': [
          {
            'text':
            "You are CycleOS  Health Assistant, a helpful chatbot for a period and cycle tracking app. Provide concise, helpful, and friendly answers. Format your answers clearly using markdown, such as bolding for emphasis and bullet points for lists."
          }
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 8192,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final responseData = json.decode(response.body);

        if (responseData['candidates'] != null &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          String textResponse =
              responseData['candidates'][0]['content']['parts'][0]['text'] ??
                  'Sorry, I could not generate a response.';
          return textResponse.trim();
        } else {
          // Handle blocked requests
          if (responseData['promptFeedback'] != null) {
            final feedback = responseData['promptFeedback'];
            if (feedback['blockReason'] != null) {
              return 'Response blocked: ${feedback['blockReason']}.';
            }
          }
          throw Exception('Invalid response format from Gemini API');
        }
      } else if (response.body.isEmpty) {
        throw Exception('Empty response from Gemini API.');
      } else {
        final errorData =
        response.body.isNotEmpty ? json.decode(response.body) : {};
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('API Error (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('Network error: Please check your internet connection');
      }
      throw Exception(e.toString());
    }
  }
}