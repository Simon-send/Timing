final _pending = <String, String>{};
String? pendingSignupSource(String uid) => _pending[uid];
void markSignupPending(String uid, String source) {
  _pending[uid] = source;
}

void clearSignupPending(String uid) {
  _pending.remove(uid);
}
