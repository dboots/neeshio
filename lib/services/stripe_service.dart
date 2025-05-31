import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StripeService extends ChangeNotifier {
  static const String _publishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
  static const String _baseUrl = String.fromEnvironment('STRIPE_BACKEND_URL', 
    defaultValue: 'https://your-backend.supabase.co/functions/v1');
  
  final Dio _dio;
  final SupabaseClient _supabase;
  
  bool _isInitialized = false;
  String? _error;
  
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  
  StripeService({Dio? dio, SupabaseClient? supabase})
      : _dio = dio ?? Dio(),
        _supabase = supabase ?? Supabase.instance.client {
    _setupDio();
  }
  
  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
    };
    
    // Add auth token interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _supabase.auth.currentSession?.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          print('Dio error: ${error.message}');
          print('Response: ${error.response?.data}');
        }
        handler.next(error);
      },
    ));
  }
  
  /// Initialize Stripe with publishable key
  Future<void> initialize() async {
    try {
      if (_publishableKey.isEmpty) {
        throw Exception('Stripe publishable key not found. Please set STRIPE_PUBLISHABLE_KEY environment variable.');
      }
      
      Stripe.publishableKey = _publishableKey;
      
      // Configure Stripe
      await Stripe.instance.applySettings();
      
      _isInitialized = true;
      _error = null;
      notifyListeners();
      
      if (kDebugMode) {
        print('Stripe initialized successfully');
      }
    } catch (e) {
      _error = 'Failed to initialize Stripe: ${e.toString()}';
      _isInitialized = false;
      notifyListeners();
      
      if (kDebugMode) {
        print(_error);
      }
      rethrow;
    }
  }
  
  /// Create a subscription for a user
  Future<Map<String, dynamic>> createSubscription({
    required String creatorId,
    required double price,
    String? priceId, // Stripe Price ID if using predefined prices
  }) async {
    try {
      _clearError();
      
      if (!_isInitialized) {
        throw Exception('Stripe not initialized');
      }
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Call your backend to create subscription
      final response = await _dio.post('/stripe-create-subscription', data: {
        'creator_id': creatorId,
        'subscriber_id': userId,
        'price': price,
        'price_id': priceId,
      });
      
      final data = response.data as Map<String, dynamic>;
      
      if (data['client_secret'] != null) {
        // Handle setup intent for future payments
        await _handleSetupIntent(data['client_secret']);
      }
      
      return data;
    } catch (e) {
      _error = 'Failed to create subscription: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Process a one-time payment for subscription setup
  Future<bool> processSubscriptionPayment({
    required String creatorId,
    required double amount,
    required Map<String, dynamic> billingDetails,
  }) async {
    try {
      _clearError();
      
      if (!_isInitialized) {
        throw Exception('Stripe not initialized');
      }
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Step 1: Create payment intent on backend
      final response = await _dio.post('/stripe-create-payment-intent', data: {
        'amount': (amount * 100).round(), // Convert to cents
        'currency': 'usd',
        'creator_id': creatorId,
        'subscriber_id': userId,
        'metadata': {
          'subscription_type': 'creator_subscription',
          'creator_id': creatorId,
        },
      });
      
      final clientSecret = response.data['client_secret'] as String;
      
      // Step 2: Confirm payment with Stripe
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodData(
          billingDetails: BillingDetails(
            name: billingDetails['name'],
            email: billingDetails['email'],
            phone: billingDetails['phone'],
            address: billingDetails['address'] != null 
              ? Address(
                  city: billingDetails['address']['city'],
                  country: billingDetails['address']['country'],
                  line1: billingDetails['address']['line1'],
                  line2: billingDetails['address']['line2'],
                  postalCode: billingDetails['address']['postal_code'],
                  state: billingDetails['address']['state'],
                )
              : null,
          ),
        ),
      );
      
      // Step 3: Verify payment succeeded
      await _verifyPayment(clientSecret, creatorId);
      
      return true;
    } catch (e) {
      _error = 'Payment failed: ${e.toString()}';
      notifyListeners();
      
      if (kDebugMode) {
        print('Payment error: $e');
      }
      
      return false;
    }
  }
  
  /// Handle setup intent for future payments (subscription setup)
  Future<void> _handleSetupIntent(String clientSecret) async {
    try {
      await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodData(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Setup intent error: $e');
      }
      rethrow;
    }
  }
  
  /// Verify payment completion on backend
  Future<void> _verifyPayment(String clientSecret, String creatorId) async {
    try {
      await _dio.post('/stripe-verify-payment', data: {
        'client_secret': clientSecret,
        'creator_id': creatorId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Payment verification error: $e');
      }
      rethrow;
    }
  }
  
  /// Get customer's saved payment methods
  Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      _clearError();
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final response = await _dio.get('/stripe-payment-methods');
      final data = response.data as Map<String, dynamic>;
      
      final paymentMethods = (data['payment_methods'] as List)
          .map((pm) => PaymentMethod.fromJson(pm))
          .toList();
      
      return paymentMethods;
    } catch (e) {
      _error = 'Failed to load payment methods: ${e.toString()}';
      notifyListeners();
      return [];
    }
  }
  
  /// Cancel a subscription
  Future<bool> cancelSubscription(String subscriptionId) async {
    try {
      _clearError();
      
      final response = await _dio.post('/stripe-cancel-subscription', data: {
        'subscription_id': subscriptionId,
      });
      
      return response.data['success'] == true;
    } catch (e) {
      _error = 'Failed to cancel subscription: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  /// Update subscription (change price, etc.)
  Future<bool> updateSubscription({
    required String subscriptionId,
    required String newPriceId,
  }) async {
    try {
      _clearError();
      
      final response = await _dio.post('/stripe-update-subscription', data: {
        'subscription_id': subscriptionId,
        'new_price_id': newPriceId,
      });
      
      return response.data['success'] == true;
    } catch (e) {
      _error = 'Failed to update subscription: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  /// Get subscription details
  Future<Map<String, dynamic>?> getSubscriptionDetails(String subscriptionId) async {
    try {
      _clearError();
      
      final response = await _dio.get('/stripe-subscription/$subscriptionId');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _error = 'Failed to get subscription details: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }
  
  /// Create a Stripe customer (called automatically when needed)
  Future<String?> createCustomer({
    required String email,
    String? name,
  }) async {
    try {
      final response = await _dio.post('/stripe-create-customer', data: {
        'email': email,
        'name': name,
      });
      
      return response.data['customer_id'] as String;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating Stripe customer: $e');
      }
      return null;
    }
  }
  
  /// Get or create Stripe customer
  Future<String?> getOrCreateCustomer() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      
      // Check if customer already exists in our database
      final response = await _dio.get('/stripe-customer');
      
      if (response.data['customer_id'] != null) {
        return response.data['customer_id'] as String;
      }
      
      // Create new customer
      return await createCustomer(
        email: user.email!,
        name: user.userMetadata?['name'],
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting/creating customer: $e');
      }
      return null;
    }
  }
  
  /// Present payment sheet for subscription
  Future<bool> presentSubscriptionPaymentSheet({
    required String creatorId,
    required double amount,
    required String creatorName,
  }) async {
    try {
      _clearError();
      
      // Create payment intent
      final response = await _dio.post('/stripe-create-subscription-payment', data: {
        'amount': (amount * 100).round(),
        'currency': 'usd',
        'creator_id': creatorId,
        'automatic_payment_methods': {'enabled': true},
      });
      
      final paymentIntentClientSecret = response.data['client_secret'] as String;
      final ephemeralKeySecret = response.data['ephemeral_key'] as String;
      final customerId = response.data['customer_id'] as String;
      
      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentClientSecret,
          merchantDisplayName: 'NEESH',
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKeySecret,
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            email: _supabase.auth.currentUser?.email,
          ),
        ),
      );
      
      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();
      
      // Verify payment completed
      await _verifyPayment(paymentIntentClientSecret, creatorId);
      
      return true;
    } catch (e) {
      if (e is StripeException) {
        // Handle user cancellation
        if (e.error.code == FailureCode.Canceled) {
          return false;
        }
      }
      
      _error = 'Payment failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  /// Get invoice history for a customer
  Future<List<Map<String, dynamic>>> getInvoiceHistory() async {
    try {
      final response = await _dio.get('/stripe-invoices');
      return List<Map<String, dynamic>>.from(response.data['invoices'] ?? []);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting invoice history: $e');
      }
      return [];
    }
  }
  
  /// Clear error state
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Clear error message
  void clearError() {
    _clearError();
  }
}

