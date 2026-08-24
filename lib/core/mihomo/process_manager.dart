import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../security/app_logger.dart';
import '../security/secret_redactor.dart';

class ProcessManager {
  ProcessManager(this._logger, {this.redactor = const SecretRedactor()});

  final AppLogger _logger;
  final SecretRedactor redactor;
  final StreamController<int> _exits = StreamController<int>.broadcast();
  final List<String> _recentOutput = <String>[];
  Process? _process;
  int? _lastExitCode;

  bool get running => _process != null;
  int? get lastExitCode => _lastExitCode;
  Stream<int> get exits => _exits.stream;

  Future<void> validate({
    required File executable,
    required File config,
  }) async {
    final result = await Process.run(executable.path, <String>[
      '-t',
      '-d',
      config.parent.path,
      '-f',
      config.path,
    ], runInShell: false);
    if (result.exitCode == 0) return;
    final output = '${result.stdout}\n${result.stderr}';
    throw MihomoException(describeFailure(result.exitCode, output: output));
  }

  Future<void> start({required File executable, required File config}) async {
    if (_process != null) {
      throw const MihomoException('Mihomo 已经在运行。');
    }
    _lastExitCode = null;
    _recentOutput.clear();
    final process = await Process.start(
      executable.path,
      <String>['-d', config.parent.path, '-f', config.path],
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    _process = process;
    _readLogs(process.stdout, LogLevel.info);
    _readLogs(process.stderr, LogLevel.warning);
    unawaited(
      process.exitCode.then((code) {
        if (identical(_process, process)) _process = null;
        _lastExitCode = code;
        _logger.log(LogLevel.info, 'Mihomo exited with code $code.');
        _exits.add(code);
      }),
    );
  }

  Future<void> restart({required File executable, required File config}) async {
    await stop();
    await start(executable: executable, config: config);
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    _process = null;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 2));
    }
  }

  void _readLogs(Stream<List<int>> source, LogLevel level) {
    source.transform(utf8.decoder).transform(const LineSplitter()).listen(
      (line) {
        final safeLine = redactor.redact(line).trim();
        if (safeLine.isNotEmpty) {
          _recentOutput.add(safeLine);
          if (_recentOutput.length > 20) _recentOutput.removeAt(0);
        }
        _logger.log(level, line);
      },
      onError: (Object error, StackTrace stackTrace) => _logger.log(
        LogLevel.warning,
        'Could not read Mihomo output.',
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  String describeFailure(int? code, {String? output}) {
    final details = redactor
        .redact(output ?? _recentOutput.join('\n'))
        .toLowerCase();
    if (details.contains('address already in use') ||
        details.contains('only one usage of each socket address')) {
      return '本机代理或控制端口已被其他应用占用。请先退出其他 Clash/Mihomo 客户端，或在设置中修改端口。';
    }
    if (details.contains('configure tun interface') ||
        details.contains('the object already exists')) {
      return 'Windows TUN 与其他 VPN/Clash 客户端冲突。请先断开或退出其他客户端后重试。';
    }
    if (details.contains('access is denied') ||
        details.contains('permission denied')) {
      return 'Mihomo 无法创建 Windows TUN，请确认已授予管理员权限。';
    }
    if ((details.contains('geoip') ||
            details.contains('geosite') ||
            details.contains('metadb') ||
            details.contains('mmdb')) &&
        (details.contains('download') ||
            details.contains('timeout') ||
            details.contains('connection'))) {
      return '规则数据库（GeoIP/GeoSite）下载失败。请先保持现有网络代理可用并重试；'
          '配置校验完成后，再按提示退出其他 Clash/Mihomo 客户端。';
    }
    if (details.contains('rule provider') &&
        (details.contains('download') ||
            details.contains('timeout') ||
            details.contains('connection'))) {
      return '远程规则集下载失败。请先保持现有网络代理可用并重试；'
          '配置校验完成后，再按提示退出其他 Clash/Mihomo 客户端。';
    }
    if (details.contains('yaml') ||
        details.contains('parse config') ||
        details.contains('configuration file')) {
      return '配置无法通过 Mihomo 校验，请检查订阅或自定义 YAML。';
    }
    return code == null
        ? 'Mihomo 启动失败。请检查配置，或先退出其他 Clash/Mihomo 客户端后重试。'
        : 'Mihomo 启动失败（退出码 $code）。请检查配置，或先退出其他 Clash/Mihomo 客户端后重试。';
  }

  Future<void> dispose() async {
    await stop();
    await _exits.close();
  }
}
