class ApiConfig {
  // ============================================================
  // BASE URL
  // ============================================================

  // LOCAL
  static const String baseUrl = 'http://localhost:3000/api/v1';

  // PRODUCTION
  // static const String baseUrl = 'https://api.ecocash.id/api/v1';

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  static String get login {
    return '$baseUrl/auth/login';
  }

  static String get register {
    return '$baseUrl/auth';
  }
  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  /// Auth required.
  /// Mengirim ulang email verifikasi.
  static String get sendEmailVerification {
    return '$baseUrl/auth/email-verification/send';
  }

  /// Public.
  /// Konfirmasi token dari link email.
  static String get confirmEmailVerification {
    return '$baseUrl/auth/email-verification/confirm';
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  /// Public.
  /// Request link reset password.
  static String get forgotPassword {
    return '$baseUrl/auth/forgot-password';
  }

  /// Public.
  /// Reset password menggunakan token email.
  static String get resetPassword {
    return '$baseUrl/auth/reset-password';
  }

  // ============================================================
  // USER
  // ============================================================

  static String get getUserProfile {
    return '$baseUrl/users/me';
  }

  static String get updateProfile {
    return '$baseUrl/users/me';
  }

  static String get getMyCarbon {
    return '$baseUrl/users/me/carbon';
  }

  // ============================================================
  // USER QR
  // ============================================================

  /// QR PERMANEN
  ///
  /// GET /users/me/credential-qr
  static String get getMyCredentialQr {
    return '$baseUrl/users/me/credential-qr';
  }

  /// Regenerate QR permanen.
  ///
  /// POST /users/me/credential-qr/regenerate
  ///
  /// QR lama akan direvoke.
  static String get regenerateMyCredentialQr {
    return '$baseUrl/users/me/credential-qr/regenerate';
  }

  /// QR dynamic lama.
  ///
  /// GET /users/me/qr
  ///
  /// Jangan digunakan oleh ScanPage permanen.
  static String get getMyDynamicQr {
    return '$baseUrl/users/me/qr';
  }

  // ============================================================
  // MACHINE
  // ============================================================

  static String getNearestMachines(double latitude, double longitude) {
    return '$baseUrl/machines/nearest'
        '?latitude=$latitude'
        '&longitude=$longitude';
  }

  static String getMachineById(int id) {
    return '$baseUrl/machines/$id';
  }

  // ============================================================
  // MACHINE SESSION
  // ============================================================

  static String get startSession {
    return '$baseUrl/machine-sessions/start';
  }

  /// Session milik user.
  ///
  /// Digunakan ScanPage untuk mendeteksi
  /// session baru setelah mesin membaca QR permanen.
  static String get getMySessionHistory {
    return '$baseUrl/machine-sessions/my';
  }

  static String getSessionDetail(String id) {
    return '$baseUrl/machine-sessions/$id';
  }

  static String completeSession(String id) {
    return '$baseUrl/machine-sessions/$id/complete';
  }

  static String confirmSession(String id) {
    return '$baseUrl/machine-sessions/$id/confirm';
  }
  // ============================================================
  // VOUCHERS
  // ============================================================

  /// GET /vouchers/available
  /// Voucher yang tersedia untuk user.
  static String get getAvailableVouchers {
    return '$baseUrl/vouchers/available';
  }

  /// GET /vouchers/:id
  static String getVoucherById(int id) {
    return '$baseUrl/vouchers/$id';
  }

  // ============================================================
  // LEGACY ACCESS TOKEN
  // ============================================================

  /// Hanya digunakan untuk dynamic QR lama.
  static String getAccessTokenStatus(String id) {
    return '$baseUrl/users/access-tokens/$id';
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  static String get getProducts {
    return '$baseUrl/products/marketplace';
  }

  // ============================================================
  // ORDERS
  // ============================================================

  static String get createOrder {
    return '$baseUrl/orders';
  }

  static String get getMyOrders {
    return '$baseUrl/orders/my';
  }

  static String getOrderById(String id) {
    return '$baseUrl/orders/$id';
  }

  // ============================================================
  // CART
  // ============================================================

  static String get getCart => '$baseUrl/cart';

  static String get clearCart => '$baseUrl/cart';

  static String get addCartItem => '$baseUrl/cart/items';

  static String updateCartItem(int id) => '$baseUrl/cart/items/$id';

  static String removeCartItem(int id) => '$baseUrl/cart/items/$id';

  static String get previewCart => '$baseUrl/cart/preview';

  static String get checkoutCart => '$baseUrl/cart/checkout';
  // ============================================================
  // WALLET
  // ============================================================

  static String get getMyWallet {
    return '$baseUrl/wallets/me';
  }

  static String get getTransactions {
    return '$baseUrl/wallets/me/transactions';
  }

  // ============================================================
  // WALLET TOP UP
  // ============================================================

  /// POST /wallets/topup
  static String get createTopUp {
    return '$baseUrl/wallets/topup';
  }

  /// GET /wallets/topup
  static String get getMyTopUps {
    return '$baseUrl/wallets/topup';
  }

  /// GET /wallets/topup/:id
  static String getTopUpById(int id) {
    return '$baseUrl/wallets/topup/$id';
  }

  /// POST /wallets/topup/:id/mock-pay
  /// HANYA untuk local development
  static String mockPayTopUp(int id) {
    return '$baseUrl/wallets/topup/$id/mock-pay';
  }

  /// POST /wallets/topup/:id/check-status
  static String checkTopUpStatus(int id) {
    return '$baseUrl/wallets/topup/$id/check-status';
  }
  // ============================================================
  // CHARITY & DONATION
  // ============================================================

  static String get getPublicCharities {
    return '$baseUrl/charities/public';
  }

  static String get getMyDonations {
    return '$baseUrl/donations/me';
  }

  static String getCharityById(int id) {
    return '$baseUrl/charities/$id';
  }

  static String donateToCharity(int id) {
    return '$baseUrl/charities/$id/donate';
  }
  // ============================================================
  // AUTH TOKEN
  // ============================================================

  static String? userToken;

  /// Simpan JWT setelah login berhasil.
  static void setToken(String token) {
    userToken = token
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();
  }

  /// Hapus token ketika logout.
  static void clearToken() {
    userToken = null;
  }

  static bool get hasToken {
    return userToken != null && userToken!.trim().isNotEmpty;
  }

  // ============================================================
  // HEADERS
  // ============================================================

  static Map<String, String> get headers {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',

      if (hasToken) 'Authorization': 'Bearer ${userToken!.trim()}',
    };
  }
}
