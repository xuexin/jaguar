library jaguar.src.http.request;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:mime/mime.dart';
import 'package:http_server/http_server.dart';
import 'package:logging/logging.dart';

import 'package:jaguar/src/http/session/session.dart';

part 'form_field.dart';

/// Splits given path to composing segments
List<String> splitPathToSegments(final String paths) {
  final List<String> segments = paths.split(new RegExp('/+'));
  final res = <String>[];
  for (String part in segments) {
    if (part.length == 0) continue;
    res.add(part);
  }
  return res;
}

/// [Request] contains information about HTTP request
abstract class Request {
  factory Request(
          HttpRequest request, SessionManager sessionManager, Logger log) =>
      new _Request(request, sessionManager, log);

  /// The URI for the request
  ///
  /// This provides access to the path and query string for the request.
  Uri get uri;

  /// The requested URI for the request
  ///
  /// The returned URI is reconstructed by using http-header fields, to access
  /// otherwise lost information, e.g. host and scheme.
  ///
  /// To reconstruct the scheme, first 'X-Forwarded-Proto' is checked, and then
  /// falling back to server type.
  ///
  /// To reconstruct the host, first 'X-Forwarded-Host' is checked, then 'Host'
  /// and finally calling back to server.
  Uri get requestedUri;

  /// The method, such as 'GET' or 'POST', for the request.
  String get method;

  /// The request headers.
  HttpHeaders get headers;

  /// The cookies in the request, from the Cookie headers.
  List<Cookie> get cookies;

  /// The session for the given request
  Future<Session> get session;

  /// Does session need an update?
  ///
  /// Shall be used when writing response or closing a request.
  bool get sessionNeedsUpdate;

  /// Parsed session
  ///
  /// Returns [null], if the session is not parsed yet.
  Session get parsedSession;

  /// Connection information of the request
  HttpConnectionInfo get connectionInfo;

  /// Logger to log data during request
  Logger get log;

  /// The client certificate of the client making the request
  ///
  /// This value is null if the connection is not a secure TLS or SSL connection,
  /// or if the server does not request a client certificate, or if the client
  /// does not provide one.
  X509Certificate get certificate;

  /// The content length of the request body
  ///
  /// If the size of the request body is not known in advance,
  /// this value is -1.
  int get contentLength;

  /// The persistent connection state signaled by the client
  bool get persistentConnection;

  /// The HTTP protocol version used in the request, either "1.0" or "1.1".
  String get protocolVersion;

  Future<WebSocket> get upgradeToWebSocket;

  /// Returns raw body of HTTP request
  Future<List<int>> get body;

  /// Returns the body of HTTP request as Stream
  Future<Stream<List<int>>> get bodyAsStream;

  /// Returns body as text
  Future<String> bodyAsText([Encoding encoding = UTF8]);

  /// Decodes JSON body of the request
  Future<dynamic> bodyAsJson({Encoding encoding: UTF8});

  /// Decodes JSON body of the request as [Map]
  Future<Map> bodyAsJsonMap({Encoding encoding: UTF8});

  /// Decodes JSON body of the request as [List]
  Future<List> bodyAsJsonList({Encoding encoding: UTF8});

  /// Decodes url-encoded form from the body and returns Map<String, String>
  Future<Map<String, String>> bodyAsUrlEncodedForm({Encoding encoding: UTF8});

  /// Decodes `multipart/form-data` body
  Future<Map<String, FormField>> bodyAsFormData({Encoding encoding: UTF8});
}

/// [Request] contains information about HTTP request
class _Request implements Request {
  final HttpRequest _request;

  final Logger log;

  final SessionManager _sessionManager;

  Session _session;

  _Request(this._request, this._sessionManager, this.log);

  /// The client certificate of the client making the request.
  X509Certificate get certificate => _request.certificate;

  /// Information about the client connection.
  HttpConnectionInfo get connectionInfo => _request.connectionInfo;

  /// The content length of the request body.
  int get contentLength => _request.contentLength;

  /// The cookies in the request, from the Cookie headers.
  List<Cookie> get cookies => _request.cookies;

  /// The request headers.
  HttpHeaders get headers => _request.headers;

  /// The method, such as 'GET' or 'POST', for the request.
  String get method => _request.method;

  /// The persistent connection state signaled by the client.
  bool get persistentConnection => _request.persistentConnection;

