ruleset hello_world {
  meta {
    name "Hello World"
    description <<
A first ruleset for the Quickstart
>>
    author "Phil Windley"
    shares hello, __testing
  }
   
  global {
    __testing = {
      "queries": [],
      "events": [
        {"domain": "echo", "name": "hello"},
        {"domain": "echo", "name": "monkey"},
        {"domain": "echo", "name": "monkey", "attrs":["name"]}] 
  }

  hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }
  }
   
  rule hello_world {
    select when echo hello
    send_directive("say", {"something": "Hello World"})
  }
   
  rule hello_monkey {
    select when echo monkey
    pre {
      val = (event:attr("name") || "Monkey").klog("Name used: ")
    }
    send_directive("say", {"something": "Hello " + val})
  }
}