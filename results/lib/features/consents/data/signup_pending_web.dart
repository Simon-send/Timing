import 'package:web/web.dart' as web;

final _pending = <String, String>{};
String? pendingSignupSource(String uid) {
  try {
    return web.window.localStorage.getItem('plotting.signup.pending.$uid') ??
        _pending[uid];
  } on Object {
    return _pending[uid];
  }
}

void markSignupPending(String uid, String source) {
  _pending[uid] = source;
  try {
    web.window.localStorage.setItem('plotting.signup.pending.$uid', source);
  } on Object {
    /* In-memory state keeps this tab recoverable when storage is blocked. */
  }
}

void clearSignupPending(String uid) {
  _pending.remove(uid);
  try {
    web.window.localStorage.removeItem('plotting.signup.pending.$uid');
  } on Object {
    /* Backend completion remains authoritative if a stale key survives. */
  }
}
