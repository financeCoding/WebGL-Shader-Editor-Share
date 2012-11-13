//---------------------------------------------------------------------
// Library imports
//
// Allows libraries to be accessed by the application.
// Core libraries are prefixed with dart.
// Third party libraries are specified in the pubspec.yaml file
// and imported with the package prefix.
//---------------------------------------------------------------------

library webgl_lab;

import 'dart:html';
import 'dart:math' as Math;
import 'dart:json';
import 'dart:isolate';
import 'package:spectre/spectre.dart';
import 'package:vector_math/vector_math_browser.dart';

//---------------------------------------------------------------------
// Source files
//---------------------------------------------------------------------

part 'compile_log.dart';
part 'render_state_options.dart';
part 'shader_defaults.dart';
part 'tabbed_element.dart';
part 'texture_dialog.dart';
part 'application/frame_counter.dart';
part 'application/game.dart';

/**
 * The amount of time to wait until attempting to compile the shader.
 *
 * This is so the user has time to type, and so the shader isn't
 * being compiled constantly.
 */
const int _compileDelay = 1000;

/// The [FrameCounter] associated with the application
FrameCounter _counter;
/// The [TextureDialog] associated with the application
TextureDialog _textureDialog;
/// The [RenderStateOptions] associated with the application
RenderStateOptions _renderStateOptions;
/// The time to compile the fragment shader.
int _compileVertexShaderAt = 0;
/// The time to compile the vertex shader.
int _compileFragmentShaderAt = 0;
/// The [CompileLog] for the shader program.
CompileLog _compileLog;

WebSocket ws;

/**
 * Update function for the application.
 *
 * The current [time] is passed in.
 */
void _onUpdate(double time)
{
  _counter.update(time);
  Game.onUpdate(time);

  // For the animation to continue the function
  // needs to set itself again
  window.requestAnimationFrame(_onUpdate);
}

/**
 * Opens the texture dialog.
 */
void _openTextureDialog(_)
{
  _textureDialog.show();
}

/**
 * Callback for when the texture is changed.
 */
void _onTextureChange(String value)
{
  Game instance = Game.instance;

  instance.texture = value;
}

/**
 * Callback for when the model is changed.
 */
void _onModelChange(String value)
{
  Game instance = Game.instance;

  instance.mesh = value;
}

/**
 * Initializes the model buttons.
 */
void _initModelButtons()
{
  
  DivElement shareButton = document.query('#share_button') as DivElement;
  assert(shareButton != null);
  shareButton.on.click.add((_) {
    // Send via websockets the json data of 
    // vertext, fragment and renderer.
    // TODO(adam): pick all the settings for renderer off.
    
    var vertex_shader_source = document.query('#vertex_shader_source') as TextAreaElement;
    var fragment_shader_source = document.query('#fragment_shader_source') as TextAreaElement;
    
    var d = {
      "command" : "store",
      "vertex_shader_source" : vertex_shader_source.value,
      "fragment_shader_source" : fragment_shader_source.value
    };
    ws.send(JSON.stringify(d));
    
  });
  
  DivElement cubeMesh = document.query('#cube_button') as DivElement;
  assert(cubeMesh != null);

  cubeMesh.on.click.add((_) {
    _onModelChange('resources/meshes/cube.mesh');
  });

  DivElement sphereMesh = document.query('#sphere_button') as DivElement;
  assert(sphereMesh != null);

  sphereMesh.on.click.add((_) {
    _onModelChange('resources/meshes/sphere.mesh');
  });

  DivElement planeMesh = document.query('#plane_button') as DivElement;
  assert(planeMesh != null);

  planeMesh.on.click.add((_) {
    _onModelChange('resources/meshes/plane.mesh');
  });

  DivElement cylinderMesh = document.query('#cylinder_button') as DivElement;
  assert(cylinderMesh != null);

  cylinderMesh.on.click.add((_) {
    _onModelChange('resources/meshes/cylinder.mesh');
  });
}

/**
 * Callback for when the rasterizer state is modified.
 */
void _onRasterizerStateChanged(String value)
{
  print(value);
  Game.instance.setRasterizerStateProperties(value);
}

/**
 * Callback for when the depth state is modified.
 */
void _onDepthStateChanged(String value)
{
  print(value);
  Game.instance.setDepthStateProperties(value);
}

/**
 * Callback for when the blend state is modified.
 */
void _onBlendStateChanged(String value)
{
  print(value);
  Game.instance.setBlendStateProperties(value);
}

/**
 * Quickfix for removing non-ascii chars
 */
_toAscii(String value) {
  StringBuffer sb = new StringBuffer();
  for (int i=0; i<value.length; i++) {
    int c = value.charCodeAt(i);
    if (c == 160) { 
      sb.add(" ");
    } else if (c >= 0 && c < 128) {
      sb.addCharCode(c);
    } else if (c >= 128) {
      print("warning at index $i of is >= 128: '$c' '${new String.fromCharCodes([c])}'");
    }
  }
  
  return sb.toString();
}

/**
 * Callback for when the vertex shader text is changed.
 */
void _onVertexShaderTextChanged(String value)
{
  Date date = new Date.now();
  if (_compileVertexShaderAt > date.millisecondsSinceEpoch)
    return;

  Game.instance.setVertexSource(_toAscii(value));
  _updateCompilerLog();
}

