import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enhanced StripeService for flutter_stripe 11.5
///
/// Key changes from previous version:
/// - Updated payment method data structure
/// - Improved error handling with StripeException
/// - Enhanced Payment Sheet integration
/// - Better subscription management
/// - Updated API parameter structure
class StripeService extends ChangeNotifier {
  static const String _publishableKey =
      String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
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

  /// Initialize Stripe with publishable key and settings
  Future<void> initialize({
    String? merchantIdentifier,
    String? urlScheme,
  }) async {
    try {
      if (_publishableKey.isEmpty) {
        throw Exception(
            'Stripe publishable key not found. Please set STRIPE_PUBLISHABLE_KEY environment variable.');
      }

      // Set publishable key
      Stripe.publishableKey = _publishableKey;

      // Set optional parameters
      if (merchantIdentifier != null) {
        Stripe.merchantIdentifier = merchantIdentifier;
      }
      if (urlScheme != null) {
        Stripe.urlScheme = urlScheme;
      }

      // Apply settings
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

  /// Create a subscription for a user using Payment Sheet
  Future<Map<String, dynamic>> createSubscription({
    required String creatorId,
    required double price,
    String? priceId,
    Map<String, dynamic>? metadata,
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

      // Call backend to create subscription
      final response = await _dio.post('/stripe-create-subscription', data: {
        'creator_id': creatorId,
        'subscriber_id': userId,
        'price': price,
        'price_id': priceId,
        'metadata': metadata ?? {},
      });

      final data = response.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      _error = 'Failed to create subscription: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Process a subscription payment using Payment Sheet
  Future<bool> processSubscriptionPayment({
    required String creatorId,
    required double amount,
    required String creatorName,
    Map<String, dynamic>? metadata,
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

      // Step 1: Create setup intent for subscription
      final response =
          await _dio.post('/stripe-create-subscription-setup', data: {
        'amount': (amount * 100).round(), // Convert to cents
        'currency': 'usd',
        'creator_id': creatorId,
        'subscriber_id': userId,
        'metadata': {
          'subscription_type': 'creator_subscription',
          'creator_id': creatorId,
          ...?metadata,
        },
      });

      final setupIntentClientSecret =
          response.data['setup_intent_client_secret'] as String;
      final ephemeralKeySecret = response.data['ephemeral_key'] as String;
      final customerId = response.data['customer_id'] as String;

      // Step 2: Initialize Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          // Use setupIntentClientSecret for subscriptions
          setupIntentClientSecret: setupIntentClientSecret,
          merchantDisplayName: 'NEESH',
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKeySecret,
          // Updated parameter structure for 11.5
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            email: _supabase.auth.currentUser?.email,
          ),
          // Payment method order (optional - specify preferred payment methods)
          paymentMethodOrder: const ['card', 'apple_pay', 'google_pay'],
          // Enhanced appearance options in 11.5
          appearance: const PaymentSheetAppearance(
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: Color(0xFF300489),
                ),
              ),
            ),
          ),
        ),
      );

      // Step 3: Present Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // Step 4: Verify setup completed on backend
      await _verifySetupIntent(setupIntentClientSecret, creatorId);

