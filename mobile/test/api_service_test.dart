import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  group('ApiService Unit Tests', () {
    test('checkHealth returns true when backend responds with 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/health');
        return http.Response(jsonEncode({'status': 'healthy'}), 200);
      });

      final api = ApiService(
        baseUrl: 'https://test-api.com/api/v1',
        client: mockClient,
      );

      final isHealthy = await api.checkHealth();
      expect(isHealthy, isTrue);
    });

    test('getCustomers correctly parses customer list', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customers');
        return http.Response(
          jsonEncode({
            'success': true,
            'count': 1,
            'data': [
              {
                'id': 'cust-1',
                'consumerNumber': '1122334455667',
                'phone': '+91 98470 11111',
                'name': 'Ramesh Kumar',
                'address': 'Kochi, Kerala',
                'createdAt': '2026-03-01T10:00:00.000Z',
                'updatedAt': '2026-03-01T10:00:00.000Z',
              }
            ]
          }),
          200,
        );
      });

      final api = ApiService(
        baseUrl: 'https://test-api.com/api/v1',
        client: mockClient,
      );

      final customers = await api.getCustomers();
      expect(customers.length, 1);
      expect(customers.first.consumerNumber, '1122334455667');
      expect(customers.first.name, 'Ramesh Kumar');
    });

    test('createPurchase sends proper payload and returns created purchase', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/purchases');
        final body = jsonDecode(request.body) as Map;
        expect(body['batchNumber'], 'BATCH-540-X');
        expect(body['wattage'], 540);
        expect(body['quantity'], 2);
        expect(body['serialNumbers'], ['HZ-1', 'HZ-2']);

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'purch-1',
              'purchaseDate': '2026-03-10T00:00:00.000Z',
              'batchNumber': 'BATCH-540-X',
              'wattage': 540,
              'quantity': 2,
              'serialNumbers': ['HZ-1', 'HZ-2'],
              'unitPurchasePrice': 12000.0,
              'totalPurchaseAmount': 24000.0,
              'createdAt': '2026-03-10T00:00:00.000Z',
              'updatedAt': '2026-03-10T00:00:00.000Z',
            }
          }),
          201,
        );
      });

      final api = ApiService(
        baseUrl: 'https://test-api.com/api/v1',
        client: mockClient,
      );

      final purchase = await api.createPurchase(
        batchNumber: 'BATCH-540-X',
        wattage: 540,
        quantity: 2,
        serialNumbers: ['HZ-1', 'HZ-2'],
        unitPurchasePrice: 12000.0,
      );

      expect(purchase.id, 'purch-1');
      expect(purchase.totalPurchaseAmount, 24000.0);
    });

    test('throws ApiException on 400 error with descriptive message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': 'Duplicate serial number in batch entry: "HZ-1".',
          }),
          400,
        );
      });

      final api = ApiService(
        baseUrl: 'https://test-api.com/api/v1',
        client: mockClient,
      );

      expect(
        () => api.createPurchase(
          batchNumber: 'BATCH-1',
          wattage: 540,
          quantity: 2,
          serialNumbers: ['HZ-1', 'HZ-1'],
          unitPurchasePrice: 10000.0,
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Duplicate serial number'),
        )),
      );
    });
  });
}