/// Subscription status enum
enum SubscriptionStatus {
  active,
  canceled,
  incomplete,
  incompleteExpired,
  pastDue,
  trialing,
  unpaid,
}

/// Helper class for subscription data
class SubscriptionData {
  final String id;
  final String customerId;
  final String priceId;
  final SubscriptionStatus status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final double amount;
  final String currency;
  
  SubscriptionData({
    required this.id,
    required this.customerId,
    required this.priceId,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.amount,
    required this.currency,
  });
  
  factory SubscriptionData.fromJson(Map<String, dynamic> json) {
    return SubscriptionData(
      id: json['id'],
      customerId: json['customer'],
      priceId: json['items']['data'][0]['price']['id'],
      status: _parseStatus(json['status']),
      currentPeriodStart: DateTime.fromMillisecondsSinceEpoch(
        json['current_period_start'] * 1000,
      ),
      currentPeriodEnd: DateTime.fromMillisecondsSinceEpoch(
        json['current_period_end'] * 1000,
      ),
      cancelAtPeriodEnd: json['cancel_at_period_end'],
      amount: (json['items']['data'][0]['price']['unit_amount'] / 100).toDouble(),
      currency: json['items']['data'][0]['price']['currency'],
    );
  }
  
  static SubscriptionStatus _parseStatus(String status) {
    switch (status) {
      case 'active':
        return SubscriptionStatus.active;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'incomplete':
        return SubscriptionStatus.incomplete;
      case 'incomplete_expired':
        return SubscriptionStatus.incompleteExpired;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'trialing':
        return SubscriptionStatus.trialing;
      case 'unpaid':
        return SubscriptionStatus.unpaid;
      default:
        return SubscriptionStatus.incomplete;
    }
  }
  
  bool get isActive => status == SubscriptionStatus.active || status == SubscriptionStatus.trialing;
  
  String get statusText {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.canceled:
        return 'Canceled';
      case SubscriptionStatus.incomplete:
        return 'Incomplete';
      case SubscriptionStatus.incompleteExpired:
        return 'Expired';
      case SubscriptionStatus.pastDue:
        return 'Past Due';
      case SubscriptionStatus.trialing:
        return 'Trial';
      case SubscriptionStatus.unpaid:
        return 'Unpaid';
    }
  }
}
