abstract final class Routes {
  // Public.
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const forbidden = '/forbidden';

  // Shell tabs.
  static const home = '/home';
  static const sermons = '/sermons';
  static const read = '/read';
  static const questions = '/questions';
  static const profile = '/profile';

  // User flows.
  static String sermon(String id) => '/sermons/$id';
  static const studio = '/studio';
  static String studioSubmit(String draftId) => '/studio/submit/$draftId';
  static const myRecordings = '/recordings';
  static String recording(String id) => '/recordings/$id';
  static String book(String id) => '/books/$id';
  static String bookReader(String id) => '/books/$id/read';
  static String article(String id) => '/articles/$id';
  static const askQuestion = '/questions/ask';
  static const myQuestions = '/questions/mine';
  static String question(String id) => '/questions/$id';
  static const notifications = '/notifications';
  static const editProfile = '/profile/edit';

  // Admin workspace.
  static const admin = '/admin';
  static const adminSermons = '/admin/sermons';
  static const adminSermonNew = '/admin/sermons/new';
  static String adminSermonEdit(String id) => '/admin/sermons/$id';
  static const adminReviews = '/admin/reviews';
  static String adminReview(String id) => '/admin/reviews/$id';
  static const adminBooks = '/admin/books';
  static const adminBookNew = '/admin/books/new';
  static String adminBookEdit(String id) => '/admin/books/$id';
  static const adminArticles = '/admin/articles';
  static const adminArticleNew = '/admin/articles/new';
  static String adminArticleEdit(String id) => '/admin/articles/$id';
  static const adminQuestions = '/admin/questions';
  static String adminQuestion(String id) => '/admin/questions/$id';

  static const publicPaths = {signIn, register, forgotPassword};
}
