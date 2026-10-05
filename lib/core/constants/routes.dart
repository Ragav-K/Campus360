/// Typed route paths + names. Kept flat and const so navigation is refactor-safe.
abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';

  // Tabs
  static const pulse = '/pulse';
  static const map = '/map';
  static const lostFound = '/lostfound';
  static const print = '/print';

  // Pulse
  static String pulseDetail(String id) => '/pulse/$id';

  // Map
  static String locationDetail(String id) => '/map/location/$id';
  static String navigate(String id) => '/map/navigate/$id';

  // Lost & Found
  static const reportLost = '/lostfound/report-lost';
  static const reportFound = '/lostfound/report-found';
  static const myReports = '/lostfound/mine';
  static String lostDetail(String id) => '/lostfound/lost/$id';
  static String foundDetail(String id) => '/lostfound/found/$id';
  static String matchDetail(String id) => '/lostfound/match/$id';
  static String claimDetail(String id) => '/lostfound/claim/$id';
  static String claimVerify(String id) => '/lostfound/claim/$id/verify';

  // Printout
  static const newPrintOrder = '/print/new';
  static const printHistory = '/print/history';
  static String printOrder(String id) => '/print/order/$id';
  static String printOtp(String id) => '/print/order/$id/otp';

  // Timetable & academic calendar
  static const timetable = '/timetable';

  // Common
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const activity = '/profile/activity';
  static const settings = '/settings';

  // Staff
  static const staffHome = '/staff';
  static const staffVerifyOtp = '/staff/verify-otp';
  static String staffOrder(String id) => '/staff/order/$id';

  // Admin
  static const adminHome = '/admin';
  static const adminPulse = '/admin/pulse';
  static const adminLocations = '/admin/locations';
  static const adminLostFound = '/admin/lostfound';
  static const adminShops = '/admin/shops';
  static const adminUsers = '/admin/users';
  static const adminAnalytics = '/admin/analytics';
  static const adminSurvey = '/admin/survey';

  static const tabs = [pulse, map, lostFound, print];
}
