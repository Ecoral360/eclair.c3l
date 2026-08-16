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

// completed is inferred to be an optional query parameter of the request
fn List{Todo} get_todos(Maybe{bool} completed) @Route({ GET, "/" }) {
  io::printfn("Completed query value: %s", completed);
  return todos;
}

// TodoInput is inferred to be the body of the request
fn Todo? create_todo(TodoInput input) @Route({ POST, "/" }) {
  int new_id = (int) todos.len() + 1;
  Todo new_todo = { .id = new_id, .title = input.title, .completed = input.completed };
  todos.push(new_todo);

  return new_todo;
}

// id is inferred to be the value of ':id', and will be converted to an int automatically
fn Maybe{Todo} get_todo(int id) @Route({ GET, "/:id" }) {
  foreach (todo : todos) {
    if (todo.id == id) {
      return maybe::value{Todo}(todo);
    }
  }
  return {};
}

fn Todo? update_todo(int id, TodoInput input) @Route({ PUT, "/:id" }) {
  foreach (&todo : todos) {
    if (todo.id == id) {
      todo.title = input.title;
      todo.completed = input.completed;
      return *todo;
    }
  }
  return NOT_FOUND~;
}

// You can still do it manually
fn Todo? delete_todo(Request* req) @Route({ DELETE, "/:id" }) {
  int id = req.params["id"].to_int()!;

  foreach (i, todo : todos) {
    if (todo.id == id) {
      todos.remove_at(i);
      return todo;
    }
  }
  return NOT_FOUND~;
}

fn String hello(Maybe{String} name) @Route({ GET, "/hello" }) {
  return string::tformat("Hello, %s!", name.get() ?? "Stranger");
}

/// MAIN PROGRAM

List{Todo} todos;

fn void init_list() @init {
  todos.init(mem);
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
