require('nodefly').profile(
    '46f141b3c7e05d92d8692046f404cef0',
    ["plunker-api", process.env.SUBDOMAIN],
    {} // optional
);

//process.env.NODE_ENV = "production"

require("coffee-script");

var nconf = require("nconf")
  , http = require("http")
  , server = require("./index");


http.createServer(server).listen(nconf.get("PORT"), function(){
  console.log("[INFO] Server started");
});