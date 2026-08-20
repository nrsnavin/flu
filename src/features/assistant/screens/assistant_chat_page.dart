import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../PurchaseOrder/services/theme.dart';
import '../controllers/assistant_controller.dart';

// ══════════════════════════════════════════════════════════════
//  ASK JARVIS — chat screen
// ══════════════════════════════════════════════════════════════

class AssistantChatPage extends StatefulWidget {
  const AssistantChatPage({super.key});

  @override
  State<AssistantChatPage> createState() => _AssistantChatPageState();
}

class _AssistantChatPageState extends State<AssistantChatPage> {
  late final AssistantController c;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    c = Get.put(AssistantController());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _input.clear();
    c.send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ErpColors.bgBase,
      appBar: AppBar(
        backgroundColor: ErpColors.navyDark,
        foregroundColor: ErpColors.textOnDark,
        title: const Text('Ask Jarvis'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              _scrollToBottom();
              final msgs = c.messages;
              if (msgs.isEmpty && !c.isSending.value) return _empty();
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(14),
                itemCount: msgs.length + (c.isSending.value ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= msgs.length) return _typing();
                  return _bubble(msgs[i]);
                },
              );
            }),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _empty() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: ErpColors.statusOpenBg, shape: BoxShape.circle),
            child: Icon(Icons.auto_awesome, color: ErpColors.accentBlue),
          ),
          const SizedBox(height: 12),
          Text('Ask about the floor',
              style: TextStyle(fontWeight: FontWeight.w700, color: ErpColors.textPrimary, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            'Jarvis reads your live data to answer — it can explain and recommend, but never changes anything.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ErpColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
            children: AssistantController.suggestions
                .map((s) => InkWell(
                      onTap: () => _send(s),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: ErpColors.bgSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ErpColors.borderLight),
                        ),
                        child: Text(s, style: TextStyle(fontSize: 13, color: ErpColors.textSecondary)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _avatar(Icons.smart_toy_outlined, ErpColors.statusOpenBg, ErpColors.accentBlue),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? ErpColors.accentBlue : ErpColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: isUser ? null : Border.all(color: ErpColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.content,
                      style: TextStyle(
                          color: isUser ? ErpColors.textOnDark : ErpColors.textPrimary, fontSize: 14, height: 1.35)),
                  if (m.tools.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: m.tools
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ErpColors.bgMuted,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.build_outlined, size: 11, color: ErpColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text(kToolLabels[t] ?? t,
                                      style: TextStyle(fontSize: 11, color: ErpColors.textMuted)),
                                ]),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _avatar(Icons.person_outline, ErpColors.borderLight, ErpColors.textSecondary),
        ],
      ),
    );
  }

  Widget _avatar(IconData icon, Color bg, Color fg) => Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: fg),
      );

  Widget _typing() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          _avatar(Icons.smart_toy_outlined, ErpColors.statusOpenBg, ErpColors.accentBlue),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ErpColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ErpColors.borderLight),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ErpColors.accentBlue)),
              SizedBox(width: 8),
              Text('Checking the data…', style: TextStyle(color: ErpColors.textMuted, fontSize: 13)),
            ]),
          ),
        ]),
      );

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: ErpColors.bgSurface,
        border: Border(top: BorderSide(color: ErpColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Ask about orders, wastage, stock…',
                filled: true,
                fillColor: ErpColors.bgMuted,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Obx(() => Material(
                color: ErpColors.accentBlue,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: c.isSending.value ? null : () => _send(_input.text),
                  child: Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(Icons.send, color: ErpColors.textOnDark, size: 20),
                  ),
                ),
              )),
        ]),
      ),
    );
  }
}
