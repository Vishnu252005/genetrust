import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'VoiceChat.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class AdvancedAIChat extends StatefulWidget {
  final String? initialContext;
  final String? initialImage;
  
  const AdvancedAIChat({
    Key? key, 
    this.initialContext,
    this.initialImage,
  }) : super(key: key);

  @override
  _AdvancedAIChatState createState() => _AdvancedAIChatState();
}

class _AdvancedAIChatState extends State<AdvancedAIChat> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Set<int> _starredMessages = Set();
  Map<int, String> _messageReactions = {};
  bool _isLoading = false;
  bool _isDarkMode = true;
  final FlutterTts flutterTts = FlutterTts();
  bool isSpeaking = false;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  Uint8List? webImage;
  String? webImageName;
  bool _isProcessingImage = false;
  String _ocrApiKey = "K89769007088957"; // Free OCR.space API key
  static const String _ocrApiUrl = "https://api.ocr.space/parse/image";
  String _streamingResponse = '';
  bool _isStreaming = false;
  bool _isCompiling = false;
  String? _output;
  static const String _compilerApiUrl = 'https://emkc.org/api/v2/piston/execute';

  // For scroll-to-bottom and scroll-to-top buttons
  bool _showScrollToBottom = false;
  bool _showScrollToTop = false;

  // Update color getters
  Color get _backgroundColor => _isDarkMode 
      ? const Color(0xFF1A1A2E) 
      : const Color(0xFFF8FBFF);
  
  Color get _cardColor => _isDarkMode 
      ? const Color(0xFF252542) 
      : Colors.white;
  
  Color get _textColor => _isDarkMode 
      ? Colors.white 
      : const Color(0xFF2D2D3A);

  Color get _primaryColor => _isDarkMode 
      ? Theme.of(context).colorScheme.primary
      : Theme.of(context).colorScheme.primary;

  static const String _apiKey = "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";
  static const String _apiUrl = "https://api.groq.com/openai/v1/chat/completions";

  // Add these at the top of the class
  String _selectedLanguage = 'python';
  final Map<String, String> _languages = {
    'python': 'python',
    'javascript': 'nodejs',
    'java': 'java',
    'cpp': 'cpp',
    'c': 'c',
    'ruby': 'ruby',
  };

  // Update the language mappings at class level
  final Map<String, Map<String, String>> _languageConfigs = {
    'python': {
      'language': 'python',
      'version': '3.10.0'
    },
    'javascript': {
      'language': 'nodejs',
      'version': '18.15.0'
    },
    'java': {
      'language': 'java',
      'version': '15.0.2'
    },
    'cpp': {
      'language': 'cpp',
      'version': '10.2.0'
    },
    'c': {
      'language': 'c',
      'version': '10.2.0'
    },
    'ruby': {
      'language': 'ruby',
      'version': '3.0.0'
    }
  };

  bool _aiTyping = false;
  List<String> _quickReplies = [
    'Explain my symptoms',
    'Medical advice',
    'Treatment options',
    'Side effects',
    'Preventive care',
    'Emergency warning signs'
  ];

  String _currentSuggestion = '';
  final FocusNode _inputFocusNode = FocusNode();

  // Add health tips list
  final List<String> _healthTips = [
    'Drink at least 8 glasses of water a day.',
    'Get 7-8 hours of sleep every night.',
    'Wash your hands regularly.',
    'Exercise for at least 30 minutes most days.',
    'Eat a variety of fruits and vegetables.',
    'Take regular breaks from screens.',
    'Practice mindfulness or meditation.',
    "Don't skip breakfast.",
    'Limit sugary drinks and snacks.',
    'Schedule regular health checkups.'
  ];
  int _currentTipIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _chatScrollController.addListener(_handleScroll);
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        RawKeyboard.instance.addListener(_handleRawKey);
      } else {
        RawKeyboard.instance.removeListener(_handleRawKey);
      }
    });
    // If there's an initial image, process it as a user-uploaded image
    if (widget.initialImage != null) {
      _selectedImage = File(widget.initialImage!);
      setState(() {
        _messages.add({
          "role": "user",
          "content": "Processing image...",
          "isImage": "true",
          "imagePath": widget.initialImage
        });
      });
      _sendMessageToGroq(_selectedImage);
    }
    // If there's an initial context, add it to the messages
    if (widget.initialContext != null && widget.initialContext!.isNotEmpty) {
      // Add the context as a system message
      _messages = [
        {
          "role": "system",
          "content": "PDF Context: ${widget.initialContext}",
        }
      ];
      // Auto-send a greeting message that acknowledges the context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendInitialMessage();
      });
    }
  }

  void _handleScroll() {
    if (!_chatScrollController.hasClients) return;
    final threshold = 100.0;
    final maxScroll = _chatScrollController.position.maxScrollExtent;
    final currentScroll = _chatScrollController.offset;
    final atBottom = (maxScroll - currentScroll) < threshold;
    final atTop = currentScroll < threshold;
    if (_showScrollToBottom == atBottom || _showScrollToTop == !atTop) {
      setState(() {
        _showScrollToBottom = !atBottom;
        _showScrollToTop = !atTop;
      });
    }
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToTop() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  // Add theme preference loading
  Future<void> _loadThemePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    });
  }

  // Update theme toggle method
  void _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('isDarkMode', _isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _isDarkMode 
                    ? const Color(0xFF2A2A4A).withOpacity(0.9)
                    : Colors.white,
                _isDarkMode 
                    ? const Color(0xFF1A1A2E)
                    : const Color(0xFFF8FBFF),
              ],
            ),
          ),
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _messages.isEmpty
                    ? _buildWelcomeMessage()
                    : _buildChatList(),
              ),
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? _cardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: _textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medical_services_outlined,
              color: _primaryColor,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Flexible(
            child: Text(
              'GeneTrust Medical AI',
              style: TextStyle(
                color: _textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.emergency_outlined, color: _textColor),
            tooltip: 'Emergency Information',
            onPressed: () => _showEmergencyInfo(),
          ),
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _textColor,
            ),
            onPressed: () => _toggleTheme(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildWelcomeMessage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildHealthTipsCard(),
          _buildQuickActions(),
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: _primaryColor,
            ),
          ).animate()
            .scale(duration: 400.ms, curve: Curves.easeOut)
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.3, end: 0),
          SizedBox(height: 32),
          Text(
            'Welcome to\nGeneTrust Medical AI',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ).animate()
            .fadeIn(duration: 400.ms, delay: 400.ms)
            .slideY(begin: 0.3, end: 0),
          SizedBox(height: 16),
          Text(
            'Your AI-powered medical assistant for personalized healthcare guidance',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor.withOpacity(0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ).animate()
            .fadeIn(duration: 400.ms, delay: 600.ms)
            .slideY(begin: 0.3, end: 0),
          SizedBox(height: 24),
          _buildMedicalDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildMedicalDisclaimer() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.red.withOpacity(0.1) : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, 
                color: Colors.red[400],
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Medical Disclaimer',
                style: TextStyle(
                  color: Colors.red[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'This AI assistant provides general medical information only. It is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider.',
            style: TextStyle(
              color: _textColor.withOpacity(0.8),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: 600.ms)
      .slideY(begin: 0.3, end: 0);
  }

  Widget _buildChatList() {
    return Stack(
      children: [
        ListView.builder(
          controller: _chatScrollController,
      padding: EdgeInsets.all(16),
          itemCount: _messages.length + (_aiTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (_aiTyping && index == _messages.length) {
              return _buildTypingIndicator();
            }
            return _buildMessageItem(context, index);
          },
        ).animate().fadeIn(duration: 300.ms),
        if (_showScrollToBottom || _showScrollToTop)
          Positioned(
            right: 16,
            bottom: 24 + 64, // above input area
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showScrollToTop)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: _primaryColor,
                      onPressed: _scrollToTop,
                      child: Icon(Icons.arrow_upward, color: Colors.white),
                      tooltip: 'Scroll to top',
                      elevation: 2,
                    ),
                  ),
                if (_showScrollToBottom)
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: _primaryColor,
                    onPressed: _scrollToBottom,
                    child: Icon(Icons.arrow_downward, color: Colors.white),
                    tooltip: 'Scroll to bottom',
                    elevation: 2,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? _cardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.image, color: _isDarkMode ? Colors.white : Colors.grey[700]),
            tooltip: 'Send an image',
            onPressed: _isProcessingImage ? null : _pickImage,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _isDarkMode 
                    ? Colors.black.withOpacity(0.3) 
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: _isDarkMode 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey[300]!,
                ),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Ghost suggestion text
                  if (_controller.text.isNotEmpty && _currentSuggestion.isNotEmpty && _currentSuggestion != _controller.text)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: RichText(
                        text: TextSpan(
                          text: _controller.text,
                          style: TextStyle(color: _textColor, fontSize: 16),
                          children: [
                            TextSpan(
                              text: _currentSuggestion.substring(_controller.text.length),
                              style: TextStyle(color: _textColor.withOpacity(0.4), fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  TextField(
                    controller: _controller,
                    style: TextStyle(color: _textColor, fontSize: 16),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      hintStyle: TextStyle(
                        color: _textColor.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _currentSuggestion = '';
                        if (val.isNotEmpty) {
                          final match = _quickReplies.firstWhere(
                            (s) => s.toLowerCase().startsWith(val.toLowerCase()) && s.length > val.length,
                            orElse: () => '',
                          );
                          _currentSuggestion = match;
                        }
                      });
                    },
                    onEditingComplete: () {},
                    onSubmitted: (_) {},
                    onTap: () {},
                    autofocus: false,
                    textInputAction: TextInputAction.newline,
                    focusNode: _inputFocusNode,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Add voice button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withOpacity(0.8),
                  _primaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.mic_rounded, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VoiceChat()),
                );
              },
            ),
          ),
          SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor,
                  _primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _isProcessingImage ? null : _sendMessage,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildMessageItem(BuildContext context, int index) {
    final message = _messages[index];
    final isUser = message['role'] == 'user';
    final isImage = message['isImage'] == 'true';
    final isStreaming = message['isStreaming'] == true;
    final isStarred = _starredMessages.contains(index);
    final reaction = _messageReactions[index];
    final content = message['content'] as String;
    final hasCodeBlock = content.contains('```');

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  margin: EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    backgroundColor: _primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              Stack(
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: EdgeInsets.only(
                      top: 8,
                      bottom: isUser ? 8 : 4,
                    ),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUser
                          ? (_isDarkMode ? Color(0xFF2962FF) : Colors.blue[100])
                          : (_isDarkMode ? _cardColor : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isImage) ...[
                          if (kIsWeb && message['webImage'] != null) // Handle web image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                message['webImage'] as Uint8List,
                                fit: BoxFit.cover,
                              ),
                            )
                          else if (!kIsWeb && message['imagePath'] != null) // Handle mobile image from path
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(message['imagePath'] as String),
                                fit: BoxFit.cover,
                              ),
                            ),
                          if (message['content'] != "Processing image...")
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: _buildMarkdownContent(message['content'] as String),
                            ),
                          if (message['content'] == "Processing image...") // Show loading indicator or specific text for processing state
                             Padding(
                               padding: EdgeInsets.only(top: 8),
                               child: Text("Processing image...", style: TextStyle(fontStyle: FontStyle.italic, color: _textColor.withOpacity(0.7))),
                             ),
                        ] else if (isStreaming) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildMarkdownContent(message['content'] as String),
                              ),
                              if (_isStreaming)
                                Container(
                                  width: 2,
                                  height: 16,
                                  margin: EdgeInsets.only(left: 2),
                                  color: _textColor,
                                ).animate(
                                  onPlay: (controller) => controller.repeat(),
                                ).fadeOut(
                                  duration: 600.ms,
                                ).fadeIn(
                                  duration: 600.ms,
                                ),
                            ],
                          ),
                        ] else ...[
                          _buildMarkdownContent(content),
                          if (hasCodeBlock && !isUser)
                            _buildCodeExecutionButton(content),
                        ],
                        if (reaction != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(reaction, style: TextStyle(fontSize: 20)),
                          ),
                      ],
                    ),
                  ),
                  if (isStarred)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.star, color: Colors.amber, size: 20),
                    ),
                ],
              ),
              if (isUser)
                Container(
                  margin: EdgeInsets.only(left: 8),
                  child: CircleAvatar(
                    backgroundColor: _primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person_outline,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          // Action buttons for AI messages
          if (message['role'] == 'assistant' && !isStreaming && message['content'] != null)
            Padding(
              padding: EdgeInsets.only(
                left: 8,
                right: MediaQuery.of(context).size.width * 0.2,
                bottom: 8,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildActionButton(
                    icon: Icons.copy_outlined,
                    label: 'Copy',
                    onTap: () {
                      String textToCopy = message['content']!.replaceAll(RegExp(r'\*\*'), '');
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Text copied to clipboard'),
                          backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey[900],
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                    label: isSpeaking ? 'Stop' : 'Listen',
                    onTap: () {
                      String textToSpeak = message['content']!.replaceAll(RegExp(r'\*\*'), '');
                      _handleTTS(textToSpeak);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: () {
                      String textToShare = message['content']!.replaceAll(RegExp(r'\*\*'), '');
                      _showShareOptions(context, textToShare);
                    },
                  ),
                ],
              ),
            ),
          // Quick reply suggestions for AI messages
          if (message['role'] == 'assistant' && !isStreaming && message['content'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Wrap(
                spacing: 8,
                children: _quickReplies.map((reply) => ActionChip(
                  label: Text(reply),
                  onPressed: () {
                    _controller.text = reply;
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(String content) {
    // Clean and format the content
    String cleanedContent = _cleanAndFormatContent(content);
    
    return MarkdownBody(
      data: cleanedContent,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: _textColor,
          fontSize: 16,
          height: 1.5,
        ),
        h1: TextStyle(
          color: _textColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h2: TextStyle(
          color: _textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        h3: TextStyle(
          color: _textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        strong: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.bold,
        ),
        em: TextStyle(
          color: _textColor,
          fontStyle: FontStyle.italic,
        ),
        blockquote: TextStyle(
          color: _textColor.withOpacity(0.8),
          fontStyle: FontStyle.italic,
        ),
        code: TextStyle(
          color: _isDarkMode ? Color(0xFF9ECBFF) : Color(0xFF2563EB),
          backgroundColor: _isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFF0F0F0),
          fontFamily: 'JetBrains Mono',
        ),
        codeblockDecoration: BoxDecoration(
          color: _isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        listBullet: TextStyle(
          color: _textColor,
          fontSize: 16,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: _primaryColor,
              width: 4,
            ),
          ),
        ),
      ),
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
    );
  }

  String _cleanAndFormatContent(String content) {
    // 0. Decode unicode emoji escape sequences (e.g. \uXXXX or \u{XXXX})
    String decodeUnicode(String input) {
      // Handle \uXXXX
      input = input.replaceAllMapped(
        RegExp(r'\\u([0-9A-Fa-f]{4})'),
        (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
      );
      // Handle \u{XXXX}
      input = input.replaceAllMapped(
        RegExp(r'\\u\{([0-9A-Fa-f]+)\}'),
        (m) => String.fromCharCodes([int.parse(m[1]!, radix: 16)]),
      );
      return input;
    }

    // 0.25. Replace common graphic descriptions with emoji
    String convertDescriptionsToEmoji(String input) {
      final descMap = {
        'bell': '🔔',
        'pencil': '✏️',
        'star': '⭐',
        'piece of paper': '📄',
        'paper': '📄',
        'blue and white color scheme': '🔵⚪',
        'call-to-action': '👉',
        'swipe up': '⬆️',
        'graphics': '🎨',
      };
      descMap.forEach((k, v) {
        input = input.replaceAll(RegExp(r'(?<=\s|^)' + RegExp.escape(k) + r'(?=\s|\.|,|$)', caseSensitive: false), v);
      });
      return input;
    }

    // 0.5. Convert common emoji shortcodes to unicode emoji
    String convertShortcodes(String input) {
      final emojiMap = {
        ':tada:': '🎉',
        ':smile:': '😄',
        ':rocket:': '🚀',
        ':checkered_flag:': '🏁',
        ':star:': '⭐',
        ':fire:': '🔥',
        ':100:': '💯',
        ':warning:': '⚠️',
        ':heavy_check_mark:': '✔️',
        ':x:': '❌',
        ':bulb:': '💡',
        ':wave:': '👋',
        ':calendar:': '📅',
        ':moneybag:': '💰',
        ':books:': '📚',
        ':memo:': '📝',
        ':pushpin:': '📌',
        ':bell:': '🔔',
        ':hourglass:': '⏳',
        ':mag:': '🔍',
        ':lock:': '🔒',
        ':unlock:': '🔓',
        ':zap:': '⚡',
        ':clap:': '👏',
        ':thumbsup:': '👍',
        ':thumbsdown:': '👎',
        ':question:': '❓',
        ':exclamation:': '❗',
      };
      emojiMap.forEach((k, v) {
        input = input.replaceAll(k, v);
      });
      return input;
    }

    content = decodeUnicode(content);
    content = convertDescriptionsToEmoji(content);
    content = convertShortcodes(content);

    // 1. Replace weird characters
    String cleaned = content
        .replaceAll('â¢', '•')
        .replaceAll('â¢', '•')
        .replaceAll('â', '')
        .replaceAll('€', '')
        .replaceAll('¢', '')
        .replaceAll('•\s*•', '•') // Remove double bullets
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 1.5. Convert frac{a}{b} to a / b
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'frac\{([^}]+)\}\{([^}]+)\}'),
      (m) => '${m[1]} / ${m[2]}'
    );

    // 2. Split into lines for smarter processing
    List<String> lines = cleaned.split('\n');
    List<String> result = [];
    bool inList = false;
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      // Remove empty lines and lines that are just = or -
      if (line.isEmpty || line == '=' || line == '-' || line == '•') continue;
      // Headings: make lines with 'Solution', 'Part', 'Given', etc. bold and/or headers
      if (RegExp(r'^(Problem|Part|Given|Solution|Step|Overview|Details|Requirements|Contact|Additional|Answer|Explanation|Section|Summary)', caseSensitive: false).hasMatch(line)) {
        if (!line.startsWith('##')) line = '## $line';
        result.add(line);
        inList = false;
        continue;
      }
      // List items: lines starting with bullet or *
      if (line.startsWith('•') || line.startsWith('*')) {
        if (!inList) {
          inList = true;
        }
        // Remove duplicate bullets and extra spaces
        line = line.replaceFirst(RegExp(r'^[•*]\s*'), '- ');
        result.add(line);
        continue;
      } else {
        inList = false;
      }
      // Equations or values: lines with only numbers or Rs. or =
      if (RegExp(r'^(Rs\.|\d|=|\+|\-|\*|\/|\^|\(|\)).*').hasMatch(line)) {
        // Format as inline code
        result.add('`$line`');
        continue;
      }
      // Bold key-value pairs
      if (line.contains(':')) {
        var parts = line.split(':');
        if (parts.length == 2) {
          result.add('**${parts[0].trim()}**: ${parts[1].trim()}');
          continue;
        }
      }
      // Default: just add the line
      result.add(line);
    }
    // 3. Join and clean up extra newlines
    String finalText = result.join('\n');
    finalText = finalText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return finalText;
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    String userMessage = _controller.text;
    _controller.clear();
    
    setState(() {
      _messages.add({
        "role": "user", 
        "content": userMessage
      });
      _isLoading = true;
      _isStreaming = true;
      _streamingResponse = '';
      _messages.add({
        "role": "assistant", 
        "content": "",
        "isStreaming": true,
        "isImage": "false"
      });
    });

    try {
      // Create messages array with context from previous messages
      List<Map<String, String>> messageHistory = [];
      
      // Add system message first
      messageHistory.add({
        "role": "system",
        "content": """You are GeneTrust Medical AI, a specialized medical assistant focused on providing healthcare information and guidance. Your role is to:

1. Provide general medical information and education
2. Help users understand their symptoms and conditions
3. Explain medical terms and procedures
4. Offer preventive care advice
5. Guide users to appropriate medical resources

Important guidelines:
- Always maintain a professional and empathetic tone
- Clearly state when information is general and not specific medical advice
- Encourage users to consult healthcare professionals for personal medical concerns
- Never make definitive diagnoses or prescribe treatments
- Prioritize user safety and well-being
- Include relevant medical disclaimers when appropriate
- Use evidence-based medical information
- Be clear about the limitations of AI in medical advice

Remember: You are an AI assistant providing general medical information, not a replacement for professional medical care."""
      });

      // Add previous messages for context (limit to last 10 messages)
      int startIndex = _messages.length > 20 ? _messages.length - 20 : 0;
      for (int i = startIndex; i < _messages.length; i++) {
        final msg = _messages[i];
        // Skip messages that are images or processing states
        if (msg['isImage'] == true || msg['content'] == "Processing image...") {
          continue;
        }
        messageHistory.add({
          "role": msg['role'] as String,
          "content": msg['content'] as String,
        });
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
          "Accept": "text/event-stream",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": messageHistory,  // Use the message history instead of just the current message
          "temperature": 0.7,
          "max_tokens": 1000,
          "stream": true,
        }),
      );

      if (response.statusCode == 200) {
        final stream = response.body.split('\n');
        
        for (var line in stream) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            try {
              final data = jsonDecode(line.substring(6));
              final content = data['choices'][0]['delta']['content'] ?? '';
              
              setState(() {
                _streamingResponse += content;
                _messages.last['content'] = _streamingResponse;
              });
              
              // Add a small delay for visual effect
              await Future.delayed(Duration(milliseconds: 10));
            } catch (e) {
              print('Error parsing streaming response: $e');
            }
          }
        }
        // After streaming, ensure the message is marked as assistant and isImage false
        setState(() {
          _messages.last['role'] = 'assistant';
          _messages.last['isImage'] = 'false';
          _messages.last.remove('isStreaming');
        });
      } else {
        setState(() {
          _messages.last['content'] = "Something went wrong, bro. Just try again after some time!";
          _messages.last['role'] = 'assistant';
          _messages.last['isImage'] = 'false';
          _messages.last.remove('isStreaming');
        });
      }
    } catch (e) {
      setState(() {
        _messages.last['content'] = "Something went wrong, bro. Just try again after some time!";
        _messages.last['role'] = 'assistant';
        _messages.last['isImage'] = 'false';
        _messages.last.remove('isStreaming');
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isStreaming = false;
      });
    }

    // After sending/receiving a message, scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isDarkMode 
              ? Colors.grey[800]!.withOpacity(0.3)
              : Colors.grey[200]!,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: _textColor.withOpacity(0.8),
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _textColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareOptions(BuildContext context, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? _cardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
        children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Share Response',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareButton(
                    icon: Icons.copy_outlined,
                    label: 'Copy',
                    color: Colors.blue,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: content));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Response copied to clipboard'),
                          backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey[900],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
                  _buildShareButton(
                    icon: Icons.telegram,
                    label: 'Telegram',
                    color: Color(0xFF0088cc),
                    onTap: () async {
                      final url = 'https://t.me/share/url?url=${Uri.encodeComponent(content)}';
                      if (await canLaunch(url)) {
                        Navigator.pop(context);
                        await launch(url);
                      } else {
                        Share.share(content);
                      }
                    },
                  ),
                  _buildShareButton(
                    icon: Icons.share,
                    label: 'More',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      Share.share(content);
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ).animate().slideY(
          begin: 1,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutQuad,
        );
      },
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: _textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      ),
    ).animate().scale(
      duration: 300.ms,
      delay: 200.ms,
      curve: Curves.easeOutQuad,
    );
  }

  Future<void> _handleTTS(String content) async {
    try {
      if (isSpeaking) {
        await flutterTts.stop();
        setState(() => isSpeaking = false);
      } else {
        // Initialize TTS if not already initialized
        await flutterTts.awaitSpeakCompletion(true);
        await flutterTts.setLanguage("en-US");
        await flutterTts.setPitch(1.0);
        await flutterTts.setSpeechRate(0.5);
        
        // Clear any existing handlers by setting empty callbacks
        flutterTts.setCompletionHandler(() {});
        flutterTts.setErrorHandler((msg) {});
        flutterTts.setCancelHandler(() {});
        
        // Set new handlers
        flutterTts.setCompletionHandler(() {
          setState(() => isSpeaking = false);
        });
        
        flutterTts.setErrorHandler((msg) {
          setState(() => isSpeaking = false);
          print("TTS Error: $msg");
        });
        
        flutterTts.setCancelHandler(() {
          setState(() => isSpeaking = false);
        });
        
        setState(() => isSpeaking = true);
        
        // Wait for any previous speech to complete
        await Future.delayed(Duration(milliseconds: 100));
        
        // Speak the content
        await flutterTts.speak(content);
      }
    } catch (e) {
      print("TTS Error: $e");
      setState(() => isSpeaking = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _isProcessingImage = true);
      
      if (kIsWeb) {
        final html.FileUploadInputElement input = html.FileUploadInputElement()
          ..accept = 'image/*';
        input.click();

        await input.onChange.first;
        if (input.files?.isEmpty ?? true) return;

        final reader = html.FileReader();
        reader.readAsArrayBuffer(input.files![0]);
        await reader.onLoad.first;

        final imageBytes = Uint8List.fromList(reader.result as List<int>);
        
        if (imageBytes.length > 5 * 1024 * 1024) {
          throw Exception('Image size too large. Please choose an image under 5MB.');
        }

        setState(() {
          webImage = imageBytes;
          webImageName = input.files![0].name;
          _messages.add({
            "role": "user",
            "content": "Processing image...",
            "isImage": "true",
            "webImage": webImage,
            "imageName": webImageName
          });
        });

        // Send image directly to Groq for analysis
        await _sendMessageToGroq(webImage);

      } else {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 90,
        );
        
        if (image != null) {
          final bytes = await image.readAsBytes();
          if (bytes.length > 5 * 1024 * 1024) {
            throw Exception('Image size too large. Please choose an image under 5MB.');
          }

          setState(() {
            _selectedImage = File(image.path);
            _messages.add({
              "role": "user",
              "content": "Processing image...",
              "isImage": "true",
              "imagePath": image.path
            });
          });

          // Send image directly to Groq for analysis
          await _sendMessageToGroq(_selectedImage);
        }
      }
    } catch (e) {
      print('Image processing error: $e'); // Add error logging
      setState(() => _isProcessingImage = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey[900],
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isProcessingImage = false);
    }
  }

  Future<String> _extractTextFromImage(dynamic image) async {
    try {
      setState(() => _isProcessingImage = true);
      
      var request = http.MultipartRequest('POST', Uri.parse(_ocrApiUrl));
      request.headers.addAll({
        'apikey': _ocrApiKey,
      });

      if (image is File) {
        // Handle mobile file
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          image.path,
          contentType: MediaType('image', path.extension(image.path).substring(1)),
        ));
      } else if (image is Uint8List) {
        // Handle web file
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          image,
          filename: 'image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      request.fields['language'] = 'eng';
      request.fields['isOverlayRequired'] = 'false';
      request.fields['detectOrientation'] = 'true';

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData);

      if (response.statusCode == 200) {
        if (jsonData['ParsedResults'] != null && 
            jsonData['ParsedResults'].isNotEmpty) {
          return jsonData['ParsedResults'][0]['ParsedText'];
        } else {
          throw Exception('No text found in the image');
        }
      } else {
        throw Exception('OCR API error: ${jsonData['ErrorMessage']}');
      }
    } catch (e) {
      print('OCR Error: $e');
      throw Exception('Failed to extract text from image');
    } finally {
      setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _sendMessageToGroq(dynamic image) async {
    try {
      // Convert image to base64
      String base64Image;
      if (image is File) {
        final bytes = await image.readAsBytes();
        base64Image = base64Encode(bytes);
      } else if (image is Uint8List) {
        base64Image = base64Encode(image);
      } else {
        throw Exception('Unsupported image type');
      }

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "meta-llama/llama-4-scout-17b-16e-instruct",
          "messages": [
            {
              "role": "system",
              "content": """You are an AI assistant that analyzes images. When analyzing documents, especially academic ones, structure your response in a clear, organized format using markdown. Include:\n\n1. A brief overview\n2. Main sections with clear headers\n3. Bullet points for key details\n4. Bold text for important terms\n5. Proper spacing and formatting\n6. Mathematical expressions in LaTeX format when needed\n\nMake the response easy to read and visually appealing."""
            },
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text": "Please analyze this image and provide a detailed, well-structured response using markdown formatting."
                },
                {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:image/jpeg;base64,$base64Image"
                  }
                }
              ]
            }
          ],
          "temperature": 0.7,
          "max_tokens": 1024,
          "top_p": 1,
          "stream": false
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String aiResponse = data['choices'][0]['message']['content'];

        setState(() {
          _messages.add({
            "role": "assistant",
            "content": aiResponse,
            "isImage": "true"
          });
        });
      } else {
        print('Error response: ${response.body}');
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "Something went wrong, bro. Just try again after some time!",
            "isImage": "true"
          });
        });
      }
    } catch (e) {
      print('Groq AI Error: $e');
      setState(() {
        _messages.add({
          "role": "assistant",
          "content": "Something went wrong, bro. Just try again after some time!",
          "isImage": "true"
        });
      });
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    _chatScrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _handleRawKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      if (_currentSuggestion.isNotEmpty && _currentSuggestion != _controller.text) {
        setState(() {
          _controller.text = _currentSuggestion;
          _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
        });
      }
      // Prevent default tab behavior
      FocusScope.of(context).requestFocus(_inputFocusNode);
    }
  }

  Widget _buildTypingIndicator() {
    return _aiTyping
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                SizedBox(width: 16),
                CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_primaryColor)),
                SizedBox(width: 12),
                Text('Vihaya is typing...', style: TextStyle(color: _textColor.withOpacity(0.7))),
              ],
            ),
          )
        : SizedBox.shrink();
  }

  // Implement initial message sending logic
  Future<void> _sendInitialMessage() async {
    setState(() {
      _isLoading = true;
      _isStreaming = true;
      _streamingResponse = '';
      _messages.add({
        "role": "assistant",
        "content": "",
        "isStreaming": true,
        "isImage": "false" // Ensure isImage is set for text replies
      });
    });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
          "Accept": "text/event-stream",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": [
            {
              "role": "system",
              "content": "You are a helpful AI assistant. The user is viewing a PDF document. Help them understand, analyze, or take notes on the content."
            },
            {
              "role": "user",
              "content": "I'm viewing this PDF: ${widget.initialContext}. How can you help me study or analyze it?"
            }
          ],
          "temperature": 0.7,
          "max_tokens": 300,
          "stream": true,
        }),
      );

      if (response.statusCode == 200) {
        final stream = response.body.split('\n');

        for (var line in stream) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            try {
              final data = jsonDecode(line.substring(6));
              final content = data['choices'][0]['delta']['content'] ?? '';

              setState(() {
                _streamingResponse += content;
                _messages.last['content'] = _streamingResponse;
              });

              await Future.delayed(Duration(milliseconds: 10));
            } catch (e) {
              print('Error parsing streaming response: $e');
            }
          }
        }
        // After streaming, finalize message state
        setState(() {
          _messages.last['role'] = 'assistant';
          _messages.last['isImage'] = 'false';
          _messages.last.remove('isStreaming');
        });
      } else {
        setState(() {
          _messages.last['content'] = "Something went wrong, bro. Just try again after some time!";
          _messages.last['role'] = 'assistant';
          _messages.last['isImage'] = 'false';
          _messages.last.remove('isStreaming');
        });
      }
    } catch (e) {
      setState(() {
        _messages.last['content'] = "Something went wrong, bro. Just try again after some time!";
        _messages.last['role'] = 'assistant';
        _messages.last['isImage'] = 'false';
        _messages.last.remove('isStreaming');
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isStreaming = false;
      });
    }
  }

  // Implement image processing logic
  Future<void> _processInitialImage() async {
    try {
      setState(() {
        _isProcessingImage = true;
        // Add a user message indicating image processing
        _messages.add({
          "role": "user",
          "content": "Processing image...",
          "isImage": "true",
          "imagePath": widget.initialImage // Include image path for display
        });
      });

      if (widget.initialImage != null) {
         final File imageFile = File(widget.initialImage!); // Load the image file
         // Send the image directly to Groq AI for analysis
         await _sendMessageToGroq(imageFile);
      }

    } catch (e) {
      print('Initial image processing error: $e');
      setState(() {
         _messages.add({
          "role": "assistant",
          "content": "Something went wrong, bro. Just try again after some time!",
          "isImage": "false" // Error is a text reply
        });
      });
    } finally {
      setState(() => _isProcessingImage = false);
    }
  }

  Widget _buildCodeExecutionButton(String content) {
    final codeBlocks = RegExp(r'```(\w+)?\n([\s\S]*?)```').allMatches(content);
    
    return Column(
      children: codeBlocks.map((match) {
        final language = (match.group(1) ?? 'python').toLowerCase();
        final code = match.group(2) ?? '';
        final supportedLang = _languages.containsKey(language) ? language : 'python';
        final codeController = TextEditingController(text: code);

        return Container(
          margin: EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.code, size: 16, color: _textColor),
                    SizedBox(width: 8),
                    Text(
                      supportedLang.toUpperCase(),
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeController,
                      maxLines: null,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        color: _isDarkMode ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.play_arrow, color: _primaryColor),
                          label: Text(
                            'Run Code',
                            style: TextStyle(color: _primaryColor),
                          ),
                          onPressed: () => _executeCode(codeController.text, supportedLang),
                        ),
                      ],
                    ),
                    if (_isCompiling || _output != null)
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Color(0xFF2D2D2D) : Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Terminal Header
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFD0D0D0),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.red[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.amber[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Terminal',
                                    style: TextStyle(
                                      color: _textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Terminal Content
                            Container(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_isCompiling)
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(_primaryColor),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Running code...',
                                          style: TextStyle(
                                            color: _textColor.withOpacity(0.7),
                                            fontSize: 12,
                                            fontFamily: 'JetBrains Mono',
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (_output != null)
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.terminal,
                                                size: 14,
                                                color: _textColor.withOpacity(0.7),
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Output:',
                                                style: TextStyle(
                                                  color: _textColor.withOpacity(0.7),
                                                  fontSize: 12,
                                                  fontFamily: 'JetBrains Mono',
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          SelectableText(
                                            _output!,
                                            style: TextStyle(
                                              color: _textColor,
                                              fontSize: 12,
                                              fontFamily: 'JetBrains Mono',
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _executeCode(String code, String language) async {
    setState(() {
      _isCompiling = true;
      _output = null;
    });

    try {
      final response = await http.post(
        Uri.parse(_compilerApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'language': _languageConfigs[language.toLowerCase()]!['language'],
          'version': _languageConfigs[language.toLowerCase()]!['version'],
          'files': [
            {
              'name': 'main.${language.toLowerCase()}',
              'content': code,
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _output = data['run']['output'] ?? 'No output';
          if (data['run']['stderr'] != null && data['run']['stderr'].isNotEmpty) {
            _output = 'Error: ${data['run']['stderr']}';
          }
        });
      } else {
        setState(() {
          _output = 'Something went wrong, bro. Just try again after some time!';
        });
      }
    } catch (e) {
      setState(() {
        _output = 'Something went wrong, bro. Just try again after some time!';
      });
    } finally {
      setState(() {
        _isCompiling = false;
      });
    }
  }

  Future<void> _downloadChatAsPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('VIHAYA AI Chat', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          ..._messages.map((msg) {
            final isUser = msg['role'] == 'user';
            final content = msg['content'] ?? '';
            return pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 60,
                    child: pw.Text(isUser ? 'You:' : 'AI:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    child: pw.Text(content, style: pw.TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
    try {
      if (kIsWeb) {
        final bytes = await pdf.save();
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement()
          ..href = url
          ..style.display = 'none'
          ..download = 'vihaya_ai_chat.pdf';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat PDF downloaded successfully')),
        );
      } else {
        final output = await getApplicationDocumentsDirectory();
        final file = File('${output.path}/vihaya_ai_chat.pdf');
        await file.writeAsBytes(await pdf.save());
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Chat PDF Generated'),
              content: Text('What would you like to do with the PDF?'),
              actions: [
                TextButton(
                  onPressed: () async {
                    await OpenFile.open(file.path);
                    Navigator.pop(context);
                  },
                  child: Text('Open'),
                ),
                TextButton(
                  onPressed: () async {
                    await Share.shareXFiles([XFile(file.path)], text: 'VIHAYA AI Chat PDF');
                    Navigator.pop(context);
                  },
                  child: Text('Share'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  void _showEmergencyInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.emergency, color: Colors.red),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Emergency Information',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'In case of emergency:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Call emergency services immediately'),
              Text('• Your local emergency number: 911'),
              Text('• Go to the nearest emergency room'),
              SizedBox(height: 16),
              Text(
                'This AI assistant is not for emergency situations.',
                style: TextStyle(
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showNextTip() {
    setState(() {
      _currentTipIndex = (_currentTipIndex + 1) % _healthTips.length;
    });
  }

  Widget _buildHealthTipsCard() {
    return Card(
      color: _isDarkMode ? _cardColor : Colors.white,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.local_hospital, color: _primaryColor),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _healthTips[_currentTipIndex],
                style: TextStyle(color: _textColor, fontSize: 16),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: _primaryColor),
              onPressed: _showNextTip,
              tooltip: 'Next Tip',
            ),
          ],
        ),
      ),
    );
  }

  // Add Symptom Checker and BMI Calculator quick actions
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(
            icon: Icons.health_and_safety,
            label: 'Symptom Checker',
            onTap: _showSymptomChecker,
          ),
          _buildQuickActionButton(
            icon: Icons.monitor_weight,
            label: 'BMI Calculator',
            onTap: _showBMICalculator,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label, style: TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        elevation: 2,
      ),
      onPressed: onTap,
    );
  }

  // Symptom Checker dialog
  void _showSymptomChecker() {
    showDialog(
      context: context,
      builder: (context) {
        final List<String> symptoms = [
          'Fever', 'Cough', 'Headache', 'Fatigue', 'Nausea', 'Sore throat', 'Shortness of breath', 'Chest pain', 'Dizziness', 'Rash'
        ];
        final Set<String> selected = {};
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Symptom Checker'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select your symptoms:'),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: symptoms.map((symptom) => FilterChip(
                      label: Text(symptom),
                      selected: selected.contains(symptom),
                      onSelected: (val) {
                        setState(() {
                          if (val) selected.add(symptom);
                          else selected.remove(symptom);
                        });
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selected.isEmpty ? null : () {
                  Navigator.pop(context);
                  _showSymptomResult(selected);
                },
                child: Text('Check'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSymptomResult(Set<String> symptoms) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Possible Causes'),
        content: Text('You selected: ${symptoms.join(", ")}.\n\nThis is not a diagnosis. Please consult a healthcare professional for an accurate assessment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // BMI Calculator dialog
  void _showBMICalculator() {
    showDialog(
      context: context,
      builder: (context) {
        final heightController = TextEditingController();
        final weightController = TextEditingController();
        String? result;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('BMI Calculator'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Height (cm)'),
                ),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Weight (kg)'),
                ),
                if (result != null) ...[
                  SizedBox(height: 12),
                  Text(result!, style: TextStyle(fontWeight: FontWeight.bold)),
                ]
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final h = double.tryParse(heightController.text);
                  final w = double.tryParse(weightController.text);
                  if (h != null && w != null && h > 0) {
                    final bmi = w / ((h / 100) * (h / 100));
                    String category;
                    if (bmi < 18.5) category = 'Underweight';
                    else if (bmi < 25) category = 'Normal weight';
                    else if (bmi < 30) category = 'Overweight';
                    else category = 'Obese';
                    setState(() {
                      result = 'Your BMI is ${bmi.toStringAsFixed(1)} ($category)';
                    });
                  } else {
                    setState(() {
                      result = 'Please enter valid numbers.';
                    });
                  }
                },
                child: Text('Calculate'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Add these classes at the end of the file
abstract class ThemeColors {
  Color get background;
  Color get appBarBackground;
  Color get appBarText;
  Color get messageText;
  Color get userBubbleBackground;
  Color get aiBubbleBackground;
  Color get terminalBackground;
  Color get terminalHeader;
  Color get codeText;
  Color get copyButtonColor;
  Color get languageTagBackground;
  Color get languageTagText;
  Color get inputBackground;
  Color get inputFieldBackground;
  Color get inputText;
  Color get inputHintText;
  Color get sendButtonBackground;
  Color get sendButtonIcon;
  Color get loadingIndicator;
  Color get snackbarBackground;
}

class LightThemeColors extends ThemeColors {
  @override Color get background => Colors.grey[100]!;
  @override Color get appBarBackground => Colors.white;
  @override Color get appBarText => Colors.black87;
  @override Color get messageText => Colors.black87;
  @override Color get userBubbleBackground => Colors.blue[100]!;
  @override Color get aiBubbleBackground => Colors.white;
  @override Color get terminalBackground => Color(0xFF1E1E1E);
  @override Color get terminalHeader => Color(0xFF2D2D2D);
  @override Color get codeText => Colors.white;
  @override Color get copyButtonColor => Colors.grey[400]!;
  @override Color get languageTagBackground => Colors.grey[700]!;
  @override Color get languageTagText => Colors.white;
  @override Color get inputBackground => Colors.white;
  @override Color get inputFieldBackground => Colors.grey[100]!;
  @override Color get inputText => Colors.black87;
  @override Color get inputHintText => Colors.grey[600]!;
  @override Color get sendButtonBackground => Colors.blue;
  @override Color get sendButtonIcon => Colors.white;
  @override Color get loadingIndicator => Colors.blue;
  @override Color get snackbarBackground => Colors.grey[800]!;
}

class DarkThemeColors extends ThemeColors {
  @override Color get background => Color(0xFF1A1A1A);
  @override Color get appBarBackground => Color(0xFF2D2D2D);
  @override Color get appBarText => Colors.white;
  @override Color get messageText => Colors.white;
  @override Color get userBubbleBackground => Color(0xFF2962FF);
  @override Color get aiBubbleBackground => Color(0xFF2D2D2D);
  @override Color get terminalBackground => Color(0xFF1E1E1E);
  @override Color get terminalHeader => Color(0xFF2D2D2D);
  @override Color get codeText => Colors.white;
  @override Color get copyButtonColor => Colors.grey[400]!;
  @override Color get languageTagBackground => Colors.grey[800]!;
  @override Color get languageTagText => Colors.grey[300]!;
  @override Color get inputBackground => Color(0xFF2D2D2D);
  @override Color get inputFieldBackground => Color(0xFF1E1E1E);
  @override Color get inputText => Colors.white;
  @override Color get inputHintText => Colors.grey[400]!;
  @override Color get sendButtonBackground => Color(0xFF2962FF);
  @override Color get sendButtonIcon => Colors.white;
  @override Color get loadingIndicator => Color(0xFF2962FF);
  @override Color get snackbarBackground => Color(0xFF424242);
}


