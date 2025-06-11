import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // <--- Add this import for cos and sin
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart'; // For formatting timestamps
import 'package:flutter_animate/flutter_animate.dart'; // For animations
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:url_launcher/url_launcher.dart'; // Add this import for opening apps
import 'package:url_launcher/url_launcher_string.dart'; // Add this import for opening apps

class VoiceChat extends StatefulWidget {
  const VoiceChat({super.key});

  @override
  State<VoiceChat> createState() => _VoiceChatState();
}

// Define message types for clarity
enum MessageRole { user, assistant, status }

// Define a simple message class
class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.role, required this.timestamp});
}

class _VoiceChatState extends State<VoiceChat> with TickerProviderStateMixin {
  final String _groqApiKey =
      "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"; // Ensure this is correct
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FlutterTts _flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController(); // For scrolling chat list

  bool _isRecording = false;
  bool _isProcessing = false; // Combined state for transcribing/thinking
  bool _isSpeaking = false;
  String? _audioPath;
  String _currentStatus = "Tap the mic to start speaking";

  // Store conversation messages
  final List<ChatMessage> _messages = [];

  final String _chatApiUrl = "https://api.groq.com/openai/v1/chat/completions";
  final String _transcriptionApiUrl = "https://api.groq.com/openai/v1/audio/transcriptions";

  // Animation Controller for mic pulse
  AnimationController? _micPulseController;
  // --- Add Animation Controller for orbit ---
  AnimationController? _orbitController;

  // --- Add Dark Mode State ---
  bool _isDarkMode = true; // Default to dark mode

