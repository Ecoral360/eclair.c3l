module eclair::req;
import eclair::httpserver;
import eclair::constants;
import std::collections::map;
import dessert;

struct Request {
  HttpRequest* inner;
  HashMap{String, String} params;
  HashMap{String, String} query;
}

fn Request request_from(HttpRequest* req) {
  return { .inner = req };
}

fn String Request.target(&self) {
  return httpserver::http_request_target(self.inner).to_string();
}

fn HTTPMethod Request.method(&self) {
  String method_name = httpserver::http_request_method(self.inner).to_string();
  return HTTPMethod::lookup_field(name, method_name)!!;
}

fn String Request.body(&self) {
  return httpserver::http_request_body(self.inner).to_string();
}


macro Request.json_body_as(&self, $Output) {
  return des::deserialize{$Output}(&&json::tdeserializer(self.body()));
}


// struct QueryParamConfig {
//   String name;
// }
// attrdef @Query(QueryParamConfig config) = @tag("eclair:query", config);
// attrdef @Body = @tag("eclair:body");
//
// macro Output? query(Request* req, String name) <Output> {
//   String v = req.query[name]!;
//
//   return des::deserialize{Output}(&&json::deserializer(v));
// }
