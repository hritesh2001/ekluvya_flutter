import '../../data/models/signed_cookie_model.dart';

abstract class SignedCookieRepository {
  Future<SignedCookieModel> getSignedCookies();
}
