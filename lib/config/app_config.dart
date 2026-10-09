// USE THIS FILE TO STORE LINKS / BUCKET NAMES AND OTHER NON SENSTIVE FREQUENTLY REPEATED INFO
class AppConfig {
  AppConfig._();

  // Backend API
  static const String backendBaseUrl =
      'http://localhost:5000';

//This is here so that its easy to switch to the correct url. Localhost urls = DaChoco Local testing
  static const String quickSwapUrl = 
      'http://26.223.171.250:80';

  // Supabase
  static const String supabaseUrl =
      'https://zeedqugdftxrbscmhgmq.supabase.co';

  // Supabase Storage For Icons
  static const String supabaseIconBucketName =
      'user-icons';

  static String get supabaseBucketBaseUrl =>
      '$supabaseUrl/storage/v1/object/public/$supabaseIconBucketName';
}
