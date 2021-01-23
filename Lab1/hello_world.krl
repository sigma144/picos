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
        {"domain": "echo", "type": "hello"},
        {"domain": "echo", "type": "monkey"},
        {"domain": "echo", "type": "monkey", "args":["name"]}] 
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