// GENERATED CODE - DO NOT MODIFY BY HAND

part of test.jaguar.websocket;

// **************************************************************************
// Generator: ApiGenerator
// Target: class ExampleApi
// **************************************************************************

abstract class _$JaguarExampleApi implements ApiInterface {
  static const List<RouteBase> _routes = const <RouteBase>[const Ws('/ws')];

  Future<dynamic> websocket(WebSocket ws);

  Future<bool> handleApiRequest(HttpRequest request) async {
    PathParams pathParams = new PathParams();
    bool match = false;

    match =
        _routes[0].match(request.uri.path, request.method, '/api', pathParams);
    if (match) {
      dynamic rRouteResponse;
      WebSocket ws = await WebSocketTransformer.upgrade(request);
      rRouteResponse = await websocket(
        ws,
      );
      return true;
    }

    return false;
  }
}
