// GENERATED CODE - DO NOT MODIFY BY HAND

part of test.interceptor.param;

// **************************************************************************
// Generator: ApiGenerator
// Target: class ExampleApi
// **************************************************************************

abstract class _$JaguarExampleApi implements RequestHandler {
  static const List<RouteBase> routes = const <RouteBase>[
    const Route(path: '/user', methods: const <String>['GET'])
  ];

  String getUser(String who);

  Future<bool> handleRequest(HttpRequest request, {String prefix: ''}) async {
    prefix += '/api';
    PathParams pathParams = new PathParams();
    bool match = false;

//Handler for getUser
    match =
        routes[0].match(request.uri.path, request.method, prefix, pathParams);
    if (match) {
      Response rRouteResponse = new Response(null);
      WithParam iWithParam = new WrapWithParam(
        makeParams: const {#checker: const MakeParamFromType(CheckerImpl)},
        checker: new CheckerImpl(),
      )
          .createInterceptor();
      String rWithParam = iWithParam.pre();
      rRouteResponse.statusCode = 200;
      rRouteResponse.value = getUser(
        rWithParam,
      );
      await rRouteResponse.writeResponse(request.response);
      return true;
    }

    return false;
  }
}