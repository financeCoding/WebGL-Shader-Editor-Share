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
int _compileVertexShaderAt;
/// The time to compile the vertex shader.
int _compileFragmentShaderAt;
/// The [CompileLog] for the shader program.
CompileLog _compileLog;

WebSocket ws;
Function onMessage;

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
    // #vertex_shader_source
    // #fragment_shader_source
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
 * Callback for when the vertex shader text is changed.
 */
void _onVertexShaderTextChanged(String value)
{
  Date date = new Date.now();
  if (_compileVertexShaderAt > date.millisecondsSinceEpoch)
    return;

  Game.instance.setVertexSource(value);
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

  Game.instance.setFragmentSource(value);
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

void setupWebsocket() {
  ws = new WebSocket("ws://${window.location.host}/ws");
  ws.on.open.add((a) {
    print("open $a");
  });

  ws.on.error.add((e) {
    print("error $e");
  });
  ws.on.close.add((c) {
    print("close $c");
  });

  ws.on.message.add((message) {
    print("ws.on.message = $message");
    Map jsonFromServer = JSON.parse(message.data);
    print(jsonFromServer);
    if (jsonFromServer.containsKey("command")) {
      if (jsonFromServer["command"] == "load_shaders") {
        // Loading shader code from server. 
      }
    }
    
//    if (onMessage is Function) {
//      onMessage(jsonFiles);
//    }
  });
}

loadData() {
  ws.send(JSON.stringify({"command" : "load"}));
}

/**
 * Main entrypoint for every Dart application.
 */
void main()
{
  setupWebsocket();
  //loadData();
  
  // Initialize the WebGL side
  Game.onInitialize();
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
