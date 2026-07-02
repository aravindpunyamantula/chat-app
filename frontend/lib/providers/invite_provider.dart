import 'package:flutter/foundation.dart';
import '../data/models/conversation_model.dart';
import '../data/models/user_model.dart';
import '../data/repositories/invite_repository.dart';
import '../core/utils/logger.dart';

enum InviteCheckState { idle, checking, done }

class InviteProvider with ChangeNotifier {
  final InviteRepository _repo;

  InviteCheckState checkState = InviteCheckState.idle;
  bool isBonded = false;
  ConversationModel? bondedConversation;
  UserModel? partner;
  String? myCode;
  DateTime? codeExpiresAt;
  String? error;

  // Transient state for the accept flow
  bool isAccepting = false;
  String? acceptError;

  // Transient state for code refresh
  bool isRefreshing = false;

  InviteProvider({required InviteRepository repo}) : _repo = repo;

  bool get isChecking => checkState != InviteCheckState.done;

  Future<void> checkStatus() async {
    checkState = InviteCheckState.checking;
    error = null;
    notifyListeners();

    try {
      final status = await _repo.getStatus();
      isBonded = status.bonded;
      myCode = status.myCode;
      codeExpiresAt = status.expiresAt;
      partner = status.partner;

      if (status.bonded && status.conversationId != null) {
        // Reconstruct a minimal ConversationModel from status data
        bondedConversation = ConversationModel(
          id: status.conversationId!,
          participants: status.partner != null ? [status.partner!] : [],
          isGroup: false,
          isBonded: true,
          groupName: '',
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      AppLogger.error('InviteProvider: checkStatus error — $e');
    } finally {
      checkState = InviteCheckState.done;
      notifyListeners();
    }
  }

  Future<bool> acceptInvite(String code, String currentUserId) async {
    if (isAccepting) return false;
    isAccepting = true;
    acceptError = null;
    notifyListeners();

    try {
      final result = await _repo.acceptInvite(code);
      bondedConversation = result.conversation;
      partner = result.partner;
      isBonded = true;
      myCode = null;
      return true;
    } catch (e) {
      acceptError = e.toString().replaceFirst('Exception: ', '');
      AppLogger.error('InviteProvider: acceptInvite error — $e');
      return false;
    } finally {
      isAccepting = false;
      notifyListeners();
    }
  }

  Future<void> refreshCode() async {
    if (isRefreshing) return;
    isRefreshing = true;
    notifyListeners();

    try {
      myCode = await _repo.refreshCode();
      error = null;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  void clearAcceptError() {
    acceptError = null;
    notifyListeners();
  }
}
