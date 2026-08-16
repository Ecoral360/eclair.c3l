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
            res.set_body(ser::serialize(&&json::serializer(), result)!.to_string()!);

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
  var $params = $Typeof($cb)::params;

  any[$params.len ?: 1] args = {};

  $foreach $i, $param : $params:
    do {
      $switch:
        $case $param.type == Request*:
          args[$i] = &#req;

        $case $param.type == Response*:
          args[$i] = &#res;

        $default:
          var result = @parse_param_value($param.type, $param.name, #req);
          $if $defined(result!):
            if (catch result) {
              result!;
              return INVALID_PARAM~;
            }
          $endif
          args[$i] = &result;
      $endswitch
    };
  $endforeach

  $switch $params.len:
    $case 0:
      return $cb();

    $case 1:
      return $cb(@acast(args[0], $params[0]));

    $case 2:
      return $cb(@acast(args[0], $params[0]), @acast(args[1], $params[1]));

    $case 3:
      return $cb(@acast(args[0], $params[0]), @acast(args[1], $params[1]), @acast(args[2], $params[2]));

    $case 4:
      return $cb(@acast(args[0], $params[0]), @acast(args[1], $params[1]), @acast(args[2], $params[2]), @acast(args[3], $params[3]));

    $case 5:
      return $cb(@acast(args[0], $params[0]), @acast(args[1], $params[1]), @acast(args[2], $params[2]), @acast(args[3], $params[3]), @acast(args[4], $params[4]));

    $case 6:
      return $cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
        @acast(args[5], $params[5]),
      );

    $case 7:
      return $cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
        @acast(args[5], $params[5]),
        @acast(args[6], $params[6]),
      );

    $case 8:
      return $cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
        @acast(args[5], $params[5]),
        @acast(args[6], $params[6]),
        @acast(args[7], $params[7]),
      );

    $case 9:
      return $cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
        @acast(args[5], $params[5]),
        @acast(args[6], $params[6]),
        @acast(args[7], $params[7]),
        @acast(args[8], $params[8]),
      );

    $case 10:
      return $cb(
        @acast(args[0], $params[0]), 
        @acast(args[1], $params[1]), 
        @acast(args[2], $params[2]), 
        @acast(args[3], $params[3]), 
        @acast(args[4], $params[4]),
        @acast(args[5], $params[5]),
        @acast(args[6], $params[6]),
        @acast(args[7], $params[7]),
        @acast(args[8], $params[8]),
        @acast(args[9], $params[9]),
      );

    $default:
      $error "Too many argument " +++ $param.len;

  $endswitch
}

macro @acast(arg, $param) {
  return *anycast(arg, $Typefrom($param.type));
}

macro @call_cb_old($cb, req, res) @local {
  var $params = $Typeof($cb)::params;

  $switch:
    $case $Typeof($cb)::params.len == 0:
      return $cb();

    $case $Typeof($cb)::params[0].type == Request* &&& ($Typeof($cb)::params.len == 1 ||| $Typeof($cb)::params[1].type != Response*):
      return $cb(req);
  
    $case $Typeof($cb)::params.len == 1 &&& $Typeof($cb)::params[0].type == Response*:
      return $cb(res);

    $default:
      return $cb(req, res);
  $endswitch
}

macro @parse_param_value($type, $name, #req) {
  $Typefrom($type) $val;
  $if @is_maybe($val):
    var result = @parse_param_value($Typeof($val.value), $name, #req);
    $if $defined(result!):
      if (catch result) {
        return $val;
      }
    $endif
    return maybe::value{$Typeof($val.value)}(result);
  $endif

  $switch:
    $case $type == String:
      String p = #req.params[$name] ?? #req.query[$name]!;
      return p;

    $case $type == bool:
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

    $case $type == int:
      String p = #req.params[$name] ?? #req.query[$name]!;
      int? i = p.to_int();
      if (catch i) {
        io::eprintfn("Error: expected int value for %s, got %s", $name, p);
        return INVALID_PARAM~;
      }
      return i;

    $case $type == char:
      String p = #req.params[$name] ?? #req.query[$name]!;
      if (p.len != 1) {
        io::eprintfn("Error: expected char value for %s, got %s", $name, p);
        return INVALID_PARAM~;
      }
      return p[0];

    $case des::@is_deserializable($type):
      String p = #req.body();
      $Typefrom($type)? v = des::deserialize{$type}(&&json::deserializer(p));
      if (catch v) {
        io::eprintfn("Error while deserializing the param (%s) %s with value: %s", $type.nameof, $name, p);
        return INVALID_PARAM~;
      }
      return v;

    $default:
      $error @sprintf("A value of type %s cannot be deserialize", $type.nameof);
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