  /// The HTTP protocol version used in the request, either "1.0" or "1.1".
  String get protocolVersion => _request.protocolVersion;

  /// The requested URI for the request.
  Uri get requestedUri => _request.requestedUri;

  /// Does the session need update?
  bool get sessionNeedsUpdate => _session != null && _session.needsUpdate;

  /// Parsed session. Returns null, if the session is not parsed yet.
  Session get parsedSession => _session;

  /// The session for the given request.
  Future<Session> get session async {
    if (_session == null) {
      _session = await _sessionManager.parse(this);
    }
    return this._session;
  }

  /// The URI for the request.
  Uri get uri => _request.uri;

  /// Upgrades the request to websocket request
  Future<WebSocket> get upgradeToWebSocket =>
      WebSocketTransformer.upgrade(_request);

  /// Private cache for request body
  List<int> _body;

  /// Returns the body of HTTP request
  Future<List<int>> get body async {
    if (_body is List<int>) return _body;

    final BytesBuilder builder = await _request.fold(new BytesBuilder(),
        (BytesBuilder builder, List<int> data) => builder..add(data));

    _body = builder.takeBytes();
    return _body;
  }

  /// Returns the body of HTTP request
  Future<Stream<List<int>>> get bodyAsStream async {
    final List<int> bodyRaw = await body;
    return new Stream<List<int>>.fromIterable(<List<int>>[bodyRaw]);
  }

  /// Returns body as text
  Future<String> bodyAsText([Encoding encoding = UTF8]) async {
    return encoding.decode(await body);
  }

  /// Decodes JSON body of the request
  Future<dynamic> bodyAsJson({Encoding encoding: UTF8}) async {
    final String text = await bodyAsText(encoding);
    return JSON.decode(text);
  }

  /// Decodes JSON body of the request as [Map]
  Future<Map> bodyAsJsonMap({Encoding encoding: UTF8}) async {
    final String text = await bodyAsText(encoding);
    final ret = JSON.decode(text);

    if (ret == null) return null;

    if (ret is! Map) throw new Exception("Json body is not a Map!");

    return ret;
  }

  /// Decodes JSON body of the request as [List]
  Future<List> bodyAsJsonList({Encoding encoding: UTF8}) async {
    final String text = await bodyAsText(encoding);
    final ret = JSON.decode(text);

    if (ret == null) return null;

    if (ret is! List) throw new Exception("Json body is not a List!");

    return ret;
  }

  /// Decodes url-encoded form from the body and returns Map<String, String>
  Future<Map<String, String>> bodyAsUrlEncodedForm(
      {Encoding encoding: UTF8}) async {
    final String text = await bodyAsText(encoding);
    return text
        .split("&")
        .map((String part) => part.split("="))
        .map((List<String> part) => <String, String>{part.first: part.last})
        .reduce((Map<String, String> value, Map<String, String> element) =>
            value..putIfAbsent(element.keys.first, () => element.values.first));
  }

  /// Decodes `multipart/form-data` body
  Future<Map<String, FormField>> bodyAsFormData(
      {Encoding encoding: UTF8}) async {
    if (!headers.contentType.parameters.containsKey('boundary')) {
      return null;
    }

    final String boundary = headers.contentType.parameters['boundary'];

    final Map<String, FormField> ret = {};

    final Stream<List<int>> bodyStream = await bodyAsStream;

    // Transform body to [MimeMultipart]
    final transformer = new MimeMultipartTransformer(boundary);
    final Stream<MimeMultipart> stream = bodyStream.transform(transformer);

    await for (MimeMultipart part in stream) {
      HttpMultipartFormData multipart = HttpMultipartFormData.parse(part);

      // Parse field content type
      final ContentType contentType = multipart.contentType;

      final String name = multipart.contentDisposition.parameters['name'];

      final String fn = multipart.contentDisposition.parameters['filename'];

      // Create field
      if (fn is! String && multipart.isText) {
        final String data = await multipart.join();
        final field = new StringFormField(name, data, contentType: contentType);
        ret[field.name] = field;
      } else if (multipart.isText) {
        final field = new TextFileFormField(name, multipart as Stream<String>,
            contentType: contentType, filename: fn);
        ret[field.name] = field;
      } else {
        final field = new BinaryFileFormField(
            name, multipart as Stream<List<int>>,
            contentType: contentType, filename: fn);
        ret[field.name] = field;
      }
    }

    return ret;
  }
}
