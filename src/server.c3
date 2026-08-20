module eclair::server;
import eclair::httpserver;

struct Server {
  HttpServer *server;
  int port;
}