      return true;
    } on StripeException catch (e) {
      // Handle Stripe-specific errors
      if (e.error.code == FailureCode.Canceled) {
        // User cancelled
        return false;
      }

      _error = 'Payment failed: ${e.error.localizedMessage ?? e.error.message}';
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Payment failed: ${e.toString()}';
      notifyListeners();

      if (kDebugMode) {
        print('Payment error: $e');
      }

      return false;
    }
  }

  /// Create a payment method with updated parameter structure
  Future<PaymentMethod?> createPaymentMethod({
    required PaymentMethodParams params,
    Map<String, String>? options,
  }) async {
    try {
      _clearError();

      if (!_isInitialized) {
        throw Exception('Stripe not initialized');
      }

      // Updated method call for 11.5 - options parameter is not supported in this method
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: params,
      );

      return paymentMethod;
    } on StripeException catch (e) {
      _error =
          'Failed to create payment method: ${e.error.localizedMessage ?? e.error.message}';
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to create payment method: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// Confirm payment with updated parameter structure
  Future<PaymentIntent?> confirmPayment({
    required String clientSecret,
    required PaymentMethodParams data,
    PaymentMethodOptions? options,
  }) async {
    try {
      _clearError();

      if (!_isInitialized) {
        throw Exception('Stripe not initialized');
      }

      // Updated confirmPayment call for 11.5
      final paymentIntent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: data,
        options: options,
      );

      return paymentIntent;
    } on StripeException catch (e) {
      _error =
          'Payment confirmation failed: ${e.error.localizedMessage ?? e.error.message}';
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Payment confirmation failed: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// Confirm setup intent with updated parameter structure
  Future<SetupIntent?> confirmSetupIntent({
    required String clientSecret,
    required PaymentMethodParams data,
    Map<String, String>? options,
  }) async {
    try {
      _clearError();

      if (!_isInitialized) {
        throw Exception('Stripe not initialized');
      }

      // Updated confirmSetupIntent call for 11.5 - uses positional parameters
      final setupIntent = await Stripe.instance.confirmSetupIntent(
          paymentIntentClientSecret: clientSecret, params: data);

      return setupIntent;
    } on StripeException catch (e) {
      _error =
          'Setup intent confirmation failed: ${e.error.localizedMessage ?? e.error.message}';
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Setup intent confirmation failed: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// Verify setup intent completion on backend
  Future<void> _verifySetupIntent(String clientSecret, String creatorId) async {
    try {
      await _dio.post('/stripe-verify-setup-intent', data: {
        'client_secret': clientSecret,
        'creator_id': creatorId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Setup intent verification error: $e');
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

  /// Update subscription
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
  Future<SubscriptionData?> getSubscriptionDetails(
      String subscriptionId) async {
    try {
      _clearError();

      final response = await _dio.get('/stripe-subscription/$subscriptionId');
      final data = response.data as Map<String, dynamic>;

      return SubscriptionData.fromJson(data);
    } catch (e) {
      _error = 'Failed to get subscription details: ${e.toString()}';
      notifyListeners();
      return null;
    }
  }

  /// Create a Stripe customer
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

      // Check if customer already exists
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

  /// Present Customer Sheet for payment method management
  Future<void> presentCustomerSheet() async {
    try {
      _clearError();

      if (!_isInitialized) {
        throw Exception('Stripe not initialized');
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get customer and ephemeral key from backend
      final response = await _dio.post('/stripe-customer-sheet-setup');
      final customerId = response.data['customer_id'] as String;
      final ephemeralKeySecret = response.data['ephemeral_key'] as String;

      // Initialize Customer Sheet
      await Stripe.instance.initCustomerSheet(
        customerSheetInitParams: CustomerSheetInitParams(
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKeySecret,
          merchantDisplayName: 'NEESH',
          style: ThemeMode.system,
          // Enhanced appearance options in 11.5
          appearance: const PaymentSheetAppearance(
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: Color(0xFF300489),
                ),
              ),
            ),
          ),
        ),
      );

      // Present Customer Sheet
      final result = await Stripe.instance.presentCustomerSheet();

      if (kDebugMode) {
        print('Customer Sheet result: $result');
      }
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        _error =
            'Customer Sheet failed: ${e.error.localizedMessage ?? e.error.message}';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Customer Sheet failed: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Helper method to create card payment method params
  static PaymentMethodParams createCardPaymentMethodParams({
    BillingDetails? billingDetails,
  }) {
    return PaymentMethodParams.card(
      paymentMethodData: PaymentMethodData(
        billingDetails: billingDetails,
      ),
    );
  }

  /// Helper method to create ideal payment method params
  static PaymentMethodParams createIdealPaymentMethodParams({
    required String bankName,
    BillingDetails? billingDetails,
  }) {
    return PaymentMethodParams.ideal(
      paymentMethodData: PaymentMethodDataIdeal(
        bankName: bankName,
        billingDetails: billingDetails,
      ),
    );
  }

  /// Get invoice history for a customer
  Future<List<InvoiceData>> getInvoiceHistory() async {
    try {
      final response = await _dio.get('/stripe-invoices');
      final invoices = response.data['invoices'] as List;

      return invoices.map((invoice) => InvoiceData.fromJson(invoice)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting invoice history: $e');
      }
      return [];
    }
  }

  /// Reset Payment Sheet customer (clears authentication state)
  Future<void> resetPaymentSheetCustomer() async {
    try {
      await Stripe.instance.resetPaymentSheetCustomer();
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting Payment Sheet customer: $e');
      }
    }
  }

  /// Check if Apple Pay is supported
  Future<bool> isApplePaySupported() async {
    try {
      return await Stripe.instance.isPlatformPaySupported();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Apple Pay support: $e');
      }
      return false;
    }
  }

  /// Check if Google Pay is supported
  Future<bool> isGooglePaySupported() async {
    try {
      return await Stripe.instance.isPlatformPaySupported();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking Google Pay support: $e');
      }
      return false;
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

/// Enhanced subscription data model
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
  final DateTime? canceledAt;
  final DateTime? trialEnd;
  final Map<String, dynamic>? metadata;

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
    this.canceledAt,
    this.trialEnd,
    this.metadata,
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
      amount:
          (json['items']['data'][0]['price']['unit_amount'] / 100).toDouble(),
      currency: json['items']['data'][0]['price']['currency'],
      canceledAt: json['canceled_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['canceled_at'] * 1000)
          : null,
      trialEnd: json['trial_end'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['trial_end'] * 1000)
          : null,
      metadata: json['metadata'],
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

  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trialing;

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'price_id': priceId,
      'status': status.name,
      'current_period_start': currentPeriodStart.toIso8601String(),
      'current_period_end': currentPeriodEnd.toIso8601String(),
      'cancel_at_period_end': cancelAtPeriodEnd,
      'amount': amount,
      'currency': currency,
      'canceled_at': canceledAt?.toIso8601String(),
      'trial_end': trialEnd?.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Invoice data model
class InvoiceData {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final DateTime created;
  final DateTime? dueDate;
  final String? description;
  final String? subscriptionId;

  InvoiceData({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.created,
    this.dueDate,
    this.description,
    this.subscriptionId,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    return InvoiceData(
      id: json['id'],
      amount: (json['amount_paid'] / 100).toDouble(),
      currency: json['currency'],
      status: json['status'],
      created: DateTime.fromMillisecondsSinceEpoch(json['created'] * 1000),
      dueDate: json['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['due_date'] * 1000)
          : null,
      description: json['description'],
      subscriptionId: json['subscription'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'status': status,
      'created': created.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'description': description,
      'subscription_id': subscriptionId,
    };
  }
}
