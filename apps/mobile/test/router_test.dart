import 'package:beacon_check_in/core/auth/auth_controller.dart';
import 'package:beacon_check_in/core/models/api_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('role routing helpers', () {
    test('maps API roles and admin flags', () {
      expect(UserRole.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('user'), UserRole.user);
      expect(UserRole.fromString(null), UserRole.user);
      expect(UserRole.admin.isAdmin, isTrue);
      expect(UserRole.superAdmin.isAdmin, isTrue);
      expect(UserRole.user.isAdmin, isFalse);
    });

    test('auth state exposes admin/user routing flags', () {
      const admin = AuthState(
        user: User(
          id: '1',
          displayName: 'Admin',
          email: 'admin@example.com',
          role: UserRole.admin,
          mustChangePassword: false,
        ),
        initialized: true,
      );
      const user = AuthState(
        user: User(
          id: '2',
          displayName: 'User',
          email: 'user@example.com',
          role: UserRole.user,
          mustChangePassword: false,
        ),
        initialized: true,
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.isUser, isFalse);
      expect(user.isUser, isTrue);
      expect(user.isAdmin, isFalse);
    });
  });
}
