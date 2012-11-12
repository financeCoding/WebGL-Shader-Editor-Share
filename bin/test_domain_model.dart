library test_domain_model;
import 'package:objectory/objectory_console.dart';
import 'domain_model.dart';
const Uri = 'mongodb://127.0.0.1/objectory_shader_app';
void main() {
  // setting 3rd param as true drops the db
  objectory = new ObjectoryDirectConnectionImpl(Uri, registerClasses, false);
  objectory.initDomainModel().then((_) {
    Code code = new Code();
    code.title = "some title";
    code.body = "some body 3";
    code.fragmentShaderSource = "fragment shader code";
    code.vertexShaderSource = "vertext shader code";
    code.rendererConfig = "renderer config data";
    code.save();
    objectory.close();
  });
}