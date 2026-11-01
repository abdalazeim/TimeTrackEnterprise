import 'package:flutter/widgets.dart';

import '../../features/gateway/domain/entities/offline_scan.dart';

/// Small built-in dictionary for the starter app's shared authentication and
/// example screens. Add an ARB-backed localization package when the product
/// grows beyond these reusable screens.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context));

  bool get isArabic => locale.languageCode == 'ar';

  String get languageSwitch => isArabic ? 'English' : 'العربية';
  String hello(String name) => isArabic ? 'أهلًا، $name' : 'Hello, $name';
  String get loginTitle => isArabic ? 'تسجيل الدخول' : 'Sign in';
  String get appTagline => isArabic
      ? 'قالب تطبيق عام قابل للتخصيص لمشروعك.'
      : 'A reusable starting point for your next application.';
  String get loginDescription => isArabic
      ? 'استخدم بيانات حسابك للمتابعة.'
      : 'Use your account details to continue.';
  String get username => isArabic ? 'اسم المستخدم' : 'Username';
  String get usernameHint =>
      isArabic ? 'أدخل اسم المستخدم' : 'Enter your username';
  String get usernameRequired =>
      isArabic ? 'اسم المستخدم مطلوب.' : 'Username is required.';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get passwordHint =>
      isArabic ? 'أدخل كلمة المرور' : 'Enter your password';
  String get passwordRequired =>
      isArabic ? 'كلمة المرور مطلوبة.' : 'Password is required.';
  String get showPassword => isArabic ? 'إظهار كلمة المرور' : 'Show password';
  String get hidePassword => isArabic ? 'إخفاء كلمة المرور' : 'Hide password';
  String get signIn => isArabic ? 'دخول' : 'Sign in';
  String get offlineHint => isArabic
      ? 'تُحفظ الجلسة بأمان على هذا الجهاز.'
      : 'Your session is stored securely on this device.';
  String get quickStart =>
      isArabic ? 'ابدأ من المثال' : 'Start with the sample';
  String get quickStartHint => isArabic
      ? 'استخدم السجلات التجريبية لربط وحدة جديدة بواجهة API.'
      : 'Use sample records to connect a feature to the API.';
  String get exampleRecords => isArabic ? 'سجلات المثال' : 'Sample records';
  String get exampleRecordsHint => isArabic
      ? 'إنشاء السجلات وتعديلها وحذفها عبر API'
      : 'Create, update, and delete records through the API';
  String get syncTitle =>
      isArabic ? 'حالة التخزين والمزامنة' : 'Storage and sync status';
  String get syncHint => isArabic
      ? 'ملخص الطابور المحلي وآخر اتصال بالخادم'
      : 'Local queue and last server connection';
  String get waiting => isArabic ? 'قيد الانتظار' : 'Waiting';
  String get attention => isArabic ? 'تحتاج انتباه' : 'Needs attention';
  String get savedRecords => isArabic ? 'سجلات محفوظة' : 'Cached records';
  String get deviceId => isArabic ? 'معرّف الجهاز' : 'Device ID';
  String get lastSync => isArabic ? 'آخر مزامنة' : 'Last sync';
  String get lastResult => isArabic ? 'آخر نتيجة' : 'Last result';
  String get neverSynced => isArabic ? 'لم تتم مزامنة بعد' : 'No sync yet';
  String get logout => isArabic ? 'تسجيل الخروج' : 'Sign out';
  String get logoutPrompt => isArabic
      ? 'سيتم حذف جلسة الدخول من هذا الجهاز. تبقى العمليات غير المرسلة في الطابور.'
      : 'This removes the session from this device. Unsent operations remain queued.';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get confirm => isArabic ? 'خروج' : 'Sign out';
  String get refresh => isArabic ? 'تحديث' : 'Refresh';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Try again';
  String get loading => isArabic ? 'جارٍ التحميل…' : 'Loading…';
  String get preparingSession =>
      isArabic ? 'جارٍ تجهيز الجلسة…' : 'Preparing your session…';
  String get startupHint => isArabic
      ? 'تأكد من الاتصال بالخادم عند تعذر استعادة الجلسة.'
      : 'Check the server connection if your session cannot be restored.';
  String get loadFailed =>
      isArabic ? 'تعذر تحميل البيانات' : 'Could not load data';
  String get noItems => isArabic ? 'لا توجد سجلات بعد' : 'No records yet';
  String get addItem => isArabic ? 'إضافة سجل' : 'Add record';
  String get editItem => isArabic ? 'تعديل السجل' : 'Edit record';
  String get deleteItem => isArabic ? 'حذف السجل' : 'Delete record';
  String get deletePrompt => isArabic
      ? 'هل تريد حذف هذا السجل؟ لا يمكن التراجع عن هذا الإجراء.'
      : 'Delete this record? This action cannot be undone.';
  String get name => isArabic ? 'الاسم' : 'Name';
  String get code => isArabic ? 'الرمز' : 'Code';
  String get description => isArabic ? 'الوصف' : 'Description';
  String get quantity => isArabic ? 'الكمية' : 'Quantity';
  String get save => isArabic ? 'حفظ' : 'Save';
  String get fieldRequired =>
      isArabic ? 'هذا الحقل مطلوب.' : 'This field is required.';
  String get quantityInvalid => isArabic
      ? 'أدخل عددًا صحيحًا غير سالب.'
      : 'Enter a non-negative whole number.';
  String lastSynced(DateTime? date) {
    if (date == null) return neverSynced;
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return isArabic
        ? '${date.year}/$month/$day $time'
        : '$month/$day/${date.year} $time';
  }

  // Attendance Gateway
  String get gateway => isArabic ? 'بوابة الحضور' : 'Attendance Gateway';
  String get gatewayTitle =>
      isArabic ? 'بوابة الحضور المحلية' : 'Local Attendance Gateway';
  String get gatewaySubtitle => isArabic
      ? 'تشغيل خادم HTTP محلي لربط تطبيق الحضور بشبكة الجهاز'
      : 'Run a local HTTP server to bridge attendance devices on your network';
  String get startServer => isArabic ? 'بدء الخادم' : 'Start Server';
  String get stopServer => isArabic ? 'إيقاف الخادم' : 'Stop Server';
  String get serverRunning =>
      isArabic ? 'الخادم قيد التشغيل' : 'Server is running';
  String get serverStopped => isArabic ? 'الخادم متوقف' : 'Server is stopped';
  String get serverAddress => isArabic ? 'عنوان الخادم' : 'Server Address';
  String get serverPort => isArabic ? 'المنفذ' : 'Port';
  String get deviceIp => isArabic ? 'عنوان IP للجهاز' : 'Device IP';
  String get networkUnavailable => isArabic
      ? 'لا يوجد اتصال Wi-Fi أو Ethernet نشط'
      : 'No active Wi-Fi or Ethernet connection';
  String get copyAddress => isArabic ? 'نسخ العنوان' : 'Copy Address';
  String get addressCopied => isArabic ? 'تم نسخ العنوان' : 'Address copied';
  String get gatewayScanner =>
      isArabic ? 'ماسح الباركود/QR' : 'Barcode/QR Scanner';
  String get gatewayScannerSetup => isArabic ? 'إعداد الماسح' : 'Scanner Setup';
  String get gatewayPortal => isArabic ? 'بوابة الربط' : 'Companion Portal';
  String get gatewayCompanion => isArabic ? 'مساعد الربط' : 'Gateway Companion';
  String get gatewayAbout => isArabic ? 'حول التطبيق' : 'About';
  String get autoStart => isArabic
      ? 'تشغيل تلقائي عند فتح التطبيق'
      : 'Start gateway when the app opens';
  String get keepAwake =>
      isArabic ? 'إبقاء الشاشة/الخدمة نشطة' : 'Keep service active';
  String get notificationChannel =>
      isArabic ? 'خدمة بوابة الحضور' : 'Attendance Gateway Service';
  String get serviceRunning => isArabic
      ? 'خدمة البوابة تعمل في الخلفية'
      : 'Gateway service is running in background';
  String get openCompanion => isArabic ? 'فتح المساعد' : 'Open Companion';
  String get pairWithDesktop => isArabic
      ? 'ربط مع تطبيق الحضور على سطح المكتب'
      : 'Pair with Desktop Attendance App';
  String get instructions =>
      isArabic ? 'تعليمات الاستخدام' : 'Usage Instructions';
  String get instructionsText => isArabic
      ? '1. صِل الجهازين بالشبكة المحلية نفسها عبر Wi-Fi أو Ethernet\n2. شغّل الخادم على هذا الجهاز\n3. أدخل عنوان الخادم في تطبيق سطح المكتب'
      : '1. Connect both devices to the same Wi-Fi or Ethernet LAN\n2. Start the server on this device\n3. Enter the server address in the desktop app';

  // Gateway — live status and settings
  String get gatewayStatus => isArabic ? 'حالة البوابة' : 'Gateway status';
  String get gatewayStarting =>
      isArabic ? 'جارٍ تشغيل الخادم…' : 'Starting server…';
  String get gatewayRunningHint => isArabic
      ? 'جاهز لاستقبال طلبات سطح المكتب ورسائل SMS'
      : 'Ready for desktop requests and SMS delivery';
  String get gatewayStoppedHint => isArabic
      ? 'شغّل الخادم ليتمكن تطبيق سطح المكتب من الاتصال'
      : 'Start the server so the desktop app can connect';
  String get pendingScans => isArabic ? 'مسحات معلّقة' : 'Pending scans';
  String get receivedScans => isArabic ? 'مسحات مستلمة' : 'Received scans';
  String get offlineToday => isArabic ? 'حضور اليوم' : 'Today attendance';
  String get offlinePending =>
      isArabic ? 'بانتظار المزامنة' : 'Waiting to sync';
  String get pairingCode => isArabic ? 'رمز الربط' : 'Pairing code';
  String get apiKey => isArabic ? 'مفتاح API' : 'API key';
  String get showSecret => isArabic ? 'إظهار' : 'Show';
  String get hideSecret => isArabic ? 'إخفاء' : 'Hide';
  String get regenerate => isArabic ? 'توليد جديد' : 'Regenerate';
  String get regenerateKeyPrompt => isArabic
      ? 'سيؤدي توليد مفتاح جديد إلى قطع اتصال تطبيق سطح المكتب حتى يعيد الربط. هل تريد المتابعة؟'
      : 'A new key disconnects the desktop app until it pairs again. Continue?';
  String get regeneratePinPrompt => isArabic
      ? 'سيصبح رمز الربط الحالي غير صالح. هل تريد توليد رمز جديد؟'
      : 'The current pairing code will stop working. Generate a new one?';
  String get pairingEnabled => isArabic ? 'السماح بالربط' : 'Allow pairing';
  String get pairingDisabled => isArabic ? 'الربط معطّل' : 'Pairing disabled';
  String get pairingHint => isArabic
      ? 'أدخل هذا الرمز في تطبيق سطح المكتب لربط البوابة.'
      : 'Enter this code in the desktop app to pair the gateway.';
  String get apiKeyHint => isArabic
      ? 'يُرسل في الترويسة X-Api-Key مع كل طلب.'
      : 'Sent as the X-Api-Key header with every request.';
  String get portLabel => isArabic ? 'منفذ الخادم' : 'Server port';
  String get portHint => isArabic ? '1024 – 65535' : '1024 – 65535';
  String get invalidPort => isArabic
      ? 'أدخل منفذًا بين 1024 و65535.'
      : 'Enter a port between 1024 and 65535.';
  String get invalidPin => isArabic
      ? 'يجب أن يتكوّن رمز الربط من أربعة أرقام.'
      : 'The pairing code must contain exactly four digits.';
  String get invalidApiKey => isArabic
      ? 'يجب أن يتكوّن مفتاح API من 8 إلى 128 حرفًا.'
      : 'The API key must contain 8 to 128 characters.';
  String get settingsSaved => isArabic ? 'تم حفظ الإعدادات' : 'Settings saved';
  String get restartServer => isArabic ? 'إعادة تشغيل' : 'Restart';
  String get startedMessage => isArabic ? 'تم تشغيل الخادم' : 'Server started';
  String get stoppedMessage => isArabic ? 'تم إيقاف الخادم' : 'Server stopped';
  String get restartedMessage =>
      isArabic ? 'تمت إعادة تشغيل الخادم' : 'Server restarted';
  String get queueCleared =>
      isArabic ? 'تم تفريغ قائمة المسحات' : 'Scan queue cleared';
  String get keyRegenerated =>
      isArabic ? 'تم توليد مفتاح API جديد' : 'New API key generated';
  String get pinRegenerated =>
      isArabic ? 'تم توليد رمز ربط جديد' : 'New pairing code generated';
  String get settings => isArabic ? 'الإعدادات' : 'Settings';
  String get gatewaySettings =>
      isArabic ? 'إعدادات البوابة' : 'Gateway settings';
  String get autoStartHint => isArabic
      ? 'تشغيل الخادم تلقائيًا عند فتح التطبيق'
      : 'Start the server automatically when the app opens';
  String get keepAwakeHint => isArabic
      ? 'منع إيقاف الخدمة أثناء العمل'
      : 'Prevent the service from sleeping while in use';
  String get scanQueue => isArabic ? 'قائمة المسحات' : 'Scan queue';
  String get clearQueue => isArabic ? 'تفريغ' : 'Clear';
  String get noScans => isArabic ? 'لا توجد مسحات بعد' : 'No scans yet';
  String get sharedNetworkHint => isArabic
      ? 'يجب أن يكون الهاتف والكمبيوتر على نفس شبكة Wi-Fi.'
      : 'The phone and desktop must be on the same Wi-Fi network.';
  String get pcConnected =>
      isArabic ? 'تم الاتصال بسطح المكتب' : 'Desktop connected';
  String get pcWaiting =>
      isArabic ? 'بانتظار سطح المكتب' : 'Waiting for desktop';
  String lastPcContact(String value) =>
      isArabic ? 'آخر اتصال: $value' : 'Last contact: $value';
  String get endpoints => isArabic ? 'نقاط النهاية' : 'Endpoints';
  String get endpointHealth => isArabic ? 'الحالة والفحص' : 'Status and health';
  String get endpointScans => isArabic ? 'قراءة المسحات' : 'Read scans';
  String get endpointPair =>
      isArabic ? 'تبادل رمز الربط' : 'Exchange pairing code';
  String get endpointSend => isArabic ? 'إرسال رسالة SMS' : 'Send an SMS';

  // Gateway — scanner
  String get scannerModeGateway =>
      isArabic ? 'مسح لسطح المكتب' : 'Desktop scans';
  String get scannerModeOffline =>
      isArabic ? 'حضور بدون اتصال' : 'Offline attendance';
  String get scannerGatewayHint => isArabic
      ? 'تظهر كل مسحة مباشرة لتطبيق سطح المكتب عبر /scans.'
      : 'Every scan appears immediately to the desktop app through /scans.';
  String get scannerOfflineHint => isArabic
      ? 'تُحفظ المسحات محليًا وتُزامن عند توفر الاتصال.'
      : 'Scans are stored locally and synced when the connection returns.';
  String get scannerManualHint =>
      isArabic ? 'أدخل الرمز يدويًا' : 'Enter the code manually';
  String get submit => isArabic ? 'إرسال' : 'Submit';
  String get scannerLastScan => isArabic ? 'آخر مسحة' : 'Last scan';
  String get scannerNoScan => isArabic
      ? 'وجّه الكاميرا إلى الباركود أو أدخل الرمز يدويًا.'
      : 'Point the camera at a barcode or enter the code manually.';
  String get scannerTorch => isArabic ? 'الفلاش' : 'Flashlight';
  String get scannerSwitchCamera =>
      isArabic ? 'تبديل الكاميرا' : 'Switch camera';
  String scannerQueued(int seq) => isArabic
      ? 'تمت إضافة المسحة إلى قائمة سطح المكتب (#$seq).'
      : 'Scan added to the desktop queue (#$seq).';
  String get scannerIgnored => isArabic
      ? 'تم تجاهل مسحة مكررة خلال 2.5 ثانية.'
      : 'A duplicate scan within 2.5 seconds was ignored.';
  String scannerOfflineQueued(String name, String status) => isArabic
      ? 'تم حفظ حضور $name: $status'
      : 'Saved attendance for $name: $status';
  String scannerOfflineStatus(String name, String status) =>
      isArabic ? '$name: $status' : '$name: $status';
  String get scannerNeedsSetup => isArabic
      ? 'اربط الماسح أولًا من إعداد الماسح.'
      : 'Connect the scanner from Scanner Setup first.';
  String get scannerNeedsStaff => isArabic
      ? 'سجّل الدخول كموظف من بوابة الربط لتفعيل الحضور بدون اتصال.'
      : 'Sign in as staff from the Companion Portal to enable offline attendance.';
  String get scannerNeedsRoster => isArabic
      ? 'لم يتم تنزيل قائمة الطلاب بعد. اضغط مزامنة.'
      : 'The student roster has not been downloaded yet. Tap Sync.';
  String get recentScans => isArabic ? 'أحدث المسحات' : 'Recent scans';
  String get syncNow => isArabic ? 'مزامنة الآن' : 'Sync now';
  String get syncing => isArabic ? 'جارٍ المزامنة…' : 'Syncing…';
  String get syncDone => isArabic ? 'تمت المزامنة بنجاح' : 'Sync completed';
  String get syncFailed => isArabic ? 'تعذرت المزامنة' : 'Sync failed';
  String get staffRequired => isArabic
      ? 'يلزم تسجيل دخول الموظف من بوابة الربط.'
      : 'Staff sign-in through the Companion Portal is required.';
  String get rosterVersionLabel =>
      isArabic ? 'إصدار القائمة' : 'Roster version';
  String get studentsCount => isArabic ? 'الطلاب' : 'Students';
  String get periodsCount => isArabic ? 'الحصص' : 'Periods';
  String get lastRosterSync =>
      isArabic ? 'آخر تنزيل للقائمة' : 'Roster downloaded';
  String get lastSyncLabel => isArabic ? 'آخر مزامنة' : 'Last sync';
  String get never => isArabic ? 'لم يحدث بعد' : 'Never';
  String scanCounter(int today, int pending) => isArabic
      ? 'اليوم: $today • بانتظار المزامنة: $pending'
      : 'Today: $today • Pending sync: $pending';
  String get offlineStatusLabel => isArabic ? 'الحالة' : 'Status';

  // Gateway — scanner setup and companion
  String get scannerSetupDescription => isArabic
      ? 'اطلب رمز تسجيل الجهاز المكوّن من 8 أرقام من لوحة تحكم الحضور، ثم اربط هذا الهاتف.'
      : 'Request the 8-digit device passcode from the attendance dashboard, then connect this phone.';
  String get serverAddressHint => isArabic
      ? 'مثال: http://192.168.1.20:8080'
      : 'e.g. http://192.168.1.20:8080';
  String get passcode => isArabic ? 'رمز الجهاز' : 'Device passcode';
  String get passcodeHint => isArabic ? '8 أرقام' : '8 digits';
  String get passcodeRequired => isArabic
      ? 'أدخل رمز الجهاز المكوّن من 8 أرقام.'
      : 'Enter the 8-digit device passcode.';
  String get invalidServer => isArabic
      ? 'أدخل عنوانًا صحيحًا. استخدم HTTPS للخوادم العامة وHTTP لشبكة Wi-Fi المحلية.'
      : 'Enter a valid address. Use HTTPS for public servers and HTTP for the local network.';
  String get connectScanner => isArabic ? 'ربط الماسح' : 'Connect scanner';
  String get connecting => isArabic ? 'جارٍ الاتصال…' : 'Connecting…';
  String get discoverServer => isArabic ? 'بحث تلقائي' : 'Auto-detect';
  String get discovering =>
      isArabic ? 'جارٍ البحث في الشبكة…' : 'Searching the network…';
  String get serverFound => isArabic ? 'تم العثور على الخادم' : 'Server found';
  String get serverNotFound =>
      isArabic ? 'لم يتم العثور على خادم' : 'No server found';
  String get scannerConnected =>
      isArabic ? 'تم ربط الماسح' : 'Scanner connected';
  String get scannerPending => isArabic
      ? 'بانتظار موافقة الإدارة على الجهاز'
      : 'Waiting for administrator approval';
  String get scannerBlocked => isArabic
      ? 'تم حظر هذا الجهاز. تواصل مع الإدارة.'
      : 'This device is blocked. Contact the administrator.';
  String get pairCodeLabel => isArabic ? 'رمز الموافقة' : 'Approval code';
  String get waitingApproval => isArabic
      ? 'اطلب من الإدارة الموافقة على الجهاز ثم اضغط تحديث.'
      : 'Ask the administrator to approve the device, then tap Refresh.';
  String get refreshStatus => isArabic ? 'تحديث الحالة' : 'Refresh status';
  String get disconnectScanner =>
      isArabic ? 'فصل الماسح' : 'Disconnect scanner';
  String get disconnectScannerPrompt => isArabic
      ? 'سيتم حذف جلسة الماسح من هذا الجهاز. تبقى المسحات المحفوظة في الطابور.'
      : 'The scanner session will be removed from this device. Saved scans stay queued.';
  String get deviceName => isArabic ? 'اسم الجهاز' : 'Device name';
  String get scannerLoginRequiredNote => isArabic
      ? 'يجب تسجيل الدخول كموظف في بوابة الربط للمزامنة وإرسال SMS.'
      : 'Sign in as staff in the Companion Portal to sync and send SMS.';
  String get companionStatus => isArabic ? 'حالة المساعد' : 'Companion status';
  String get companionDevice => isArabic ? 'جهاز الماسح' : 'Scanner device';
  String get companionUser => isArabic ? 'المستخدم' : 'User';
  String get companionSchool => isArabic ? 'المدرسة' : 'School';
  String get companionRole => isArabic ? 'الدور' : 'Role';
  String get companionServer => isArabic ? 'الخادم' : 'Server';
  String get approved => isArabic ? 'معتمد' : 'Approved';
  String get pendingApproval =>
      isArabic ? 'بانتظار الموافقة' : 'Pending approval';
  String get blocked => isArabic ? 'محظور' : 'Blocked';
  String get notConnected => isArabic ? 'غير متصل' : 'Not connected';
  String get companionNoSessionHint => isArabic
      ? 'لم يتم ربط الماسح بعد. ابدأ من إعداد الماسح لربط هذا الهاتف بالخادم.'
      : 'The scanner is not connected yet. Start with Scanner Setup to pair this phone.';
  String get openScannerSetup =>
      isArabic ? 'فتح إعداد الماسح' : 'Open Scanner Setup';
  String get syncOffline => isArabic ? 'مزامنة البيانات' : 'Sync data';
  String get deviceIdLabel => isArabic ? 'معرّف الجهاز' : 'Device ID';
  String get copy => isArabic ? 'نسخ' : 'Copy';
  String get copied => isArabic ? 'تم النسخ' : 'Copied';

  // Gateway — portal
  String get staffTab => isArabic ? 'موظف' : 'Staff';
  String get parentTab => isArabic ? 'ولي أمر' : 'Parent';
  String get staffLogin => isArabic ? 'دخول الموظفين' : 'Staff sign-in';
  String get parentLogin => isArabic ? 'دخول أولياء الأمور' : 'Parent sign-in';
  String get staffLoginDescription => isArabic
      ? 'أدخل عنوان الخادم ورمز الهاتف المكوّن من 8 أرقام.'
      : 'Enter the server address and the 8-digit phone code.';
  String get parentLoginDescription => isArabic
      ? 'أدخل عنوان الخادم ورمز الطالب المكوّن من 12 رقمًا.'
      : 'Enter the server address and the 12-digit child code.';
  String get staffCode => isArabic ? 'رمز الموظف' : 'Staff code';
  String get staffCodeHint => isArabic ? '8 أرقام' : '8 digits';
  String get childCode => isArabic ? 'رمز الطالب' : 'Child code';
  String get childCodeHint => isArabic ? '12 رقمًا' : '12 digits';
  String get invalidStaffCode => isArabic
      ? 'رمز الموظف يجب أن يتكوّن من 8 أرقام.'
      : 'The staff code must contain 8 digits.';
  String get invalidChildCode => isArabic
      ? 'رمز الطالب يجب أن يتكوّن من 12 رقمًا.'
      : 'The child code must contain 12 digits.';
  String get signingIn => isArabic ? 'جارٍ تسجيل الدخول…' : 'Signing in…';
  String get signOut => isArabic ? 'تسجيل الخروج' : 'Sign out';
  String get signOutPrompt => isArabic
      ? 'هل تريد تسجيل الخروج من بوابة الربط؟'
      : 'Sign out of the Companion Portal?';
  String get role => isArabic ? 'الدور' : 'Role';
  String get adminRole => isArabic ? 'مدير' : 'Administrator';
  String get employeeRole => isArabic ? 'موظف' : 'Employee';
  String get roleMismatch => isArabic
      ? 'الدور المحدد لا يطابق هذا الحساب.'
      : 'The selected role does not match this account.';
  String get invalidResponse => isArabic
      ? 'أعاد الخادم استجابة غير مكتملة.'
      : 'The server returned an incomplete response.';
  String get offlineError => isArabic
      ? 'تعذر الوصول إلى الخادم. تحقق من الشبكة والعنوان.'
      : 'The server is unreachable. Check the network and address.';
  String get sessionExpired => isArabic
      ? 'انتهت الجلسة. سجّل الدخول مرة أخرى.'
      : 'The session ended. Sign in again.';
  String get staffSignedIn =>
      isArabic ? 'تم تسجيل دخول الموظف' : 'Staff signed in';
  String get parentSignedIn =>
      isArabic ? 'تم تسجيل دخول ولي الأمر' : 'Parent signed in';
  String get portalSignedOut => isArabic ? 'تم تسجيل الخروج' : 'Signed out';
  String get teacherDashboard =>
      isArabic ? 'لوحة المتابعة' : 'Attendance dashboard';
  String get openDashboard => isArabic ? 'عرض لوحة المتابعة' : 'Open dashboard';
  String get parentChildren =>
      isArabic ? 'الأبناء المرتبطون' : 'Linked children';
  String get noChildren =>
      isArabic ? 'لا يوجد أبناء مرتبطون بعد.' : 'No linked children yet.';
  String get parentOverview => isArabic ? 'ملخص الحضور' : 'Attendance overview';
  String get attendance30 =>
      isArabic ? 'حضور آخر 30 يومًا' : 'Attendance — last 30 days';
  String get noAttendance =>
      isArabic ? 'لا توجد سجلات حضور' : 'No attendance records';
  String get noPortalData => isArabic ? 'لا توجد بيانات' : 'No data available';
  String get summary => isArabic ? 'الملخص' : 'Summary';
  String get details => isArabic ? 'التفاصيل' : 'Details';
  String get notifications => isArabic ? 'الإشعارات' : 'Notifications';
  String get noNotifications =>
      isArabic ? 'لا توجد إشعارات' : 'No notifications';
  String get markAllRead => isArabic ? 'تحديد الكل كمقروء' : 'Mark all as read';
  String get removeChild => isArabic ? 'إزالة' : 'Remove';
  String get removeChildPrompt => isArabic
      ? 'هل تريد إزالة هذا الطالب من هذا الجهاز؟'
      : 'Remove this child from this device?';
  String get selectChild => isArabic ? 'اختر طالبًا' : 'Select a child';
  String get profile => isArabic ? 'الحساب' : 'Account';
  String get usernameLabel => isArabic ? 'اسم المستخدم' : 'Username';
  String get schoolYear => isArabic ? 'العام الدراسي' : 'Academic year';
  String get dateLabel => isArabic ? 'التاريخ' : 'Date';

  // Gateway — SMS and misc
  String get sendTestSms => isArabic ? 'إرسال رسالة تجريبية' : 'Send test SMS';
  String get sendSms => isArabic ? 'إرسال SMS' : 'Send SMS';
  String get phoneNumber => isArabic ? 'رقم الهاتف' : 'Phone number';
  String get messageBody => isArabic ? 'نص الرسالة' : 'Message';
  String get phoneRequired =>
      isArabic ? 'أدخل رقم هاتف صحيحًا.' : 'Enter a valid phone number.';
  String get messageRequired =>
      isArabic ? 'أدخل نص الرسالة.' : 'Enter the message.';
  String get smsQueued =>
      isArabic ? 'تم تسليم الرسالة إلى نظام SMS' : 'SMS handed to the system';
  String get smsStaffRequired => isArabic
      ? 'سجّل الدخول كموظف أولًا لإرسال الرسائل.'
      : 'Sign in as staff before sending messages.';
  String get smsUnavailable => isArabic
      ? 'إرسال SMS متاح على أندرويد فقط.'
      : 'SMS sending is only available on Android.';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get send => isArabic ? 'إرسال' : 'Send';
  String get done => isArabic ? 'تم' : 'Done';
  String get ok => isArabic ? 'حسنًا' : 'OK';
  String get unknownError =>
      isArabic ? 'حدث خطأ غير متوقع.' : 'An unexpected error occurred.';
  String get gatewayVersion => isArabic ? 'إصدار البوابة' : 'Gateway version';
  String get protocolTitle =>
      isArabic ? 'بروتوكول الاتصال' : 'Communication protocol';
  String get aboutDescription => isArabic
      ? 'بوابة محلية تحوّل هذا الهاتف إلى جسر بين تطبيق سطح المكتب وأجهزة الحضور، وتدعم إرسال SMS والمسح بدون اتصال.'
      : 'A local gateway that turns this phone into a bridge between the desktop app and attendance devices, with SMS delivery and offline scanning.';
  String get licenseNote => isArabic
      ? 'مبني على بروتوكول تطبيق TimeTrack Enterprise Gateway 4.1.1.'
      : 'Built on the TimeTrack Enterprise Gateway 4.1.1 protocol.';

  /// Localised text for error/status codes produced by the gateway provider.
  String errorText(String? code) {
    switch (code) {
      case 'invalid_server':
        return invalidServer;
      case 'invalid_port':
        return invalidPort;
      case 'invalid_pin':
        return invalidPin;
      case 'invalid_key':
        return invalidApiKey;
      case 'invalid_code':
        return invalidStaffCode;
      case 'invalid_role':
      case 'role_mismatch':
        return roleMismatch;
      case 'invalid_response':
        return invalidResponse;
      case 'offline':
        return offlineError;
      case 'session_expired':
      case 'unauthorized':
        return sessionExpired;
      case 'staff_required':
      case 'no_session':
        return staffRequired;
      case 'scanner_required':
        return scannerNeedsSetup;
      case 'roster_required':
        return scannerNeedsRoster;
      case 'device_pending':
        return scannerPending;
      case 'device_blocked':
        return scannerBlocked;
      case 'settings_saved':
        return settingsSaved;
      case 'started':
        return startedMessage;
      case 'stopped':
        return stoppedMessage;
      case 'restarted':
        return restartedMessage;
      case 'queue_cleared':
        return queueCleared;
      case 'key_regenerated':
        return keyRegenerated;
      case 'pin_regenerated':
        return pinRegenerated;
      case 'pairing_enabled':
        return pairingEnabled;
      case 'pairing_disabled':
        return pairingDisabled;
      case 'sync_done':
        return syncDone;
      case 'sync_failed':
        return syncFailed;
      case 'scanner_connected':
        return scannerConnected;
      case 'scanner_disconnected':
        return disconnectScanner;
      case 'staff_signed_in':
        return staffSignedIn;
      case 'parent_signed_in':
        return parentSignedIn;
      case 'portal_signed_out':
        return portalSignedOut;
      case 'sms_queued':
        return smsQueued;
      default:
        return code ?? unknownError;
    }
  }

  /// Localised label for offline attendance statuses.
  String offlineStatus(String status) =>
      isArabic ? OfflineStatus.labelAr(status) : OfflineStatus.labelEn(status);
}
