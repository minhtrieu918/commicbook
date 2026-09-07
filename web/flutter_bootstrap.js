{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Dùng CanvasKit đã được đóng gói cùng bản build để giao diện vẫn tải ổn
    // định khi CDN bên ngoài chậm hoặc bị chặn.
    canvasKitBaseUrl: 'canvaskit/',
  },
});
