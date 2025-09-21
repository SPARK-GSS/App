import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:gss/services/AuthService.dart';

class InviteService {
  // 여러분의 https 딥링크 베이스
  static const String _deepBase = 'https://gss-db-df40f.web.app/invite';

  // 여러분의 Cloud Functions HTTPS 엔드포인트 (아래 5번에서 배포)
  static const String _shortenerEndpoint =
      'https://us-central1-gss-db-df40f.cloudfunctions.net/createShortLink';

  static Future<Uri> createInviteLink(String clubName) async {
    final sid = await user_stuid();
    final now = DateTime.now().millisecondsSinceEpoch;

    final token = _rand(20);
    final expiresAt = now + 7 * 24 * 60 * 60 * 1000;

    await FirebaseDatabase.instance
        .ref('Club/$clubName/invites/$token')
        .set({
      'createdBy': sid,
      'createdAt': now,
      'expiresAt': expiresAt,
      'used': false,
    });

    final longLink = Uri.parse(_deepBase).replace(queryParameters: {
      'club': clubName,
      'token': token,
    }).toString();

    // Cloud Functions로 단축
    final res = await http.post(
      Uri.parse(_shortenerEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'longUrl': longLink}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final shortUrl = (data['shortUrl'] ?? '') as String;
      if (shortUrl.isNotEmpty) return Uri.parse(shortUrl);
    }
    // 실패 시 롱 링크라도 반환
    return Uri.parse(longLink);
  }

  static String _rand(int len) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    return Iterable.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
