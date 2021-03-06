part of jaguar_auth.authenticators;

/// BasicAuth performs authentication based on
/// [basic authentication](https://en.wikipedia.org/wiki/Basic_access_authentication).
///
/// It expects base64 encoded "username:password" pair in "authorization" header
/// with "Basic" scheme.
///
/// Arguments:
/// It uses [userFetcher] to fetch user model for the authentication request
/// and authenticate against the password
///
/// Outputs ans Variables:
/// The authenticated user model is injected into the context as input
class BasicAuth implements Interceptor {
  /// Model manager is used to fetch user model for the authentication request
  /// and authenticate against the password
  final UserFetcher<PasswordUser> userFetcher;

  final Hasher hasher;

  /// The key by which authorizationId shall be stored in session data
  final String authorizationIdKey;

  /// Specifies whether the interceptor should create/update the session data
  /// on successful authentication.
  ///
  /// If set to false, session creation and update must be done manually
  final bool manageSession;

  const BasicAuth(this.userFetcher,
      {this.authorizationIdKey: 'id',
      this.manageSession: true,
      this.hasher: const NoHasher()});

  /// Parses the session from request, fetches the user model and authenticates
  /// it against the password.
  ///
  /// On successful login, injects authenticated user model as context input and
  /// session manager as context variable.
  Future<void> call(Context ctx) async {
    String basic = ctx.authHeader(kBasicAuthScheme);

    if (basic == null)
      throw new Response(
          "Invalid request! Basic authorization header not found!",
          statusCode: HttpStatus.unauthorized);

    final String credentials = _decodeCredentials(basic);
    final int splitIdx = credentials.indexOf(':');

    String username;
    String password;
    if (splitIdx != -1 && splitIdx < (credentials.length - 1)) {
      username = credentials.substring(0, splitIdx);
      password = credentials.substring(splitIdx + 1);
    } else {
      username = credentials;
      password = "";
    }

    final subject = await userFetcher.getByAuthenticationId(ctx, username);

    if (subject == null)
      throw new Response("User not found!",
          statusCode: HttpStatus.unauthorized);

    if (!hasher.verify(password, subject.password))
      throw new Response("Invalid password",
          statusCode: HttpStatus.unauthorized);

    if (manageSession is bool && manageSession) {
      final Session session = await ctx.session;
      // Invalidate old session data
      session.clear();
      // Add new session data
      session.addAll(
          <String, String>{authorizationIdKey: subject.authorizationId});
    }

    ctx.addVariable(subject);
  }

  static String _decodeCredentials(String credentials) {
    try {
      return new String.fromCharCodes(base64Url.decode(credentials));
    } on FormatException catch (_) {
      return '';
    }
  }

  static const kBasicAuthScheme = 'Basic';

  static Future<ModelType> authenticate<ModelType extends PasswordUser>(
      Context ctx, UserFetcher userFetcher,
      {String authorizationIdKey: 'id',
      bool manageSession: true,
      Hasher hasher: const NoHasher()}) async {
    await new BasicAuth(userFetcher,
        authorizationIdKey: authorizationIdKey,
        manageSession: manageSession,
        hasher: hasher).call(ctx);
    return ctx.getVariable<ModelType>();
  }
}
