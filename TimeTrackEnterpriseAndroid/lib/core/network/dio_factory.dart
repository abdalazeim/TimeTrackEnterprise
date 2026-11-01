import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// ينشئ عميل HTTP واحدًا للتطبيق كله.
///
/// المهل طويلة عن قصد: استضافة Render قد تستغرق أكثر من دقيقة في أول طلب.
Dio createDio({String? baseUrl}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl ?? AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      responseType: ResponseType.json,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );
}
