import 'package:flutter_test/flutter_test.dart';
import 'package:trace_foodchain_app/helpers/handbook_links.dart';

void main() {
  String id(String url) => url.split('/').last;

  test('registrars get the registrar handbook in their language', () {
    expect(id(handbookUrl('registrar', 'de')),
        '1gWofLWNU7FhLhvGPj0CJOMackXSaChsWEMPGOOGpzHU');
    expect(id(handbookUrl('registrar', 'es')),
        '11sTTMlEa2I1UZd4CspSrz6IrDJer6zuWkuAbqlOA31U');
  });

  test('coordinators and admins get the coordinator handbook', () {
    for (final role in [
      'registrarCoordinator',
      'countryCoordinator',
      'tfcAdmin',
      'SUPERADMIN',
    ]) {
      expect(id(handbookUrl(role, 'en')),
          '1dd9BusLcGjxzlfjZbe3OIqw9Cc2RTcEBaXGB5DmVT4I',
          reason: role);
    }
  });

  test('languages without a translation fall back to English', () {
    expect(id(handbookUrl('registrar', 'fr')),
        '1duxbHg2gNURyFwTNJF5Xl7DthGtt-bEhzEF3ed0eACk');
  });

  test('other roles and signed-out users keep the EUDR handbook', () {
    expect(id(handbookUrl('Trader', 'fr')),
        '19Z0dMR6CqHqaT2nU9qM4uzHftNFlIeZpd2AlyuHngP4');
    expect(id(handbookUrl('', 'de')),
        '1wURF_uGIW3eKHh1qEn380_JE5tOdOyZRfFRQuL46Hn0');
    expect(id(handbookUrl(null, 'xx')),
        '1JcNxTNEs6nkTDotVzFw-AFU0arB6T8aI1BfzKAuDF0A');
  });
}
