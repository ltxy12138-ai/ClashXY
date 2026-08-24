import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';
import 'two_sui_http_client.dart';

class PanelReachability {
  const PanelReachability({
    required this.url,
    required this.https,
    required this.reachable,
  });

  final Uri url;
  final bool https;
  final bool reachable;
}

class PanelSetupService {
  const PanelSetupService();

  Future<PanelReachability> test(
    Uri input, {
    bool allowInsecureHttp = false,
  }) async {
    final url = TwoSuiHttpClient.normalizePanelUrl(
      input,
      allowInsecureHttp: allowInsecureHttp,
    );
    try {
      final response = await http
          .get(url.resolve('login'))
          .timeout(const Duration(seconds: 10));
      return PanelReachability(
        url: url,
        https: url.scheme == 'https',
        reachable: response.statusCode >= 200 && response.statusCode < 400,
      );
    } catch (error) {
      throw PanelException('Panel is not reachable.', cause: error);
    }
  }
}
