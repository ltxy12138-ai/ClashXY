import 'package:flutter/services.dart';

import '../../core/mihomo/binary_manager.dart';

class FlutterAssetMihomoBinarySource implements MihomoBinarySource {
  const FlutterAssetMihomoBinarySource({this.asset = 'assets/core/mihomo.exe'});

  final String asset;

  @override
  Future<Uint8List> load() async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
