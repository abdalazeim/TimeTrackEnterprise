import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/features/auth/domain/entities/app_user.dart';

void main() {
  group('AppUser', () {
    test('يفك id الرقمي', () {
      final user = AppUser.fromJson(<String, dynamic>{
        'id': 5,
        'username': 'ahmed',
      });
      expect(user.id, 5);
      expect(user.username, 'ahmed');
    });

    test('يتقبل id النصي (بعض النماذج تعيده كنص)', () {
      final user = AppUser.fromJson(<String, dynamic>{
        'id': '12',
        'username': 'sara',
      });
      expect(user.id, 12);
    });

    test('يستخدم name عند غياب username', () {
      final user = AppUser.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'مدير النظام',
      });
      expect(user.username, 'مدير النظام');
    });

    test('لا ينهار عند حقل ناقص', () {
      final user = AppUser.fromJson(<String, dynamic>{'id': null});
      expect(user.id, 0);
      expect(user.username, 'مستخدم');
    });

    test('toJson يحتفظ بالحقول الأصلية', () {
      final user = AppUser.fromJson(<String, dynamic>{
        'id': 3,
        'username': 'ali',
        'role': 'admin',
      });
      expect(user.toJson()['role'], 'admin');
      expect(user.toJson()['id'], 3);
    });
  });
}
