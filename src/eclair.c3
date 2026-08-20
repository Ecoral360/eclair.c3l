module eclair;
import eclair::httpserver;
import std::io;
import std::collections::list;
import std::collections::map;
import eclair::route;
import eclair::router;

macro @show(#expr) {
  io::printfn("%s: %s", $stringify(#expr), #expr);
}

// We need this to be global because we need to access it in request_handler
Router root_router;

fn void init_routes() @local @init {
  root_router = router::new_router("/");
}

fn void request_handler(HttpRequest* _req) @private {
  Request req = req::request_from(_req);

  Response res = res::new_response();
  String target = req.target();
  HashMap{String, String} query;
  query.init(mem);
  defer query.free();

  if (target.contains("?")) {
    sz idx = target.index_of("?")!!;
    String query_str = target[idx + 1..];
    target = target[..idx - 1];
    foreach (query_arg : query_str.split(mem, "&")) {
      if (query_arg.contains("=")) {
        sz eq_idx = query_arg.index_of("=")!!;
        String query_key = query_arg[..eq_idx - 1];
        String query_val = query_arg[eq_idx + 1..];
        query.set(query_key, query_val);
      } else {
        query.set(query_arg, query_arg);
      }
    }
  }
  req.query = query;

  target = target.strip_suffix("/");

  if (!root_router.dispatch_target(target, target, &req, &res)) {
    res.set_status(404);
    io::eprintn(string::format(mem ,"404 Not found '%s'", target));
    res.set_body(string::format(mem ,"Not found '%s'", target));
  }

  httpserver::http_respond(req.inner, res.inner);
}

fn Server new_server(int port = 8080) {
  return {
    .server = httpserver::http_server_init(port, &request_handler),
    .port = port,
  };
}

fn void Server.add_route(&self, Route route) {
  root_router.add_route(route);
}

fn void Server.include_router(&self, Router router) {
  root_router.routers.push(router);
}

macro void Server.@add_route(&self, #route) {
  root_router.@add_route(#route);
}

fn void Server.listen(&self) {
  io::printfn("Listening on %s", self.port);
  root_router.print_routes();
  httpserver::http_server_listen(self.server);
}
