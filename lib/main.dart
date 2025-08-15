import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';


void main() {
  runApp(const ChatApp());
}

class Message {
  final String role;
  final String content;
  Message({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class ChatService {
  static const _url =
      'http://e7290ef4f1cf.sn.mynetname.net:1234/v1/chat/completions';
  static const _headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer lmstudio-local',
  };

  Future<String> send(List<Message> history, String userText) async {
    final messages = [
      ...history.map((m) => m.toJson()),
      Message(role: 'user', content: userText).toJson(),
    ];
    final body = jsonEncode({
      'model': 'qwen/qwen3-coder-30b',
      'messages': messages,
      'temperature': 0.2,
      'max_tokens': 700,
      'user': 'client_app',
    });

    final response = await http.post(
      Uri.parse(_url),
      headers: _headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content']?.toString() ?? '';
    } else {
      throw Exception(
          'Ошибка:  [31m${response.statusCode} ${response.reasonPhrase} [0m');
    }
  }
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat with LM Studio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  File? _selectedFile;


  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    setState(() {
      // If file is selected, include it in the message
      if (_selectedFile != null) {
        _messages.add(Message(role: 'user', content: text + ' [File: ${_selectedFile!.path}]'));
      } else {
        _messages.add(Message(role: 'user', content: text));
      }
      _isLoading = true;
      _controller.clear();
    });
    try {
      final reply =
          await _chatService.send(_messages.where((m) => m.role != 'assistant').toList(), text);
      setState(() {
        _messages.add(Message(role: 'assistant', content: reply));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withReadStream: false,
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора файла: $e')),
        );
      }
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Функция для определения наличия SVG в тексте
  bool _containsSvg(String content) {
    return content.contains('<svg') && content.contains('</svg>');
  }

  // Функция для извлечения SVG из текста
  String? _extractSvg(String content) {
    final svgRegExp = RegExp(r'<svg[^>]*>.*?</svg>', dotAll: true);
    final match = svgRegExp.firstMatch(content);
    return match?.group(0);
  }

  // Функция для получения текста без SVG
  String _getTextWithoutSvg(String content) {
    final svgRegExp = RegExp(r'<svg[^>]*>.*?</svg>', dotAll: true);
    return content.replaceAll(svgRegExp, '[SVG изображение]').trim();
  }

  Widget _buildMessage(Message msg) {
    final isUser = msg.role == 'user';
    final containsSvg = _containsSvg(msg.content);
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.blue.shade100
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Отображение текста (если есть)
            if (_getTextWithoutSvg(msg.content).isNotEmpty)
              Text(
                _getTextWithoutSvg(msg.content),
                style: TextStyle(
                  color: Colors.black87,
                ),
              ),
            
            // Отображение SVG (если есть)
            if (containsSvg) ...[
              if (_getTextWithoutSvg(msg.content).isNotEmpty)
                const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 300,
                  maxHeight: 300,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: _buildSvgWidget(_extractSvg(msg.content)!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSvgWidget(String svgContent) {
    try {
      return SvgPicture.string(
        svgContent,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Container(
          width: 50,
          height: 50,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    } catch (e) {
      // Если SVG не удается отобразить, показываем ошибку
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Icon(Icons.error, color: Colors.red.shade400),
            const SizedBox(height: 4),
            Text(
              'Ошибка отображения SVG',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with LM Studio'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, idx) => _buildMessage(_messages[idx]),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attachment),
                  color: Colors.deepPurple,
                  onPressed: _selectFile,
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: 'Введите сообщение...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.deepPurple,
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
