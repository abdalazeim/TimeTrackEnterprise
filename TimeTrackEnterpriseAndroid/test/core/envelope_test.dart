import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/error/failure.dart';
import 'package:generic_template/core/network/envelope.dart';
import 'package:generic_template/core/network/failure_mapper.dart';

void main() {
  group('Envelope', () {
    test('يفك data القياسي', () {
      final result = Envelope.dataMap(<String, dynamic>{
        'success': true,
        'message': 'ok',
        'data': <String, dynamic>{'id': 1},
      });
      expect(result, <String, dynamic>{'id': 1});
    });

    test('يعيد الكائن نفسه عند غياب data (استثناء موثّق)', () {
      final result = Envelope.dataMap(<String, dynamic>{
        'success': true,
        'id': 7,
        'name': 'شحنة',
      });
      expect(result['id'], 7);
    });

    test('يرفض success=false ويحوّله إلى ValidationFailure', () {
      expect(
        () => Envelope.dataMap(<String, dynamic>{
          'success': false,
          'message': 'البيانات غير صالحة',
          'errors': <String, dynamic>{
            'username': <String>['هذا الحقل مطلوب'],
          },
        }),
        throwsA(
          isA<ApiException>().having(
            (error) => error.failure,
            'failure',
            isA<ValidationFailure>()
                .having(
                  (failure) => failure.fields['username'],
                  'username',
                  'هذا الحقل مطلوب',
                )
                .having(
                  (failure) => failure.message,
                  'message',
                  'البيانات غير صالحة',
                ),
          ),
        ),
      );
    });

    test('dataList يقرأ items داخل data', () {
      final result = Envelope.dataList(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{'id': 1},
          ],
        },
      });
      expect(result, hasLength(1));
    });

    test('dataList يرفض شكلًا غير متوقع', () {
      expect(
        () => Envelope.dataList(<String, dynamic>{'success': true, 'data': 5}),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
