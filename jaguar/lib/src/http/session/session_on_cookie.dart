part of jaguar.http.session;

/// A stateless cookie based session manager.
///
/// Stores all session data on a Cookie.
///
/// If [hmacKey] is provided, the sessions data is signed with a signature and
/// verified after parsing.
class CookieSessionManager implements SessionManager {
  /// Name of the cookie on which session data is stored
  final String cookieName;

  /// Duration after which the session is expired
  final Duration expiry;

  /// Constructs a new [CookieSessionManager] with given [cookieName], [expiry]
  /// and [hmacKey].
  CookieSessionManager(
      {this.cookieName = 'session', this.expiry, String hmacKey})
      : _encrypter =
            hmacKey != null ? new Hmac(sha256, hmacKey.codeUnits) : null;

  /// Parses session from the given [request]
  Session parse(Context ctx) {
    Map<String, String> values;
    for (Cookie cook in ctx.req.cookies) {
      if (cook.name == cookieName) {
        dynamic valueMap = _decode(cook.value);
        if (valueMap is Map<String, String>) {
          values = valueMap;
        }
        break;
      }
    }

    if (values == null) {
      return new Session.newSession({});
    }

    if (values['sid'] is! String) {
      return new Session.newSession({});
    }

    final String timeStr = values['sct'];
    if (timeStr is! String) {
      return new Session.newSession({});
    }

    final int timeMilli = int.tryParse(timeStr);
    if (timeMilli == null) {
      return new Session.newSession({});
    }

    final time = new DateTime.fromMillisecondsSinceEpoch(timeMilli);

    if (expiry != null) {
      final Duration diff = new DateTime.now().difference(time);
      if (diff > expiry) {
        return new Session.newSession({});
      }
    }

    return new Session(values['sid'], values, time);
  }

  /// Writes session data ([session]) to the Response ([resp]) and returns new
  /// response
  void write(Context ctx) {
    if (!ctx.sessionNeedsUpdate) return;

    final Session session = ctx.parsedSession;
    final Map<String, String> values = session.asMap;
    values['sid'] = session.id;
    values['sct'] = session.createdTime.millisecondsSinceEpoch.toString();
    final cook = new Cookie(cookieName, _encode(values));
    cook.path = '/';
    ctx.response.cookies.add(cook);
  }

  String _encode(Map<String, String> values) {
    // Base64 URL safe encoding
    String ret = base64Url.encode(json.encode(values).codeUnits);
    // If there is no encrypter, skip signature
    if (_encrypter == null) return ret;
    return ret +
        '.' +
        base64Url.encode(_encrypter.convert(ret.codeUnits).bytes);
  }

  Map<String, String> _decode(String data) {
    if (_encrypter == null) {
      try {
        String dec = new String.fromCharCodes(base64Url.decode(data));
        return (json.decode(dec) as Map).cast<String, String>();
      } catch (e) {
        return null;
      }
    } else {
      List<String> parts = data.split('.');
      if (parts.length != 2) return null;
      try {
        if (base64Url.encode(_encrypter.convert(parts.first.codeUnits).bytes) !=
            parts[1]) return null;

        return (json.decode(
                new String.fromCharCodes(base64Url.decode(parts.first))) as Map)
            .cast<String, String>();
      } catch (e) {
        return null;
      }
    }
  }

  final Hmac _encrypter;
}
