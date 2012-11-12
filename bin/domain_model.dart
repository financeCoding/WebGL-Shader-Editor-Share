library domain_model;
import 'package:objectory/objectory.dart';

class Code extends PersistentObject {
  String get title => getProperty('title');
  set title(String value) => setProperty('title', value);

  String get body => getProperty('body');
  set body(String value) => setProperty('body', value);
  
  String get vertexShaderSource => getProperty('vertexShaderSource');
  set vertexShaderSource(String value) => setProperty('vertexShaderSource', value);

  String get fragmentShaderSource => getProperty('fragmentShaderSource');
  set fragmentShaderSource(String value) => setProperty('fragmentShaderSource', value);

  String get rendererConfig => getProperty('rendererConfig');
  set rendererConfig(String value) => setProperty('rendererConfig', value);
}

void registerClasses() {
  objectory.registerClass('Code',() => new Code());
}

ObjectoryQueryBuilder get $Code => new ObjectoryQueryBuilder('Code');