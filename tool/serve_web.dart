// Minimal static file server for smoke-testing the built web app locally.
// Not part of the app; used only for local verification.
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = args.isNotEmpty ? args[0] : 'build/web';
  final port = args.length > 1 ? int.parse(args[1]) : 8899;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Serving $root on http://127.0.0.1:$port');
  await for (final req in server) {
    var path = req.uri.path;
    if (path == '/' || path.isEmpty) path = '/index.html';
    final file = File('$root$path');
    if (await file.exists()) {
      final ext = path.split('.').last;
      final type = <String, String>{
        'html': 'text/html',
        'js': 'text/javascript',
        'json': 'application/json',
        'wasm': 'application/wasm',
        'png': 'image/png',
        'ico': 'image/x-icon',
        'otf': 'font/otf',
        'ttf': 'font/ttf',
        'css': 'text/css',
      }[ext];
      if (type != null) req.response.headers.contentType = ContentType.parse(type);
      await req.response.addStream(file.openRead());
    } else {
      req.response.statusCode = HttpStatus.notFound;
    }
    await req.response.close();
  }
}
