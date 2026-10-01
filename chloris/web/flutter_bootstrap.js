{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  // Flutter's default worker unregisters itself. Keep the music worker as
  // the single owner of this scope so offline playback survives a restart.
  serviceWorkerSettings: {
    serviceWorkerUrl: "music_offline_worker.js",
    timeoutMillis: 30000
  },
  config: {
    renderer: "canvaskit",
    canvasKitVariant: "full",
    canvasKitBaseUrl: "canvaskit/",
    useLocalCanvasKit: true
  }
});
