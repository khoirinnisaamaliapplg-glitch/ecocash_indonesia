class ApiConfig {
  static const String baseUrl = "http://localhost:3000/api/v1";

  static const String login = "$baseUrl/auth/login";

  // --- Machine Sessions APIs ---
  static const String startSession = "$baseUrl/machine-sessions/start";
  static const String getMySessionHistory = "$baseUrl/machine-sessions/my";

  static const String getProducts = "$baseUrl/products/marketplace";

  static String getSessionDetail(String id) => "$baseUrl/machine-sessions/$id";
  static String completeSession(String id) =>
      "$baseUrl/machine-sessions/$id/complete";
  static String confirmSession(String id) =>
      "$baseUrl/machine-sessions/$id/confirm";
  // static String getMachineDetail(String id) {
  //   return "$baseUrl/machines/$id";
  // }

  // --- Lainnya ---
  static const String getMyQr = "$baseUrl/users/me/qr";
  static const String getMyWallet = "$baseUrl/wallets/me";
  static const String getTransactions = "$baseUrl/wallets/me/transactions";

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