/**
 * Callback for when the fragment shader text is changed.
 */
void _onFragmentShaderTextChanged(String value)
{  
  Date date = new Date.now();
  if (_compileFragmentShaderAt > date.millisecondsSinceEpoch)
    return;

  Game.instance.setFragmentSource(_toAscii(value));
  _updateCompilerLog();
}

/**
 * Initialize the renderer UI.
 */
void _initRendererOptions()
{
  TabbedElement rendererOptions = new TabbedElement();
  rendererOptions.addTab('#vertex_tab', '#vertex_shader');
  rendererOptions.addTab('#fragment_tab', '#fragment_shader');
  rendererOptions.addTab('#renderer_tab', '#renderer_options');

  TextAreaElement vertexShaderText = document.query('#vertex_shader_source') as TextAreaElement;
  vertexShaderText.value = _defaultVertexSource;

  vertexShaderText.on.keyUp.add((_) {
    Date date = new Date.now();
    _compileVertexShaderAt = date.millisecondsSinceEpoch + _compileDelay;

    Timer timer = new Timer(_compileDelay, (_) {
      _onVertexShaderTextChanged(vertexShaderText.value);
    });
  });

  Game.instance.setVertexSource(vertexShaderText.value);

  TextAreaElement fragmentShaderText = document.query('#fragment_shader_source') as TextAreaElement;
  fragmentShaderText.value = _defaultFragmentSource;

  fragmentShaderText.on.keyUp.add((_) {
    Date date = new Date.now();
    _compileFragmentShaderAt = date.millisecondsSinceEpoch + _compileDelay;

    Timer timer = new Timer(_compileDelay, (_) {
      _onFragmentShaderTextChanged(fragmentShaderText.value);
    });
  });

  Game.instance.setFragmentSource(fragmentShaderText.value);
}

/**
 * Initializes the compiler output.
 */
void _initCompilerLog()
{
  TabbedElement compilerOutput = new TabbedElement();
  compilerOutput.addTab('#error_tab', '#error_list');
  compilerOutput.addTab('#warning_tab', '#warning_list');

  _compileLog = new CompileLog();
}

/**
 * Updates the compiler output.
 */
void _updateCompilerLog()
{
  Game instance = Game.instance;
  _compileLog.clear();

  if (!instance.isProgramValid)
  {
    _compileLog.addToLog('Vertex', instance.vertexShaderLog);
    _compileLog.addToLog('Fragment', instance.fragmentShaderLog);
  }
}

Map<String, String> get queryString {
  var results = {};
  var qs;
  qs = window.location.search.isEmpty ? '' 
      : window.location.search.substring(1);
  var pairs = qs.split('&');

  for(final pair in pairs){
    var kv = pair.split('=');
    if (kv.length != 2) continue;
    results[kv[0]] = kv[1];
  }

  return results;
}

void setupWebsocket() {
  ws = new WebSocket("ws://${window.location.host}/ws");
  ws.on.open.add((a) {
    print("websocket opened $a");
    if (queryString.containsKey('q')) {
      ws.send(JSON.stringify({
        "command" : "load",
        "id" : queryString['q']
      }));
    }

  });

  ws.on.error.add((e) {
    print("websocket error $e");
  });
  ws.on.close.add((c) {
    print("websocket close $c");
  });

  ws.on.message.add((message) {
    Map jsonFromServer = JSON.parse(message.data);
    if (jsonFromServer.containsKey("command")) {
      if (jsonFromServer["command"] == "load_shaders") {
        // Loading shader code from server. 
        var vertex_shader_source = document.query('#vertex_shader_source') as TextAreaElement;
        var fragment_shader_source = document.query('#fragment_shader_source') as TextAreaElement;
        vertex_shader_source.value = jsonFromServer["vertexShaderSource"];
        fragment_shader_source.value = jsonFromServer["fragmentShaderSource"];
        _onFragmentShaderTextChanged(fragment_shader_source.value);
        _onVertexShaderTextChanged(vertex_shader_source.value);
        // TODO(adam): setup configRenderer
      } else if (jsonFromServer["command"] == "load_id") {
        var link_back_share = document.query('#link_back_share') as AnchorElement;
        var baseUrl = window.location.toString().split('?')[0];
        var oid = jsonFromServer["code_id"];
        link_back_share.href = "${baseUrl}?q=${oid}";
        link_back_share.innerHTML = "${oid}";
      }
    }
  });
}

/**
 * Main entrypoint for every Dart application.
 */
void main()
{
  // Initialize the WebGL side
  Game.onInitialize();
  
  // open up web socket connection
  setupWebsocket();
  
  _counter = new FrameCounter('#frame_counter');

  // Initialize the UI side
  _textureDialog = new TextureDialog();
  _textureDialog.submitCallback = _onTextureChange;

  DivElement replaceButton = document.query('#replace') as DivElement;
  replaceButton.on.click.add(_openTextureDialog);

  _initModelButtons();

  _renderStateOptions = new RenderStateOptions();
  _renderStateOptions.rasterizerCallback = _onRasterizerStateChanged;
  _renderStateOptions.depthStateCallback = _onDepthStateChanged;
  _renderStateOptions.blendStateCallback = _onBlendStateChanged;

  _initRendererOptions();

  _initCompilerLog();

  // Start the animation loop
  window.requestAnimationFrame(_onUpdate);
}
