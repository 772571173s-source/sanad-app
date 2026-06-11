# إعداد بيئة تشغيل Android

## المتطلبات
- Flutter SDK (متضمن مع المشروع)
- Android SDK — platform-tools (لـ adb)
- هاتف Android مع تفعيل **Developer Options** و **USB Debugging**

## التشغيل السريع

### عبر VS Code
من قائمة Terminal → Run Task → اختر:
| المهمة | الوصف |
|---|---|
| `Flutter Run Android` | تشغيل التطبيق على أول هاتف Android متصل |
| `Flutter Clean Run` | تنظيف كامل + إعادة بناء + تشغيل |
| `Flutter Hot Restart` | إعادة تشغيل ساخن (أسرع من rebuild) |
| `Flutter Analyze` | تحليل الكود للبحث عن أخطاء وتحذيرات |
| `Kill Flutter Daemon` | قتل daemon (حل مشاكل الاتصال) |

### عبر PowerShell

```powershell
.\scripts\run_android.ps1             # تشغيل debug
.\scripts\run_android.ps1 -Release     # تشغيل release
.\scripts\run_android.ps1 -Profile    # تشغيل profile
.\scripts\clean_run.ps1               # تنظيف + تشغيل
.\scripts\restart_flutter.ps1         # إعادة تشغيل ADB + Flutter + تشغيل
```

### مباشر بدون سكربت
```powershell
flutter run
```
إذا كان هناك أكثر من جهاز متصل، سيطلب Flutter اختيار الجهاز يدويًا. للسكوت عن ذلك:
```powershell
flutter run -d $(flutter devices --machine | python -c "import sys,json; devices=json.load(sys.stdin); print([d['id'] for d in devices if d['targetPlatform']=='android-arm64'][0])")
```

## مشاكل ADB الشائعة

### 1. `adb: command not found`
**الحل:** أضف مسار platform-tools إلى PATH:
```powershell
$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"
```
أو استخدم السكربتات (`run_android.ps1`) — تبحث تلقائيًا عن adb في المسارات المعتادة.

### 2. `no devices/emulators found`
**الأسباب:**
- USB Debugging غير مفعل في Developer Options
- الهاتف في وضع "شحن فقط" — غيّر إلى **Transfer files (MTP)**
- كابل USB لا يدعم نقل البيانات

**الحل:**
```powershell
adb kill-server
adb start-server
adb devices
```
إذا لم يظهر الهاتف: افصل الكابل وأعد التوصيل، ثم كرر `adb devices`.

### 3. Flutter daemon لا يستجيب
**الحل:**
```powershell
# قتل daemon
Get-Process -Name "flutter*","dart*" -ErrorAction SilentlyContinue | Stop-Process -Force
# أو استخدم السكربت المخصص
.\scripts\restart_flutter.ps1
```

### 4. خطأ Gradle / Build بعد تحديث Android SDK
**الحل:**
```powershell
.\scripts\clean_run.ps1
```

## إعادة تثبيت نظيف (Clean Install)
```powershell
# 1. احذف التطبيق من الهاتف يدويًا
# 2. نظف المشروع
flutter clean
# 3. أعد التثبيت
.\scripts\run_android.ps1
```

## Hot Reload و Hot Restart

| الأمر | الوصف | المدة التقريبية |
|---|---|---|
| `r` في terminal | Hot reload — أسرع تحديث لتغييرات UI | < 1 ثانية |
| `R` في terminal | Hot restart — يعيد تشغيل التطبيق | 1-3 ثوانٍ |
| Ctrl+F5 (VS Code) | Hot restart | 1-3 ثوانٍ |
| F5 (VS Code) | Debug run كامل | 30-60 ثانية |

**نصيحة:** استخدم hot reload (`r`) للتغييرات السريعة، و hot restart (`R`) عند تغيير State أو المتغيرات العامة.

## نصائح لتسريع البناء

1. **استخدم --no-tree-shake-icons لل debug:**
   ```powershell
   flutter run -d <device> --no-tree-shake-icons
   ```
2. **استخدم Gradle daemon (يشتغل تلقائيًا بعد أول build):**
   ```powershell
   # التحقق من حالة daemon
   cd android && .\gradlew --status
   ```
3. **إذا كان البطء من الجهاز:** استخدم `--profile` mode (أسرع من debug).
4. **تجنب `flutter clean` المتكرر** — إلا إذا حدث خطأ في build.

## هيكل أدلة التشغيل

```
sanad_app/
├── scripts/
│   ├── run_android.ps1        ← تشغيل على أول جهاز Android
│   ├── clean_run.ps1          ← تنظيف + تشغيل
│   └── restart_flutter.ps1    ← إعادة تشغيل ADB + daemon + تشغيل
├── .vscode/
│   ├── tasks.json             ← مهام VS Code (تشغيل، تنظيف، تحليل)
│   └── launch.json            ← إعدادات التشغيل (debug, release, profile)
└── docs/guidelines/
    └── ANDROID_DEV_SETUP.md   ← هذا الملف
```
