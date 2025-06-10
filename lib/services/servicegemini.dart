import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class SimpleGeminiPage extends StatefulWidget {
  const SimpleGeminiPage({super.key});

  @override
  State<SimpleGeminiPage> createState() => _SimpleGeminiPageState();
}

class _SimpleGeminiPageState extends State<SimpleGeminiPage> {
  // IMPORTANT: DO NOT hardcode your API key like this in a real app.
  // This is just for a quick demo.
  final String _apiKey = "AIzaSyDkfoKXTUdrgm87-4kPgdJx9TvAg5HoCyk"; 

  final TextEditingController _promptController = TextEditingController();
  String _geminiResponse = "Ask me anything...";
  bool _isLoading = false;

  Future<void> _callGemini() async {
    if (_promptController.text.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _geminiResponse = "Thinking...";
    });

    try {
      // Initialize the model
      final model = GenerativeModel(
        model: 'gemini-1.5-flash-latest', // Or 'gemini-pro'
        apiKey: _apiKey,
      );

      final content = [Content.text(_promptController.text)];
      final response = await model.generateContent(content);

      setState(() {
        _geminiResponse = response.text ?? "I couldn't think of anything...";
      });
    } catch (e) {
      setState(() {
        _geminiResponse = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _promptController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Quick Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Enter your prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _callGemini,
                    child: const Text('Generate'),
                  ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_geminiResponse),
              ),
            ),
          ],
        ),
      ),
    );
  }
}