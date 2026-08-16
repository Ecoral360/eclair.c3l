module eclair::router;
import eclair::route;
import eclair::constants;
import std::collections::list;
import eclair;
import std;


struct Router {
  String prefix;
  List{Route} routes;
  List{Router} routers;
}

fn Router new_router(String prefix) {
  List{Route} routes;
  routes.init(mem);
  prefix = prefix.strip_suffix("/");
  return { .routes = routes, .prefix = prefix };
}

fn void Router.print_routes(&self) {
  foreach(route : self.routes) {
    io::printfn("%s %s%s", route.method, self.prefix, string::join(mem, route.path, "/"));
  }
  foreach(router : self.routers) router.print_routes();
}

fn void Router.add_route(&self, Route route) {
  self.routes.push(route);
}
macro void Router.@add_route(&self, #route) {
  self.routes.push(route::@to_route(#route));
}

fn void Router.include_router(&self, Router router) {
  self.routers.push(router);
}

fn bool Router.match_prefix(&self, String target) @inline {
  return target.starts_with(self.prefix);
}


fn bool Router.dispatch_target(&self, String original_target, String target, Request* req, Response* res) {
  if (!self.match_prefix(target)) return false;

  target = target[self.prefix.len..];
  String[] parts = target.split(mem, "/");

  foreach (route : self.routes) {
    if (req.method() != route.method) continue;
    if (try params = route.match_target(parts)) {
      req.params = params;
      if (catch route.handler(req, res)) {
        io::printfn("Error handling the request at route '%s'", original_target);
        res.set_status(500);
        res.set_body("Error");
      }
      return true;
    }
  }
  foreach (router : self.routers) {
    if (router.dispatch_target(original_target, target, req, res)) return true;
  }

  return false;
}



