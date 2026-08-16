module example @feat(ECLAIR_EXAMPLE);

import std::io;
import eclair;
import eclair::route;


fn String hello() @Route({ GET, "/hello" }) {
  return "Hello world!\n";
}


fn int main(String[] args) {
  Server server = eclair::new_server();
  server.@add_route(hello);

  server.listen();
	return 0;
}

