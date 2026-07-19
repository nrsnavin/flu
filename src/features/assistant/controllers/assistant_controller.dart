import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../core/api_client.dart';
import '../../../core/app_config.dart';

// ══════════════════════════════════════════════════════════════
//  ASK JARVIS — conversational ops assistant
//  Mirrors POST /api/v2/assistant/chat (prod/api/assistant.js).
//  Read-only: the assistant explains/recommends, never mutates.
// ══════════════════════════════════════════════════════════════

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final List<String> tools;
  ChatMessage(this.role, this.content, {this.tools = const []});
}

class AssistantApi {
  static final Dio _dio =
      ApiClient.buildClient(baseUrl: '${ApiConfig.baseUrl}/assistant');

  static Future<Map<String, dynamic>> chat(List<ChatMessage> history) async {
    final res = await _dio.post('/chat', data: {
      'messages': history.map((m) => {'role': m.role, 'content': m.content}).toList(),
    });
    final data = res.data as Map<String, dynamic>;
    return {
      'reply': (data['reply'] ?? '').toString(),
      'toolsUsed': (data['toolsUsed'] as List? ?? []).map((e) => e.toString()).toList(),
    };
  }
}

class AssistantController extends GetxController {
  final messages = <ChatMessage>[].obs;
  final isSending = false.obs;

  static const suggestions = [
    'Which orders are at risk this week?',
    "What's driving wastage this month?",
    'What raw materials should I reorder?',
    'What is the status of order 219?',
  ];

  Future<void> send(String text) async {
    final q = text.trim();
    if (q.isEmpty || isSending.value) return;

    messages.add(ChatMessage('user', q));
    final history = messages.map((m) => m).toList();
    isSending.value = true;
    try {
      final res = await AssistantApi.chat(history);
      messages.add(ChatMessage(
        'assistant',
        res['reply'] as String,
        tools: List<String>.from(res['toolsUsed'] as List),
      ));
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? (e.response!.data['message'] ?? e.message) : e.message;
      messages.add(ChatMessage('assistant', '⚠️ $msg'));
    } catch (e) {
      messages.add(ChatMessage('assistant', '⚠️ Something went wrong.'));
    } finally {
      isSending.value = false;
    }
  }
}

// Human-readable labels for the read tools the backend exposes.
const Map<String, String> kToolLabels = {
  'get_orders_at_risk': 'orders at risk',
  'get_wastage_summary': 'wastage',
  'get_materials_to_reorder': 'reorder list',
  'find_order': 'order lookup',
  'find_material': 'material lookup',
  'get_machine_status': 'machine status',
};