  // --- Theme Colors --- (Define helper getters for easier access)
  Color get _backgroundColor => _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5); // Standard dark/light backgrounds
  Color get _appBarColor => _isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;
  Color get _cardColor => _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _primaryColor => Theme.of(context).colorScheme.primary; // Use theme's primary
  Color get _onPrimaryColor => Theme.of(context).colorScheme.onPrimary;
  Color get _secondaryContainerColor => Theme.of(context).colorScheme.secondaryContainer;
  Color get _onSecondaryContainerColor => Theme.of(context).colorScheme.onSecondaryContainer;
  Color get _statusTextColor => _isDarkMode ? Colors.white70 : Colors.black54;
  Color get _bubbleTextColorUser => _isDarkMode ? Colors.white : Colors.black87; // High contrast for user bubble
  Color get _bubbleTextColorAssistant => _isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8);
  Color get _bubbleTextColorStatus => _isDarkMode ? Colors.white54 : Colors.black45;
  Color get _shadowColor => _isDarkMode ? Colors.black.withOpacity(0.4) : Colors.grey.withOpacity(0.2);
  Color get _progressIndicatorColor => _isDarkMode ? Colors.white : _primaryColor;

  // Add this variable at the top of the _VoiceChatState class
  bool _isFirstTimeListening = true;  // Track first-time listening state

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _setupTts();

    // Initialize animation controllers
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Load whether user has seen the listening message before
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        // Fix the null safety issue by properly handling the nullable bool
        final hasSeenMessage = prefs.getBool('hasSeenListeningMessage');
        _isFirstTimeListening = hasSeenMessage == null || !hasSeenMessage;
      });
    });

    // Add this: Send initial greeting after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _sendInitialGreeting();
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _flutterTts.stop();
    _scrollController.dispose(); // Dispose scroll controller
    _micPulseController?.dispose(); // Dispose animation controller
    _orbitController?.dispose(); // Dispose orbit controller
    super.dispose();
  }

  // Helper to add messages and scroll
  void _addMessage(String text, MessageRole role) {
    setState(() {
      _messages.add(ChatMessage(text: text, role: role, timestamp: DateTime.now()));
    });
    _scrollToBottom();
  }

  void _addStatusMessage(String text) {
     setState(() {
       _currentStatus = text;
     });
  }

  void _scrollToBottom() {
    // Add a small delay to allow the list view to build before scrolling
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

  // --- Load Theme Preference ---
  Future<void> _loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      // Default to true (dark mode) if no preference is saved
      _isDarkMode = prefs.getBool('isDarkModeVoiceChat') ?? true;
    });
  }

  // --- Toggle Theme Method ---
  Future<void> _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('isDarkModeVoiceChat', _isDarkMode); // Save preference
    });
  }

  Future<void> _setupTts() async {
    await _flutterTts.setSpeechRate(0.55);
    // await _flutterTts.setPitch(1.0); // Default is 1.0

    // --- Print available voices to Debug Console ---
    // Run the app in debug mode and check the console output
    // to see what voices your specific device/OS offers.
    var voices = await _flutterTts.getVoices;
    print("Available TTS Voices: $voices");
    // --------------------------------------------

    // --- Try setting a specific voice ---
    // You need to replace the 'name' and 'locale' with values
    // from the printed list that you prefer. This is just an EXAMPLE.
    // Common locales are "en-US", "en-GB", "en-AU", etc.
    // Names are highly device-specific (e.g., "Karen", "Daniel", "Samantha", or complex identifiers).
    try {
        // Example: Try finding a US English voice. You might need to adjust the map keys/values.
        // Look at the printed 'voices' list for the exact structure and available names/locales.
         await _flutterTts.setVoice({"locale": "en-US"}); // More generic: tries to set by locale
        // Or be more specific if you find a name you like from the printout:
        // await _flutterTts.setVoice({"name": "desired-voice-name-from-printout", "locale": "en-US"});
    } catch (e) {
        print("Error setting TTS voice: $e");
        _addMessage("Could not set preferred voice.", MessageRole.status);
    }
    // ------------------------------------


    // --- Handlers remain the same ---
    _flutterTts.setStartHandler(() {
      if (mounted) {
        _addStatusMessage("Speaking...");
        setState(() => _isSpeaking = true);
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        // Add a small delay before starting to record
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isRecording && !_isProcessing) {
            _startRecording();
            _addStatusMessage("I'm listening...");
          }
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        _addStatusMessage("TTS Error: $msg. Tap mic.");
        _addMessage("TTS Error: $msg", MessageRole.status);
        setState(() => _isSpeaking = false);
      }
    });
    // --- End Handlers ---
  }

  Future<void> _startRecording() async {
    if (_isSpeaking) {
      await _flutterTts.stop(); // Stop speaking if user interrupts
      if (mounted) setState(() => _isSpeaking = false);
    }
    if (_isProcessing) return; // Don't start if already processing

    if (await _audioRecorder.hasPermission()) {
      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/recording.m4a';

      try {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        if (await _audioRecorder.isRecording()) {
          if (mounted) {
            _addStatusMessage("Listening...");
            setState(() {
              _isRecording = true;
              _audioPath = path;
            });
            _micPulseController?.repeat(reverse: true);

            // After first successful recording start, update the state and save to preferences
            if (_isFirstTimeListening) {
              SharedPreferences.getInstance().then((prefs) {
                prefs.setBool('hasSeenListeningMessage', true);
              });
              setState(() {
                _isFirstTimeListening = false;
              });
            }
          }
        }
      } catch (e) {
         if (mounted) _addStatusMessage("Recording Error: $e");
         _micPulseController?.stop(); // Stop pulsing on error
      }
    } else {
      if (mounted) _addStatusMessage("Microphone permission denied.");
       _micPulseController?.stop(); // Stop pulsing
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
     _micPulseController?.stop(); // Stop pulsing

    try {
      final String? path = await _audioRecorder.stop();
      if (mounted) {
        _addStatusMessage("Processing audio...");
        setState(() {
          _isRecording = false;
          _isProcessing = true; // Start processing
          _audioPath = path;
        });
      }

      if (_audioPath != null) {
        await _transcribeAudio(_audioPath!);
      } else {
         if (mounted) {
           _addStatusMessage("Recording failed or no audio.");
           setState(() => _isProcessing = false); // End processing on error
         }
      }
    } catch (e) {
       if (mounted) {
         _addStatusMessage("Stop Recording Error: $e");
         setState(() { // Ensure states are reset on error
            _isRecording = false;
            _isProcessing = false;
         });
       }
    }
  }

  Future<void> _transcribeAudio(String filePath) async {
    if (_groqApiKey.isEmpty) {
      _addStatusMessage("Error: Groq API Key missing.");
      _addMessage("System Error: API Key missing.", MessageRole.status);
      setState(() => _isProcessing = false);
      return;
    }

    final Uri transcriptionUrl = Uri.parse(_transcriptionApiUrl);
    final request = http.MultipartRequest('POST', transcriptionUrl);

    request.headers['Authorization'] = 'Bearer $_groqApiKey';
    request.fields['model'] = 'whisper-large-v3-turbo';
    try {
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      if (mounted) _addStatusMessage("Transcribing...");

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return; // Check mounted after async gap

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(responseBody);
        final userText = decodedResponse['text']?.trim() ?? "";

        if (userText.isEmpty) {
            _addStatusMessage("Couldn't hear clearly. Try again?");
            setState(() => _isProcessing = false); // End processing
        } else {
            _addMessage(userText, MessageRole.user); // Add user message to chat
            _addStatusMessage("Thinking...");
            await _getAIResponse(userText); // Get AI response
        }

      } else {
        _addStatusMessage("Transcription Error: ${response.statusCode}");
        _addMessage("Error Transcribing: ${response.statusCode} - $responseBody", MessageRole.status);
        setState(() => _isProcessing = false); // End processing on error
      }
    } catch (e) {
      if (mounted) {
        _addStatusMessage("Transcription Request Error: $e");
        _addMessage("Error: $e", MessageRole.status);
        setState(() => _isProcessing = false); // End processing on error
      }
    }
  }

  Future<void> _getAIResponse(String userText) async {
    if (_groqApiKey.isEmpty) {
      _addStatusMessage("Error: Groq API Key missing.");
      _addMessage("System Error: API Key missing.", MessageRole.status);
      setState(() => _isProcessing = false);
      return;
    }

    // Check if the user wants to open an app
    if (_isAppOpenRequest(userText)) {
      await _handleAppOpenRequest(userText);
      return;
    }

    // Prepare message history for context
    List<Map<String, String>> messagesPayload = [
      {"role": "system", "content": "You are GeneTrust Medical AI, a specialized medical voice assistant. Your role is to:\n\n1. Provide general medical information and education\n2. Help users understand their symptoms and conditions\n3. Explain medical terms and procedures\n4. Offer preventive care advice\n5. Guide users to appropriate medical resources\n\nImportant guidelines:\n- Always maintain a professional and empathetic tone\n- Clearly state when information is general and not specific medical advice\n- Encourage users to consult healthcare professionals for personal medical concerns\n- Never make definitive diagnoses or prescribe treatments\n- Prioritize user safety and well-being\n- Include relevant medical disclaimers when appropriate\n- Use evidence-based medical information\n- Be clear about the limitations of AI in medical advice\n\nRemember: You are an AI assistant providing general medical information, not a replacement for professional medical care."},
      // Include last few turns (e.g., last 4 turns = 8 messages + system prompt)
      ..._messages
          .where((m) => m.role == MessageRole.user || m.role == MessageRole.assistant)
          .toList()
          .sublist(_messages.length > 9 ? _messages.length - 9 : 0)
          .map((m) => {"role": m.role.name, "content": m.text})
          .toList()
    ];
    // Make sure the last message is the current user prompt if not already added
     if (messagesPayload.last["role"] != "user" || messagesPayload.last["content"] != userText) {
         messagesPayload.add({"role": "user", "content": userText});
     }


    try {
      final response = await http.post(
        Uri.parse(_chatApiUrl),
        headers: {
          "Authorization": "Bearer $_groqApiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": messagesPayload,
          "temperature": 0.7,
          "max_tokens": 150,
          "stream": false,
        }),
      );

      if (!mounted) return; // Check mounted after async gap

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final decodedResponse = jsonDecode(decodedBody);
        final aiResponseText = decodedResponse['choices'][0]['message']['content']?.trim() ?? "Sorry, I couldn't process that.";

        _addMessage(aiResponseText, MessageRole.assistant); // Add AI message
        _addStatusMessage("Generating speech...");
        await _generateSpeech(aiResponseText);

      } else {
        _addStatusMessage("AI Error: ${response.statusCode}");
        _addMessage("Error getting AI response: ${response.statusCode} - ${response.body}", MessageRole.status);
      }
    } catch (e) {
      if (mounted) {
        _addStatusMessage("AI Request Error: $e");
        _addMessage("Error contacting AI: $e", MessageRole.status);
      }
    } finally {
       // Ensure processing state is reset unless speaking has started
       if (mounted && !_isSpeaking) {
         setState(() => _isProcessing = false);
         // If not speaking, revert status to default prompt
         if (!_isSpeaking) _addStatusMessage("Tap the mic to start speaking");
       } else if (mounted && _isSpeaking) {
         // If speaking started, processing logically ends, but wait for TTS completion handler
          setState(() => _isProcessing = false);
       }
    }
  }

  Future<void> _generateSpeech(String text) async {
    if (text.isEmpty) {
      _addStatusMessage("Nothing to speak. Tap mic.");
      if (mounted) setState(() => _isProcessing = false); // End processing
      return;
    }

    try {
      var result = await _flutterTts.speak(text);
      if (result != 1 && mounted) {
        _addStatusMessage("Failed to start TTS. Tap mic.");
        _addMessage("System Error: Could not start TTS.", MessageRole.status);
        setState(() { // Ensure states reset if speak fails immediately
            _isSpeaking = false;
            _isProcessing = false;
        });
      }
       // else: let the Start/Completion/Error handlers manage state
    } catch (e) {
        if (mounted) {
            _addStatusMessage("TTS Exception: $e. Tap mic.");
            _addMessage("System Error: TTS Exception $e", MessageRole.status);
            setState(() {
                _isSpeaking = false;
                _isProcessing = false;
            });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canRecord = !_isRecording && !_isProcessing && !_isSpeaking;
    bool canStop = _isRecording;
    bool isDisabled = _isProcessing || _isSpeaking;

    return Scaffold(
      backgroundColor: _backgroundColor, // Use theme background
      appBar: AppBar(
        title: const Text('GeneTrust Medical AI Voice'),
        backgroundColor: _appBarColor, // Use theme app bar color
        foregroundColor: _isDarkMode ? Colors.white : Colors.black87, // Adjust AppBar icon/text color
        elevation: 1,
        centerTitle: true,
        actions: [ // Add theme toggle button
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: _isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                  ? _buildWelcomeMessage()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message)
                               .animate()
                               .fadeIn(duration: 400.ms)
                               .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
                      },
                    ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 15.0),
                decoration: BoxDecoration(
                  color: _cardColor, // Use theme card color
                  boxShadow: [
                    BoxShadow(
                      color: _shadowColor, // Use themed shadow
                      blurRadius: 8,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _currentStatus,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _statusTextColor, // Use theme status text color
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ScaleTransition(
                      scale: _isRecording
                          ? Tween<double>(begin: 0.85, end: 1.0).animate(_micPulseController!)
                          : const AlwaysStoppedAnimation(1.0),
                      child: FloatingActionButton(
                        onPressed: isDisabled ? null : (canStop ? _stopRecording : _startRecording),
                        tooltip: canStop
                            ? 'Stop Listening'
                            : (isDisabled ? (_isSpeaking ? 'Speaking...' : 'Processing...') : 'Start Listening'),
                        backgroundColor: isDisabled
                            ? Colors.grey.shade400
                            : (canStop ? Colors.red.shade400 : _primaryColor), // Use theme primary color
                        elevation: isDisabled ? 0 : 4.0,
                        child: _isProcessing
                            ? SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(_progressIndicatorColor), // Use theme progress color
                                ),
                              )
                            : Icon(
                                canStop ? Icons.stop_rounded : Icons.mic_rounded,
                                size: 28,
                                color: _onPrimaryColor, // Use theme 'on primary' color for icon
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_isRecording) _buildListeningAnimation(),

        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_none_rounded, size: 80, color: _primaryColor.withOpacity(0.6)),
          const SizedBox(height: 20),
          Text(
            "Getting ready...",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: (_isDarkMode ? Colors.white : Colors.black).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "I'll start listening after my greeting.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: (_isDarkMode ? Colors.white : Colors.black).withOpacity(0.6),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    bool isUser = message.role == MessageRole.user;
    bool isStatus = message.role == MessageRole.status;
    bool isAssistantSpeaking = message.role == MessageRole.assistant && _isSpeaking;

    // Define bubble colors based on role and theme
    Color bubbleColor;
    Color textColor;
    if (isUser) {
      bubbleColor = _primaryColor; // User bubble always primary
      textColor = _onPrimaryColor; // Text color on primary
    } else if (isStatus) {
      bubbleColor = _isDarkMode ? Colors.grey[800]! : Colors.grey[200]!; // Muted status bubble
      textColor = _bubbleTextColorStatus;
    } else {
      bubbleColor = _secondaryContainerColor; // Assistant bubble uses secondary container
      textColor = _onSecondaryContainerColor; // Text color on secondary container
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        decoration: BoxDecoration(
          color: bubbleColor, // Use determined bubble color
          borderRadius: BorderRadius.only(
             topLeft: const Radius.circular(18.0),
             topRight: const Radius.circular(18.0),
             bottomLeft: Radius.circular(isUser ? 18.0 : 4.0),
             bottomRight: Radius.circular(isUser ? 4.0 : 18.0),
          ),
          border: isStatus ? Border.all(color: _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!) : null,
           boxShadow: isStatus ? [] : [
              BoxShadow(
                 color: _shadowColor, // Use themed shadow
                 blurRadius: 3,
                 offset: const Offset(1, 2),
              )
           ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.text,
                style: TextStyle(
                  color: textColor, // Use determined text color
                  fontStyle: isStatus ? FontStyle.italic : FontStyle.normal,
                  height: 1.4,
                ),
              ),
            ),
             if (isAssistantSpeaking)
               Padding(
                 padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                 child: Icon(Icons.volume_up_rounded, size: 16, color: textColor.withOpacity(0.7)) // Use text color for indicator
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .shake(hz: 2, duration: 600.ms, curve: Curves.easeInOut)
                      .moveY(begin: -1, end: 1, duration: 600.ms, curve: Curves.easeInOut),
               ),
          ],
        ),
      ),
    );
  }

  // --- Updated Listening Animation: Pulsing Orb with Orbiting Dot ---
  Widget _buildListeningAnimation() {
    final double orbSize = MediaQuery.of(context).size.width * 0.65;
    final double orbitRadius = (orbSize / 2) + 20;
    final double dotSize = 15.0;

    // --- Base pulsing orb ---
    final orb = Container(
      width: orbSize,
      height: orbSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _primaryColor.withOpacity(0.5),
            _primaryColor.withOpacity(0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .scaleXY(begin: 0.85, end: 1.05, duration: 1400.ms, curve: Curves.easeInOutSine)
        .then(delay: 100.ms)
        .scaleXY(begin: 1.05, end: 0.85, duration: 1300.ms, curve: Curves.easeInOutSine);
        // Removed the ShaderMask for simplicity with the orbit

    // --- Orbiting dot ---
    final orbitingDot = AnimatedBuilder( // Use AnimatedBuilder to listen to orbitController
      animation: _orbitController!,
      builder: (context, child) {
        // Calculate position using angle from controller value (0.0 to 1.0)
        final angle = _orbitController!.value * 2 * 3.14159; // 2 * pi for full circle
        final offset = Offset(
          orbitRadius * cos(angle),
          orbitRadius * sin(angle),
        );
        return Transform.translate(
          offset: offset,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryColor.withOpacity(0.9), // Use primary color
               boxShadow: [ // Add a subtle glow
                 BoxShadow(
                   color: _primaryColor.withOpacity(0.5),
                   blurRadius: 5,
                   spreadRadius: 1,
                 )
               ]
            ),
          ),
        );
      },
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                orb,
                orbitingDot,
              ],
            ),
            // Show message only if it's first time
            if (_isFirstTimeListening)
              Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Text(
                  "Speak now, I'm listening",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ).animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
              ),
          ],
        ),
      ),
    );
  }

  // Add this method to check if the text is asking to open an app
  bool _isAppOpenRequest(String text) {
    text = text.toLowerCase();
    return text.contains('open ') && 
           (text.contains('instagram') || 
            text.contains('facebook') || 
            text.contains('youtube') || 
            text.contains('twitter') || 
            text.contains('tiktok') ||
            text.contains('whatsapp') ||
            text.contains('snapchat') ||
            text.contains('maps') ||
            text.contains('spotify') ||
            // Add more apps as needed
            text.contains('app'));
  }

  // Add this method to handle opening apps with improved app-specific URI schemes
  Future<void> _handleAppOpenRequest(String text) async {
    text = text.toLowerCase();
    String appName = '';
    String? appScheme;
    String? webFallback;
    
    // Define more specific app schemes for different platforms
    if (text.contains('instagram')) {
      appName = 'Instagram';
      appScheme = 'instagram://app';  // More specific Instagram URI
      webFallback = 'https://www.instagram.com';
    } else if (text.contains('facebook')) {
      appName = 'Facebook';
      appScheme = Platform.isIOS ? 'fb://feed' : 'fb://facewebmodal';
      webFallback = 'https://www.facebook.com';
    } else if (text.contains('youtube')) {
      appName = 'YouTube';
      appScheme = 'youtube://';
      webFallback = 'https://www.youtube.com';
    } else if (text.contains('twitter') || text.contains('x app')) {
      appName = 'Twitter/X';
      appScheme = 'twitter://timeline';
      webFallback = 'https://twitter.com';
    } else if (text.contains('tiktok')) {
      appName = 'TikTok';
      appScheme = 'tiktok://';
      webFallback = 'https://www.tiktok.com';
    } else if (text.contains('whatsapp')) {
      appName = 'WhatsApp';
      appScheme = 'whatsapp://';
      webFallback = 'https://web.whatsapp.com';
    } else if (text.contains('snapchat')) {
      appName = 'Snapchat';
      appScheme = 'snapchat://';
      webFallback = 'https://www.snapchat.com';
    } else if (text.contains('maps')) {
      appName = 'Maps';
      if (Platform.isAndroid) {
        appScheme = 'geo:0,0?q=current+location';
        webFallback = 'https://maps.google.com';
      } else if (Platform.isIOS) {
        appScheme = 'maps://';
        webFallback = 'http://maps.apple.com/?q=current+location';
      } else {
        webFallback = 'https://maps.google.com';
      }
    } else if (text.contains('spotify')) {
      appName = 'Spotify';
      appScheme = 'spotify://';
      webFallback = 'https://open.spotify.com';
    } 
    // Add more apps as needed
    
    if (appScheme != null) {
      _addMessage("Attempting to open $appName...", MessageRole.assistant);
      _addStatusMessage("Opening $appName...");
      
      bool launched = false;
      
      try {
        // First attempt: Try to launch with the app URI scheme
        final appUri = Uri.parse(appScheme);
        
        // Force external application mode
        launched = await launchUrl(
          appUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          _addStatusMessage("Opened $appName app successfully.");
        }
      } catch (e) {
        print("App launch error: $e");
        launched = false;
      }
      
      // If the app didn't launch and we have a web fallback
      if (!launched && webFallback != null) {
        try {
          final webUri = Uri.parse(webFallback);
          _addMessage("Could not open the $appName app. Opening website instead.", MessageRole.assistant);
          
          // Try to launch the web fallback
          bool webLaunched = await launchUrl(
            webUri,
            mode: LaunchMode.externalApplication,
          );
          
          if (webLaunched) {
            _addStatusMessage("Opened $appName website.");
          } else {
            _addMessage("Sorry, I couldn't open $appName website either.", MessageRole.assistant);
            _addStatusMessage("Failed to open website.");
          }
        } catch (webError) {
          _addMessage("Sorry, I couldn't open $appName: $webError", MessageRole.assistant);
          _addStatusMessage("Error opening app or website.");
        }
      } else if (!launched) {
        _addMessage("Sorry, I couldn't open the $appName app. It may not be installed.", MessageRole.assistant);
        _addStatusMessage("Failed to open app.");
      }
      
      setState(() => _isProcessing = false);
    } else {
      // If app not recognized, continue with normal AI response
      _addStatusMessage("Processing your request...");
      await _getAIResponseNormal(text);
    }
  }

  // Move the original AI response logic to a separate method
  Future<void> _getAIResponseNormal(String userText) async {
    // Prepare message history for context
    List<Map<String, String>> messagesPayload = [
      {"role": "system", "content": "You are GeneTrust Medical AI, a specialized medical voice assistant. Your role is to:\n\n1. Provide general medical information and education\n2. Help users understand their symptoms and conditions\n3. Explain medical terms and procedures\n4. Offer preventive care advice\n5. Guide users to appropriate medical resources\n\nImportant guidelines:\n- Always maintain a professional and empathetic tone\n- Clearly state when information is general and not specific medical advice\n- Encourage users to consult healthcare professionals for personal medical concerns\n- Never make definitive diagnoses or prescribe treatments\n- Prioritize user safety and well-being\n- Include relevant medical disclaimers when appropriate\n- Use evidence-based medical information\n- Be clear about the limitations of AI in medical advice\n\nRemember: You are an AI assistant providing general medical information, not a replacement for professional medical care."},
      // ... rest of the existing _getAIResponse method ...
    ];
    
    // ... continue with existing AI response code ...
  }

  // Add this new method for initial greeting
  Future<void> _sendInitialGreeting() async {
    final greetings = [
      "Hello! I'm GeneTrust Medical AI. How can I help you with your health today?",
      "Hi! This is GeneTrust Medical AI. What medical question can I help with?",
      "Welcome to GeneTrust Medical AI. How may I assist you with your healthcare needs?",
      "Hello! I'm your AI-powered medical assistant. How can I help you today?",
    ];
    final random = Random();
    final greeting = greetings[random.nextInt(greetings.length)];
    
    _addMessage(greeting, MessageRole.assistant);
    
    try {
      await _flutterTts.speak(greeting);
      // After speaking completes, the TTS completion handler will automatically
      // trigger listening (due to our existing completion handler setup)
    } catch (e) {
      print("Error speaking greeting: $e");
      // If speaking fails, start listening anyway
      if (mounted && !_isRecording && !_isProcessing) {
        _startRecording();
      }
    }
  }
}
