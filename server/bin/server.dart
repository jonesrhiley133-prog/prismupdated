import 'dart:io';

import 'package:prism_social_server/prism_social_server.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Entry point. Railway sets PORT and (with the Postgres plugin) DATABASE_URL.
Future<void> main() async {
  final env = Platform.environment;
  final url = env['DATABASE_URL'];
  final ServerStorage storage;
  if (url != null && url.isNotEmpty) {
    storage = PostgresStorage(url, sslMode: env['PGSSLMODE']);
  } else if (env['PRISM_SOCIAL_ALLOW_MEMORY'] == 'true') {
    stderr.writeln('WARNING: DATABASE_URL is not set — using in-memory storage. Data is lost on restart.');
    storage = MemoryStorage();
  } else {
    stderr.writeln('DATABASE_URL is not set. Add a Postgres database to this Railway project and reference its DATABASE_URL, or set PRISM_SOCIAL_ALLOW_MEMORY=true for a throwaway test server.');
    exit(1);
  }
  await storage.init();
  int intEnv(String k, int d) => int.tryParse(env[k] ?? '') ?? d;
  final server = PrismSocialServer(
    storage,
    config: ServerConfig(
      maxMediaBytes: intEnv('MAX_MEDIA_BYTES', 8 * 1024 * 1024),
      maxProfilesPerAccount: intEnv('MAX_PROFILES_PER_ACCOUNT', 10),
      writesPerMinute: intEnv('WRITES_PER_MINUTE', 120),
      registrationsPerHour: intEnv('REGISTRATIONS_PER_HOUR', 20),
      allowRegistration: env['ALLOW_REGISTRATION'] != 'false',
      registrationCode: (env['REGISTRATION_CODE'] ?? '').isEmpty ? null : env['REGISTRATION_CODE'],
    ),
  );
  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final http = await io.serve(server.handler, InternetAddress.anyIPv4, port);
  http.autoCompress = true;
  stdout.writeln('Prism Social server $serverVersion listening on :$port (${url == null ? 'memory' : 'postgres'})');
  ProcessSignal.sigterm.watch().listen((_) async {
    await http.close();
    await storage.close();
    exit(0);
  });
}
