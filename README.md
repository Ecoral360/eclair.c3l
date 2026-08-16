# eclair ⚡

A fast, lightweight web framework for building REST APIs in C3.

## Goal

Eclair aims to make building HTTP APIs in C3 as simple and intuitive as possible, drawing inspiration from modern web frameworks like FastAPI (Python), rocket.rs (Rust), and Express.js (JavaScript). While it takes ideas from these frameworks, eclair is designed specifically for C3 with its own unique approach to routing, middleware, and request handling.

The framework leverages C3's powerful macro system to provide a declarative, attribute-based routing mechanism that feels natural to the language. Whether you're building a small microservice or a larger API, eclair gives you the tools to get started quickly without sacrificing performance.

## Features

- **Declarative Routing**: Define routes using the `@Route` attribute, similar to decorators in FastAPI or attributes in rocket.rs
- **Automatic Parameter Inference**: Simply add parameters to your handler function - types like `int id`, `String name`, or `bool completed` are automatically extracted from path segments, query parameters, or request bodies
- **Automatic Response Handling**: Functions returning `String` or serializable types are automatically sent as JSON responses
- **Path Parameters**: Capture dynamic segments from URLs - just add a matching parameter (e.g., `int id` for `/todos/:id`)
- **Query Parameters**: Access query string parameters - add parameters like `Maybe{bool} completed` for optional query params
- **JSON Body Parsing**: Automatically deserialize JSON request bodies - add a struct parameter and it's automatically parsed
- **Full request control**: Use a `Request*` parameter to control everything yourself
- **Maybe Types**: Use `Maybe{T}` for optional query parameters and `Maybe{T}` for optional return values (returns JSON or null)
- **Fault Handling**: Make your return type `T?` for error responses with automatic 500 error handling
- **Routers**: Group routes under a common prefix and include them in the server (sub-routers also supported)
- **HTTP Method Support**: Support for all standard HTTP methods (GET, POST, PUT, DELETE, PATCH, etc.)
- **C Interop**: Built on top of [httpserver.h](https://github.com/jeremycw/httpserver.h), a minimal C HTTP server library

## Quick Start

```c3
module example;

import std::io;
import eclair;

fn String hello() @Route({ GET, "/hello" }) {
  return "Hello world!\n";
}

fn void api_status(Request* req, Response* res) @Route({ GET, "/status" }) {
  res.set_body("OK");
}

fn int main(String[] args) {
  Server server = eclair::new_server();
  server.@add_route(hello);
  server.@add_route(api_status);

  server.listen();
  return 0;
}
```

`import eclair;` is enough to get `Server`, `Router`, `Request`, `Response` and the `@Route` attribute.

## Installation

Make sure you have the [C3 compiler installed](https://github.com/c3lang/c3c), version 0.8.4 or later.

### Using [`c3po`](https://github.com/Ecoral360/c3po)

In your project, run

```sh
c3po add ecoral360/eclair
```

This installs eclair into `lib/eclair.c3l`, pulls [dessert](https://github.com/Ecoral360/dessert.c3l) (the serialization library eclair uses) as a transitive dependency, and adds both to your `project.json`.

### Manually

1. Run `c3c init <YOUR_PROJECT>`
2. Clone this repository into `<YOUR_PROJECT>/lib/eclair.c3l`
3. Clone the [dessert](https://github.com/Ecoral360/dessert.c3l) repository into `<YOUR_PROJECT>/lib/dessert.c3l`
4. Add `"dependencies": ["eclair", "dessert"]` to your `project.json`
5. You are done ! Enjoy writing your REST API in C3 !

### Platform support

Eclair ships prebuilt target configurations for Linux (x64, x86, aarch64, riscv32/64), macOS (x64, aarch64), FreeBSD, NetBSD, OpenBSD and Android (aarch64). Windows is **not** supported yet, since the underlying `httpserver.h` backend relies on epoll/kqueue.

## Running the bundled example

This repository contains a small example server behind the `ECLAIR_EXAMPLE` feature flag (`src/main.c3`):

```sh
c3c run example   # listens on http://localhost:8080, try /hello/world?greeting=Hi
```

## How It Works

### The Server

The `Server` struct is the core of eclair. Create a new server with a port number (defaults to 8080):

```c3
Server server = eclair::new_server(); // port will be 8080
Server server = eclair::new_server(5444); // port will be 5444
```

`server.listen()` prints every registered route, then blocks and serves requests.

### Routes

Routes are defined using the `@Route` attribute with an HTTP method and path. The macro system automatically handles parameter inference:

```c3
fn String my_handler() @Route({ GET, "/path" }) {
  return "response";
}
```

Handlers are registered with `server.@add_route(handler)` (or `router.@add_route(handler)`), which reads the `@Route` tag at compile time.

Handler functions can have parameters automatically inferred:
- `Request*` - The request object
- `Response*` - The response object
- `int`, `String`, `bool`, `char` - Path or query parameters (matching `:param` in path or `param` in query string)
- Any deserializable type (`deserializable struct`, `Maybe{deserializable struct}`, `List{deserializable struct}`, or `deserializable struct[]`) - Automatically parsed from the request body
(see [dessert](https://github.com/Ecoral360/dessert.c3l) for more info on deserializable types)
- `Maybe{int | String | bool | char}` - Optional query parameters

Path parameters take precedence over query parameters: a parameter is first looked up in `req.params`, then in `req.query`.

Handler functions can return different types:
- `String` - Automatically set as the response body
- Any serializable type (`serializable struct`, `Maybe{serializable struct}`, `List{serializable struct}`, or `serializable struct[]`) - Automatically serialized to JSON
(see [dessert](https://github.com/Ecoral360/dessert.c3l) for more info on serializable types)
- `Maybe{T}` - Returns the value as JSON, or `null` if empty
- `T?` - Returns the value as JSON, or 500 error if the handler returns a `fault`
- `void` / `void?` - Lets the handler function deal with the response

Unmatched targets get an automatic `404`.

### Serializable types

Eclair uses [dessert](https://github.com/Ecoral360/dessert.c3l) for JSON. Derive the `serialize` / `deserialize` methods on the structs you send or receive:

```c3
import dessert;

$expand(dessert::@derive(Todo));
struct Todo {
  int id;
  String title;
  bool completed;
}
```

Pass `serialize` or `deserialize` as a second argument to derive only one of them.

### Path Parameters

Capture dynamic segments from URLs automatically by adding a matching parameter:

```c3
fn Maybe{Todo} get_todo(int id) @Route({ GET, "/todos/:id" }) {
  foreach (todo : todos) {
    if (todo.id == id) {
      return maybe::value{Todo}(todo);  // Wrap value in Maybe
    }
  }
  return {};  // Empty Maybe returns null
}
```

### Query Parameters

Access query string parameters automatically using parameters. Use `Maybe{T}` for optional params:

```c3
fn List{Todo} get_todos(Maybe{bool} completed) @Route({ GET, "/todos" }) {
  // completed is an optional query parameter (?completed=true)
  // Access with `if (try value = completed.get()) { ... }` or `completed.get() ?? default_value`
}
```

A flag without a value (`?completed`) is stored with the flag name as its value.

### JSON Request Bodies

Request bodies are automatically deserialized from JSON by adding a deserializable struct parameter:

```c3
fn Todo? create_todo(TodoInput input) @Route({ POST, "/todos" }) {
  // TodoInput is automatically parsed from the request body
  // ...
}
```

### Routers

Group routes under a common prefix using routers:

```c3
fn void main() {
  // ...
  Router todo_router = router::new_router("/todos");
  todo_router.@add_route(get_todos);
  todo_router.@add_route(create_todo);
  todo_router.@add_route(get_todo);
  todo_router.@add_route(update_todo);
  todo_router.@add_route(delete_todo);

  server.include_router(todo_router);
}
```

Routers nest: use `parent_router.include_router(child_router)` to build a prefix tree. A router's route paths are relative to its prefix.

### Request and Response

The `Request` and `Response` types give you access to the HTTP transaction:

```c3
fn void handler(Request* req, Response* res) @Route({ GET, "/example" }) {
  // Access request data
  String target = req.target();
  HTTPMethod method = req.method();
  String body = req.body();
  String id = req.params["id"]!!;     // path parameters
  String q = req.query["q"]!!;        // query parameters

  // Deserialize the body yourself
  MyStruct? parsed = req.json_body_as(MyStruct);

  // Set response
  res.set_status(200);
  res.set_body("Hello, world!");
}
```

### Fault Handling

Return faults for error responses. The framework automatically handles them:

```c3
fn Todo? get_todo(int id) @Route({ GET, "/todos/:id" }) {
  foreach (todo : todos) {
    if (todo.id == id) {
      return todo;
    }
  }
  return NOT_FOUND~;  // Returns 500 error
}
```

A parameter that fails to parse (e.g. `abc` for an `int id`) is left at its zero value and logged on stderr; wrap it in `Maybe{T}` if you want to detect that yourself.

## Complete Example

See [todo.c3](todo.c3) for a full REST API example with CRUD operations:

```c3
module example::todo;

import std;
import eclair;
import dessert;

$expand(dessert::@derive(Todo));
struct Todo {
  int id;
  String title;
  bool completed;
}

$expand(dessert::@derive(TodoInput));
struct TodoInput {
  String title;
  bool completed;
}

// Query parameter - optional (?completed=true or ?completed=false)
fn List{Todo} get_todos(Maybe{bool} completed) @Route({ GET, "/" }) { /* ... */ }

// Body parameter - inferred from JSON request body
fn Todo? create_todo(TodoInput input) @Route({ POST, "/" }) { /* ... */ }

// Path parameter - matches :id in route
fn Maybe{Todo} get_todo(int id) @Route({ GET, "/:id" }) { /* ... */ }

// Multiple parameters combined
fn Todo? update_todo(int id, TodoInput input) @Route({ PUT, "/:id" }) { /* ... */ }

// Manual approach still supported
fn Todo? delete_todo(Request* req) @Route({ DELETE, "/:id" }) {
  int id = req.params["id"].to_int()!;
  // ...
}

fn String hello(Maybe{String} name) @Route({ GET, "/hello" }) {
  return string::tformat("Hello, %s!", name.get() ?? "Stranger");
}

fn int main(String[] args) {
  Server server = eclair::new_server();
  server.@add_route(hello);

  Router todo_router = router::new_router("/todos");
  todo_router.@add_route(get_todos);
  todo_router.@add_route(create_todo);
  todo_router.@add_route(get_todo);
  todo_router.@add_route(update_todo);
  todo_router.@add_route(delete_todo);

  server.include_router(todo_router);
  server.listen();
  return 0;
}
```

```sh
curl localhost:8080/hello?name=Bob                                       # Hello, Bob!
curl -X POST localhost:8080/todos -d '{"title":"buy milk","completed":false}'
                                        # {"id":1,"title":"buy milk","completed":false}
curl localhost:8080/todos                # [{"id":1,"title":"buy milk","completed":false}]
curl localhost:8080/todos/99             # null
```

## Backend

Eclair uses [httpserver.h](https://github.com/jeremycw/httpserver.h) as its HTTP server backend. This is a minimal, fast C library that handles the low-level socket communication and HTTP parsing, allowing eclair to focus on providing a pleasant API surface.

## Why the name eclair ?

`Eclair` has two meaning. 
1. It means lightning in French and represents the goal of making it as fast to write in as possible.
2. The deserializer and serializer lib used by eclair is [dessert](https://github.com/Ecoral360/dessert.c3l) and `eclair (au chocolat)` is a pastry.

## License

MIT
