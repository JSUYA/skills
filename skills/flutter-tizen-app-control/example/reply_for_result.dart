// reply_for_result.dart
// Launch-for-result on the sender side AND the matching reply on the
// receiver side.

import 'package:tizen_app_control/tizen_app_control.dart';

// --- Sender side -----------------------------------------------------------
Future<void> askPartnerForToken() async {
  final control = AppControl(
    appId: 'com.partner.auth',
    extraData: {'kind': 'oauth-token'},
  );
  await control.sendLaunchRequest(
    replyCallback: (request, reply, result) {
      if (result == AppControlReplyResult.succeeded) {
        final token = reply.extraData['token'] as String?;
        // Store the token...
        print('got token: $token');
      }
    },
  );
}

// --- Receiver side ---------------------------------------------------------
Future<void> respondToTokenRequest(ReceivedAppControl request) async {
  if (!request.shouldReply) return;
  final reply = AppControl(extraData: {'token': 'eyJhbGciOiJI...'});
  await request.reply(reply, AppControlReplyResult.succeeded);
}
