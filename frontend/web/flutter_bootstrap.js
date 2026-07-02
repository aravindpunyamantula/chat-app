{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Force canvaskit renderer — skwasm (WebAssembly) is incompatible with
    // socket_io_client and causes MIME-type errors in dev servers.
    renderer: "canvaskit",
  },
});
