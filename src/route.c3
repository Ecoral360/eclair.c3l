module eclair::route;
import eclair::httpserver;
import eclair::req;
import eclair::res;
import eclair::constants;
import std::collections::map;
import std::collections::maybe;
import std::io;
import dessert;

faultdef INVALID_PARAM;

struct RouteConfig {
  HTTPMethod method;
  String path;
}

attrdef @Route(RouteConfig config) = @tag("eclair:route", config);


struct Route {
  String[] path;
  HTTPMethod method;
  RouteHandler handler;
}

alias RouteHandler = fn void?(Request* req, Response* res);

fn HashMap{String, String}? Route.match_target(&self, String[] target) {
  HashMap{String, String} map;
  map.init(mem);

  if (target.len != self.path.len) {
    return NOT_FOUND~;
  }

  foreach (i, part : target) {
    String p = self.path[i];
    if (p.len > 0 && p[0] == ':') {
      map.set(p[1..], part);
    } else if (part != p) {
      return NOT_FOUND~;
    }
  }

  return map;
}

<* 
  @require $reflect(#cb).has_tag("eclair:route")
  @require $Typeof($reflect(#cb).get_tag("eclair:route")) == RouteConfig
*>
macro Route @to_route(#cb) {
  RouteConfig $config = $reflect(#cb).get_tag("eclair:route");
  var $return_void = $Typeof(#cb)::returns == void;
  var $return_void_opt = $Typeof(#cb)::returns == void?;

  var $cb = &#cb;
  var handler = fn void?(Request* req, Response* res) {
    $switch:
      $case $return_void:
        return @call_cb($cb, $config, req, res);
      $case $return_void_opt:
        return @call_cb($cb, $config, req, res)!;
      $default:
        var result = @call_cb($cb, $config, req, res);
        $if $defined(result!):
          if (catch result) {
            result!;
            return;
          }
        $endif

        $switch:
          $case $Typeof(result) == String:
            res.set_body(result);

          $case ser::@is_serializable(result):
            res.set_body(json::tstring_serialize(result))!;

        $endswitch
    $endswitch
  };

  $if $config.path.len > 0:
    $if $config.path[$config.path.len - 1] == '/':
      var path = $config.path[..$config.path.len - 2];
    $else
      var path = $config.path;
    $endif
  $else 
    var path = $config.path;
  $endif

  return { 
    .path = path.split(mem, "/"),
    .method = $config.method,
    .handler = handler,
  };
}

macro @call_cb($cb, $config, #req, #res) @local {
  var $ParamStruct = $Typeof($cb)::param_struct;
  $if $ParamStruct == void:
    return $cb();
  $else
    $Typefrom($ParamStruct) params;
    $foreach $member : $ParamStruct::members:
      $switch:
        $case $member.type == Request*:
          params.$member = #req;

        $case $member.type == Response*:
          params.$member = #res;

        $default:
          if (try result = @parse_param_value{$member.type}($member.name, #req)) {
            params.$member = result;
          }
        // if (catch result) {
        //   result!;
        //   return INVALID_PARAM~;
        // }
      $endswitch
    $endforeach

    return $cb(...params);
  $endif
}

macro Type? @parse_param_value($name, #req) <Type> {
  Type $val;
  $if @is_maybe($val):
    var result = @parse_param_value{$Typeof($val)::generic_args[0]}($name, #req);
    $if $defined(result!):
      if (catch result) {
        return $val;
      }
    $endif
    return maybe::value{$Typeof($val.value)}(result);
  $endif

  $switch:
    $case Type == String:
      String p = #req.params[$name] ?? #req.query[$name]!;
      return p;

    $case Type? == bool:
      String p = #req.params[$name] ?? #req.query[$name]!;
      p.convert_to_lower();
      switch (p) {
        case "true":
          return true;
        case "false":
          return false;
        default:
          io::eprintfn("Error: expected bool value for %s, got %s", $name, p);
          return INVALID_PARAM~;
      }

    $case Type == int:
      String p = #req.params[$name] ?? #req.query[$name]!;
      int? i = p.to_int();
      if (catch i) {
        io::eprintfn("Error: expected int value for %s, got %s", $name, p);
        return INVALID_PARAM~;
      }
      return i;

    $case Type == char:
      String p = #req.params[$name] ?? #req.query[$name]!;
      if (p.len != 1) {
        io::eprintfn("Error: expected char value for %s, got %s", $name, p);
        return INVALID_PARAM~;
      }
      return p[0];

    $case des::@is_deserializable(Type):
      String p = #req.body();
      Type? v = json::tdeserialize{Type}(p);
      if (catch v) {
        io::eprintfn("Error while deserializing the param (%s) %s with value: %s", Type::name, $name, p);
        return INVALID_PARAM~;
      }
      return v;

    $default:
      $error @sprintf("A value of type %s cannot be deserialize", Type::name);
  $endswitch
}

// For future use
macro @nb_required_params(#cb) @local {
  var $cb = &#cb;
  var $params = $Typeof($cb)::params;

  any[$params.len ?: 1] args = {};

  $foreach $i, $param : $params:
    args[$i] = &&($Typefrom($param.type)) {};
  $endforeach

  $switch:
    $case $defined($cb()):
      return $params.len;

    $case $defined($cb(@acast(args[0], $params[0]))):
      return $params.len - ($params.len - 1);

    $case $defined($cb(@acast(args[0], $params[0]), @acast(args[1], $params[1]))):
      return $params.len - ($params.len - 2);

    $case $defined($cb(@acast(args[0], $params[0]), @acast(args[1], $params[1]), @acast(args[2], $params[2]))):
      return $params.len - ($params.len - 3);

    $case $defined($cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
      )):
      return $params.len - ($params.len - 4);

    $case $defined($cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
      )):
      return $params.len - ($params.len - 5);

    $case $defined($cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
        @acast(args[5], $params[5]),
      )):
      return $params.len - ($params.len - 6);

    $case $defined($cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
        @acast(args[5], $params[5]),
        @acast(args[6], $params[6]),
      )):
      return $params.len - ($params.len - 7);

    $case $defined($cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
        @acast(args[5], $params[5]),
        @acast(args[6], $params[6]),
        @acast(args[7], $params[7]),
      )):
      return $params.len - ($params.len - 8);

    $default:
      $error "Too many argument " +++ $param.len;

  $endswitch
}

macro @is_maybe($value) {
  return ($defined($value.get) &&& $defined($value.get()) &&& 
          ($defined($value.get()!) ||| $defined($value == maybe::value{$Typeof($value.value)}($value.value))));
}


///## Proposal

// Being able to add `@tag` attribute to function parameters
//
// Syntax to set it :
// ```c3
// fn void foo(int bar @tag("")) {
// }
// ```
//
// Syntax to get it :
// ```c3
// macro @print_param_tags(#func) {
//     $foreach $param : #func.paramsof :
//     $endforeach
// }
// ```
//
//
// ## Motivation
