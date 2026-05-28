import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/chat/widgets/message_bubble.dart';
import 'package:frontend/data/models/message_model.dart';
import 'package:frontend/data/models/user_model.dart';

void main() {
  testWidgets('Test MessageBubble layout', (WidgetTester tester) async {
    final message = MessageModel(
      id: '1',
      conversationId: 'c1',
      content: 'Hello world',
      messageType: 'text',
      fileUrl: '',
      status: 'read',
      createdAt: DateTime.now(),
      sender: UserModel(id: 'u1', name: 'User 1', email: 'u1@test.com', profileImage: '', isOnline: true, lastSeen: DateTime.now()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                children: [
                  MessageBubble(message: message, isMe: true),
                  MessageBubble(message: message, isMe: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Hello world'), findsNWidgets(2));
  });
}
