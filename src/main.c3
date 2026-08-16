module example @feat(ECLAIR_EXAMPLE);

import std::io;
import eclair;
import eclair::route;
import std::collections::maybe;


fn String hello(String id, Maybe{String} greeting) @Route({ GET, "/hello/:id" }) {
  return string::tformat("%s %s!\n", greeting.get() ?? "Hello", id);
}


fn int main(String[] args) {
  Server server = eclair::new_server();
  server.@add_route(hello);

  server.listen();
	return 0;
}

