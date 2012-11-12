library web_server;
// NOTE: start mongo db server mongod -v --dbpath .
import "dart:io";
import 'dart:json';
import 'dart:uri';
import "dart:utf";
import "dart:math";

import 'package:objectory/objectory_console.dart';

import 'domain_model.dart';

const Uri = 'mongodb://127.0.0.1/objectory_shader_app';
final IP = '127.0.0.1';
final PORT = 8080;

void main() {
  objectory = new ObjectoryDirectConnectionImpl(Uri, registerClasses, false);
  HttpServer server = new HttpServer();
  WebSocketHandler wsHandler = new WebSocketHandler();
  server.addRequestHandler((req) => req.path == "/ws", wsHandler.onRequest);
  
  Map staticFiles = new Map();
  String webFolder = "web";
  Directory directory = new Directory.fromPath(new Path(webFolder));
  DirectoryLister directoryLister = directory.list(recursive: true);
  directoryLister.onError = (error) {
    print("Not able to list directory $webFolder, $error");
    exit(0);
  };
  
  directoryLister.onFile = (String file) {
    // Ignore paths that get introduced by pub's packages folder
    if (file.contains('.pub-cache') || file.contains('dart-sdk')) { 
      return; 
    }
    
    Path path = new Path(file); 
    String cwd = new Directory.current().path;
    String nfile = file.replaceFirst(cwd, '');
    staticFiles[nfile] = file;
  };
  
  directoryLister.onDone = (completed)
  {
    if (completed == true) {
      staticFiles.forEach((k,v) {
        server.addRequestHandler((req) => req.path == k, (HttpRequest req, HttpResponse res) {
          File file = new File(v);
          file.openInputStream().pipe(res.outputStream);
        });
      });
      server.defaultRequestHandler = (HttpRequest req, HttpResponse res) {
        // TODO(adam): handle requests for files in pub-cache or dart-sdk better
        File file = new File(req.path.substring(1));
        if (file.existsSync()) {
          file.openInputStream().pipe(res.outputStream);
        } else {
          res.outputStream.close();
        }
      };
      
      objectory.initDomainModel().then((_) {
        wsHandler.onOpen = (WebSocketConnection conn) {
          conn.onMessage = (message) {
            print("wsHandler.onMessage = $message");
            Map jsonMessageFromClient = JSON.parse(message);
            if (jsonMessageFromClient.containsKey("command")) {
              if (jsonMessageFromClient["command"] == "store") {
                // Store to database
                print("storing to database");
                Code code = new Code();
                code.fragmentShaderSource = jsonMessageFromClient["fragment_shader_source"];
                code.vertexShaderSource = jsonMessageFromClient["vertex_shader_source"];
                code.rendererConfig = ""; // TODO(adam): renderer configuration
                code.save();
                // TODO(adam): send the object id back.
                print(code.id);
                print(code.id.toJson());
                print(code.id.toHexString());
                conn.send(JSON.stringify(
                    {
                      "command" : "set_code_id",
                      "code_id" : code.id.toHexString()
                    }));
              } else if (jsonMessageFromClient["command"] == "load") {
                // load the code from the database.
                objectory.find($Code.id('')).then((found) {
                  // Send the results to client
                  print("Sending Code back to the client");
                  
                });
              }
            }
          };
       
          conn.onClosed =  (int status, String reason) {
            print("conn.onClosed status=${status},reason=${reason}");
          };
        };
      });
      
      
        
      print('listing on http://$IP:$PORT');
      server.listen(IP, PORT);
    }
  };
    
  server.onError = (e) {
    print("error $e");
  };
  
}