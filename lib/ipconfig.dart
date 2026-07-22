import 'dart:io' show Platform;

class ApiConfig {
  /// Override this with your machine's local IP address when running
  /// on a physical Android device (e.g., "192.168.1.10").
  /// Set to `null` to use automatic platform detection.
  static String? customHost;

  /// The port your Docker API is running on.
  static const int port = 3000;

  /// Automatically resolves the correct host based on the platform:
  /// - Android emulator → 10.0.2.2 (host loopback)
  /// - Android physical → uses [customHost] if set, otherwise falls back to 10.0.2.2
  /// - iOS simulator   → localhost (runs on host machine)
  /// - Web / Desktop   → localhost
  static String get _host {
    // If a custom host is explicitly provided, use it (for physical Android devices)
    if (customHost != null) return customHost!;

    try {
      if (Platform.isAndroid) {
        // 10.0.2.2 is the host machine loopback from Android emulator.
        // For physical devices, set [customHost] to your machine's local IP.
        return "10.0.2.2";
      }
    } catch (_) {
      // Platform not available (e.g., web), fall through to localhost
    }

    return "localhost";
  }

  static String get baseUrl => "http://$_host:$port/api/v1";

  static String get login => "$baseUrl/auth/login";
  static String get register => "$baseUrl/auth";

  // --- Machine Sessions APIs ---
  static String get startSession => "$baseUrl/machine-sessions/start";
  static String get getMySessionHistory => "$baseUrl/machine-sessions/my";

  static String get getProducts => "$baseUrl/products/marketplace";

  static String getSessionDetail(String id) => "$baseUrl/machine-sessions/$id";
  static String completeSession(String id) => "$baseUrl/machine-sessions/$id/complete";
  static String confirmSession(String id) => "$baseUrl/machine-sessions/$id/confirm";

  static String getSessionStatus(String id) => "$baseUrl/users/access-tokens/$id";

  static String get createOrder => "$baseUrl/orders";
  static String get getMyOrders => "$baseUrl/orders/my";
  static String getOrderById(String id) => "$baseUrl/orders/$id";

  // --- Cart Endpoints ---
  static String get getCart => "$baseUrl/cart";
  static String get clearCart => "$baseUrl/cart"; // DELETE
  static String get addToCart => "$baseUrl/cart/items"; // POST
  static String updateCartItem(int id) => "$baseUrl/cart/items/$id"; // PATCH
  static String removeCartItem(int id) => "$baseUrl/cart/items/$id"; // DELETE
  static String get checkoutCart => "$baseUrl/cart/checkout"; // POST

  // --- Lainnya ---
  static String get getMyProfile => "$baseUrl/users/me";
  static String get getMyQr => "$baseUrl/users/me/qr";
  static String get getMyWallet => "$baseUrl/wallets/me";
  static String get getTransactions => "$baseUrl/wallets/me/transactions";

  static String getNearestMachines(double latitude, double longitude) =>
      "$baseUrl/machines/nearest?latitude=$latitude&longitude=$longitude";

  // Variabel untuk menyimpan token setelah login
  static String? userToken;

  static Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (userToken != null) 'Authorization': 'Bearer $userToken',
    };
  }
}