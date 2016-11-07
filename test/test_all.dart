import 'jaguar/route/route.dart' as route;
import 'jaguar/group/main.dart' as groupNormal;
import 'jaguar/websocket/websocket.dart' as websocket;

void main() {
  route.main();
  groupNormal.main();
  websocket.main();
}
