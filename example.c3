module example;

import std::io;
import eclair;
import eclair::route;


fn String hello(String id) @Route({ GET, "/hello" }) {
  return string::tformat("Hello %s!\n", id);
}


fn int main(String[] args) {
  Server server = eclair::new_server();
  server.@add_route(hello);

  server.listen();
	return 0;
}

