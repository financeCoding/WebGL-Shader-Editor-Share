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
final IP = '0.0.0.0';
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
            Map jsonMessageFromClient = JSON.parse(message);
            if (jsonMessageFromClient.containsKey("command")) {
              if (jsonMessageFromClient["command"] == "store") {
                // Store to database
                Code code = new Code();
                code.fragmentShaderSource = jsonMessageFromClient["fragment_shader_source"];
                code.vertexShaderSource = jsonMessageFromClient["vertex_shader_source"];
                code.rendererConfig = ""; // TODO(adam): renderer configuration
                code.save();
                conn.send(JSON.stringify({
                      "command" : "load_id",
                      "code_id" : code.id.toHexString()
                    }));
              } else if (jsonMessageFromClient["command"] == "load") {
                // load the code from the database.
                // Find the object
                ObjectId oid = new ObjectId.fromHexString(jsonMessageFromClient["id"]);
                objectory.findOne($Code.id(oid)).then((found) {
                  var c = found as Code;
                  Map m = new Map();
                  m['command'] = 'load_shaders';
                  m['fragmentShaderSource'] = c.fragmentShaderSource;
                  m['vertexShaderSource'] = c.vertexShaderSource;
                  m['configRenderer'] = '';
                  conn.send(JSON.stringify(m));
                });
                
              }
            }
          };
       
          conn.onClosed =  (int status, String reason) {
            print("conn.onClosed status=${status}, reason=${reason}");
          };
        };
      });
      
      
        
      print('listing on http://$IP:$PORT');
      server.listen(IP, PORT);
    }
  };
    
  server.onError = (e) {
    print("server error $e");
  };
  
}