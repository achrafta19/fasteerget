# BLS Vanguard — Command Reference / مرجع الأوامر

كل الأوامر المستخدمة في المشروع، مجمّعة في مكان واحد.
All commands used across the project, grouped in one place.

---

## 1) التشغيل والبناء — Setup & Build

```bash
# تثبيت الحزم (من جذر المشروع)
npm install

# تشغيل وضع التطوير
npm run dev

# فحص الأنواع + بناء الإنتاج
npx next typegen
npm exec tsc -- --noEmit --pretty false
npm run build

# تشغيل نسخة الإنتاج
npm run start

# فحص الجودة
npm run lint
npm run typecheck
```

---

## 1.b) فحص جاهزية التثبيت — Deployment preflight

```bash
bash deploy/preflight.sh          # فحص شامل: نظام، ملفات، env، قاعدة، بناء، منفذ
bash deploy/env-generator.sh .env # توليد .env بأسرار عشوائية (صلاحيات 600)
# الدليل التفصيلي بمراحل ومعايير نجاح: deploy/STEP-BY-STEP.md
bash deploy/install.sh /opt/vanguard   # تثبيت VPS تلقائي (Node+PG+PM2+Nginx+TLS)
docker compose up -d --build           # نشر Docker (db + app + ticker)
```

---

## 2) قاعدة البيانات — Database (Drizzle + PostgreSQL)

```bash
# تطبيق مخطط Drizzle على القاعدة (بدون ملفات migration)
npx drizzle-kit push

# توليد ملفات migration (للإنتاج)
npx drizzle-kit generate
npx drizzle-kit migrate

# فتح psql على قاعدة التطبيق
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db

# استعلامات فحص سريعة
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -c "select now(), current_setting('TimeZone')"
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc "select id,name,status,total_runs from automation_sessions order by id"
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc "select outcome, count(*) from automation_runs group by outcome"
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc "select count(*) filter (where status='pending') pending, count(*) total from captcha_challenges"
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc "select id,username,display_name,role,is_active from operators order by id"
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc "select id,full_name,passport_number from applicants order by id"
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc "select id,status,bls_confirmation_code,captured_date from appointments order by id"

# إعادة تسليح كل الجلسات (بعد دورة عالقة)
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc "update automation_sessions set status='armed'"

# تحرير جلسة عالقة في حالة running
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc "update automation_sessions set status='armed', last_run_at=null where status='running'"

# حذف بيانات التجربة (المستخدمون والملفات والمواعيد والجلسات)
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -c "truncate table captcha_challenges, automation_runs, automation_sessions, notifications, appointments, applicants, audit_logs, auth_sessions, operators restart identity cascade"

# حذف كامل للمخطط (إعادة من الصفر) — احذر
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -c "drop schema public cascade; create schema public"
```

> بعد `truncate` أعد تشغيل السيرفر: يتم إعادة زرع البيانات التجريبية تلقائيًا عند أول طلب.

---

## 3) متغيرات البيئة — Environment

```bash
# نسخ قالب الإعدادات
cp .env.example .env

# قاعدة البيانات (موجودة مسبقًا في الساندبوكس)
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5432/app_db

# ===== موصّل BLS =====
# simulation = محاكاة محلية (الافتراضي) | live = اتصال حقيقي بحسابك
BLS_MODE=live
BLS_API_BASE_URL=https://bls.dz
BLS_LOGIN_PATH=/api/auth/login
BLS_SLOTS_PATH=/api/appointment/slots
BLS_BOOK_PATH=/api/appointment/book

# المصادقة: إما كوكي جلسة أو بريد + كلمة مرور
BLS_SESSION_COOKIE=<cookie>
BLS_ACCOUNT_EMAIL=<email>
BLS_ACCOUNT_PASSWORD=<password>
BLS_API_KEY=<api-key>
BLS_CENTER_ID=<center-id>
BLS_TIMEOUT_MS=12000
BLS_USER_AGENT=<user-agent>

# ===== بوابة الكابتشا البشرية =====
BLS_CAPTCHA_TIMEOUT_MS=120000

# ===== سيرفر الحجز / التطبيق المكتبي =====
ENGINE_SECRET=<shared-secret>
ENGINE_OPERATOR_ID=1
```

---

## 4) الاختبار عبر API — API Smoke Tests

```bash
# عنوان الموقع (استبدله برابط المعاينة الحالي)
BASE=https://3000-xxxx.e2b.app

# الصحة
curl -sS $BASE/api/health

# تسجيل الدخول وحفظ الكوكي
C=$(curl -sS -i -X POST $BASE/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"blsvisa","password":"YOUR_PASSWORD"}' \
  | grep -i '^set-cookie' | sed 's/.*session=//;s/;.*//' | tr -d '\r')

# من أنا
curl -sS $BASE/api/auth/me -b "bls_vanguard_session=$C"

# الإحصائيات ونوافذ الفتح
curl -sS $BASE/api/stats -b "bls_vanguard_session=$C"

# حالة الربط + قالب الإعدادات
curl -sS $BASE/api/integration -b "bls_vanguard_session=$C"

# اختبار اتصال (drill) وقياس الزمن
curl -sS -X POST $BASE/api/integration -b "bls_vanguard_session=$C"

# الملفات والمواعيد والإشعارات
curl -sS $BASE/api/applicants -b "bls_vanguard_session=$C"
curl -sS $BASE/api/appointments -b "bls_vanguard_session=$C"
curl -sS $BASE/api/notifications -b "bls_vanguard_session=$C"

# إنشاء ملف متقدم
curl -sS -X POST $BASE/api/applicants -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' \
  -d '{"fullName":"Test Applicant","fullNameAr":"مترشح تجريبي","passportNumber":"DZ0001234","nationalId":"199001123456","phone":"+213555000000","email":"test@example.dz","dateOfBirth":"1990-01-01","placeOfBirth":"Alger","gender":"male","maritalStatus":"single","profession":"Engineer","address":"Alger"}'

# إنشاء موعد
curl -sS -X POST $BASE/api/appointments -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' \
  -d '{"applicantId":1,"missionType":"tourist","city":"Algiers","center":"BLS Algiers Center","visaCategory":"Schengen Short Stay (Type C)","priority":5}'

# تغيير حالة موعد / حذفه
curl -sS -X PATCH $BASE/api/appointments/1 -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' -d '{"status":"pending"}'
curl -sS -X DELETE $BASE/api/appointments/1 -b "bls_vanguard_session=$C"

# الجلسات الآلية: قراءة/إنشاء/تعديل/حذف
curl -sS $BASE/api/automation -b "bls_vanguard_session=$C"
curl -sS -X POST $BASE/api/automation -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Sentinel II","strategy":"aggressive","fridayAt16":true,"tuesdayAt17":true,"maxConcurrency":4,"targetAppointmentIds":[1,2]}'
curl -sS -X PATCH $BASE/api/automation/1 -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' -d '{"status":"armed"}'
curl -sS -X DELETE $BASE/api/automation/1 -b "bls_vanguard_session=$C"

# تشغيل دورة يدويًا (+ force لتجاوز عدّاد النافذة)
curl -sS -X POST $BASE/api/automation/1 -b "bls_vanguard_session=$C"
curl -sS -X POST "$BASE/api/automation/1?force=1" -b "bls_vanguard_session=$C"
```

---

## 5) سيرفر الحجز الآلي — Booking Server

```bash
# حالة السيرفر وجلساته
curl -sS $BASE/api/engine/tick -b "bls_vanguard_session=$C"

# نبضة واحدة (تحترم نافذة الجمعة 16:00 / الثلاثاء 17:00 بتوقيت الجزائر)
curl -sS -X POST $BASE/api/engine/tick -b "bls_vanguard_session=$C"

# تجاوز العدّاد (تدريب فقط)
curl -sS -X POST "$BASE/api/engine/tick?force=1" -b "bls_vanguard_session=$C"

# نبضة بسر مشترك (للتطبيق المكتبي أو cron بدون جلسة)
curl -sS -X POST -H "x-engine-secret: $ENGINE_SECRET" \
  "http://localhost:3000/api/engine/tick?operatorId=1"

# cron كل دقيقة على VPS
* * * * * curl -s -X POST -H "x-engine-secret: $ENGINE_SECRET" \
  "http://localhost:3000/api/engine/tick?operatorId=1" > /dev/null
```

---

## 6) بوابة الكابتشا البشرية — Human CAPTCHA Gate

```bash
# عرض التحديات المعلّقة
curl -sS $BASE/api/captcha -b "bls_vanguard_session=$C"

# حل تحدي (الجواب من إنسان فقط — لا OCR ولا تجاوز)
curl -sS -X PATCH $BASE/api/captcha/1 -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' -d '{"answer":"15"}'

# رفض التحدي (يتخطى الموعد)
curl -sS -X DELETE $BASE/api/captcha/1 -b "bls_vanguard_session=$C"
```

> في وضع `simulation` يكون التحدي حسابيًا ويُتحقق من الجواب.
> في وضع `live` يُمرَّر جواب الإنسان إلى البوابة كـ `captchaToken`.

---

## 7) تطبيق سطح المكتب — Electron Desktop

```bash
cd desktop
npm install

# تشغيل الغلاف المكتبي على السيرفر المحلي
VANGUARD_URL=http://localhost:3000 npm start

# فاصل النبض (افتراضي 20000ms)
VANGUARD_TICK_MS=15000 VANGUARD_URL=http://localhost:3000 npm start

# بناء ملف توزيع (electron-builder)
npm run dist

# بناء نسخة معطّلة من الحزم (بدون تثبيت Electron في الجذر)
cd .. && npx next build && npm run start
```

---

## 8) التشغيل الكامل من الصفر — Full Boot Sequence

```bash
# 1) الحزم
npm install

# 2) القاعدة
npx drizzle-kit push

# 3) الإعدادات
cp .env.example .env    # ثم عدّل BLS_MODE والمصادقة

# 4) التحقق والبناء
npx next typegen
npm exec tsc -- --noEmit --pretty false
npm run build

# 5) التشغيل
npm run start           # http://localhost:3000

# 6) السطح المكتبي (نافذة منفصلة)
cd desktop && npm install && VANGUARD_URL=http://localhost:3000 npm start
```

---

## 9) التحقق النهائي قبل التسليم — Pre-Delivery Validation

```bash
bash -lc 'set -o pipefail; npx next typegen 2>&1 | tee /tmp/next-typegen.log'
bash -lc 'set -o pipefail; npm exec tsc -- --noEmit --pretty false 2>&1 | tee /tmp/tsc.log'
bash -lc 'set -o pipefail; npm run build 2>&1 | tee /tmp/build.log'
```

عند الفشل: `cat /tmp/next-typegen.log` أو `cat /tmp/tsc.log` أو `cat /tmp/build.log`.

---

## 9.a) استمارة الحجز الكاملة — Full booking form

```bash
# عدد الحقول والأقسام
curl -sS $BASE/api/booking -b "bls_vanguard_session=$C"
# -> {"fields":[...57 names...],"sections":9}

# تقديم طلب كامل (مثال مصغّر)
curl -sS -X POST $BASE/api/booking -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' -d '{
    "applicantId":1,"missionType":"tourist","city":"Oran",
    "center":"BLS Oran Center","visaCategory":"Schengen Short Stay (Type C)",
    "stayDurationDays":21,"preferredDateFrom":"2026-05-01","priority":3,
    "biometricsRequired":true,"accompanyingSpouse":true,"minorsCount":2,
    "hotelName":"Hotel El Djazair","flightNumber":"AH1510",
    "airportArrival":"Oran Ahmed Ben Bella","hasTravelInsurance":true,
    "insuranceCompany":"CAAT","monthlyIncomeDzd":185000,"fundingSource":"self"
  }'

# فحص التفاصيل المحفوظة
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc \
  "select id,city,center,stay_duration_days,minors_count,hotel_name,insurance_company from appointments order by id desc limit 5"
```

> الحقول الإلزامية: `city`, `center`, `visaCategory`, `missionType`, `fullName`, `passportNumber`, `dateOfBirth`, `phone`, `email`, `address`.

---

## 9.c) سياسة حدود المواعيد — Booking policy

```bash
# قراءة السياسة + العدادات الحية
curl -sS $BASE/api/booking-policy -b "bls_vanguard_session=$C"

# تحديث الحدود (admin فقط)
curl -sS -X PATCH $BASE/api/booking-policy -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' \
  -d '{"oneBookingPerPassport":true,"maxActivePerPassport":1,
       "maxActivePerClient":5,"maxActiveWorkspace":200,
       "maxDailySubmissions":30,"enforceCaps":true}'

# تبديل إلى وضع التحذير بدل الرفض
curl -sS -X PATCH $BASE/api/booking-policy -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' -d '{"enforceCaps":false}'

# فحص الطلبات النشطة وتكرار الجوازات
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc \
  "select upper(a.passport_number) passport, count(*) active
   from appointments ap join applicants a on a.id=ap.applicant_id
   where ap.status in ('pending','searching','captured')
   group by 1 having count(*) > 1"

# سياسة قاعدة البيانات
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc \
  "select one_booking_per_passport, max_active_per_passport, max_active_per_client,
          max_active_workspace, max_daily_submissions, enforce_caps
   from booking_policies limit 1"
```

> رموز الرفض: `duplicate_booking` · `passport_cap` · `client_cap` · `workspace_cap` · `daily_cap`

---

## 9.b) أكواد العملاء — Client access codes

```bash
# إصدار رمز (يتطلب صلاحية admin)
curl -sS -X POST $BASE/api/access-codes -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' \
  -d '{"label":"عميل تجريبي","clientName":"Karim B","maxUses":1,"expiresInHours":48,"count":3}'

# دخول العميل بالرمز (5 أرقام)
curl -sS -X POST $BASE/api/auth/code-login -H 'Content-Type: application/json' \
  -d '{"code":"29001"}'

# قائمة الأكواد / تعطيل / حذف
curl -sS $BASE/api/access-codes -b "bls_vanguard_session=$C"
curl -sS -X PATCH $BASE/api/access-codes -H 'x-code-id: 1' -b "bls_vanguard_session=$C" \
  -H 'Content-Type: application/json' -d '{"isActive":false}'
curl -sS -X DELETE $BASE/api/access-codes -H 'x-code-id: 1' -b "bls_vanguard_session=$C"

# فحص الأكواد في القاعدة
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -tc \
  "select id,code,label,max_uses,used_count,is_active,expires_at from access_codes order by id desc limit 10"
```

---

## 9.d) فحص جاهزية الإطلاق — Launch preflight

```bash
# التقرير الكامل (يتطلب جلسة مشغّل)
curl -sS $BASE/api/launch/preflight -b "bls_vanguard_session=$C"

#出厂 شرط: تعيين كلمة مرور المالك قبل أول تشغيل
SEED_OWNER_PASSWORD='ضع_كلمة_مرور_قوية_هنا'   # في .env
```

| المتغير | مطلوب للإنتاج |
|---|---|
| `DATABASE_URL` | ✅ |
| `SEED_OWNER_PASSWORD` | اختياري (يُولَّد تلقائيًا) |
| `ENGINE_SECRET` | ✅ `openssl rand -hex 24` |
| `FORCE_HTTPS=true` | ✅ بعد تفعيل TLS |
| `BLS_MODE=live` | للحجز الفعلي |

---

## 10) سجل دخول جاهز — Credentials

| الدور | المستخدم | كلمة المرور |
|---|---|---|
| **المالك** | **`blsvisa`** | `SEED_OWNER_PASSWORD` أو المولَّدة عند أول تشغيل |

> **لا حسابات تجريبية.** الحسابات تُنشأ من `Settings → Operators` أو `Codes`.

### تغيير كلمة المرور من الطرفية

```bash
# توليد تجزئة scrypt لكلمة مرور جديدة
NEW_HASH=$(node -e '
const {randomBytes,scryptSync}=require("node:crypto");
const pw=process.argv[1];
const salt=randomBytes(16);
const d=scryptSync(pw.normalize("NFKC"),salt,64);
process.stdout.write("scrypt$"+salt.toString("hex")+"$"+d.toString("hex"));
' 'كلمة-المرور-الجديدة')

# تطبيقها على المستخدم
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db   -c "update operators set password_hash='$NEW_HASH', updated_at=now() where username='blsvisa'"

# إبطال كل الجلسات السارية
psql "$DATABASE_URL"   # sandbox example: postgresql://postgres:postgres@127.0.0.1:5432/app_db -c "delete from auth_sessions"
```

> حساب `blsvisa` يُنشأ تلقائيًا في أي قاعدة جديدة عبر `src/lib/seed.ts`.

تجزئة كلمة المرور: **scrypt** (مع ترقية تلقائية للهاشات القديمة SHA-256 عند أول دخول).
حد المحاولات: **8 محاولات / 10 دقائق لكل IP + مستخدم**.

---

## 11) ملاحظات تشغيلية — Operational Notes

- نوافذ BLS: **الجمعة 16:00** و**الثلاثاء 17:00** بتوقيت **Africa/Algiers** (السيرفر قد يعمل UTC — الحساب داخلي ومضبوط).
- النافذة الفعلية للتنفيذ: الجمعة 15:55–16:25، الثلاثاء 16:55–17:25.
- المهلة الافتراضية للكابتشا: **120 ثانية** (`BLS_CAPTCHA_TIMEOUT_MS`).
- حد التزامن: `maxConcurrency` من 1 إلى 16، الأهداف تُنفَّذ بدفعات حسب **priority** (1 = الأعلى).
- حماية من الحجز المزدوج: قفل ذري + استرجاع الجلسة العالقة بعد **10 دقائق**.
- إن ظهرت جلسة `running` بدون نشاط: استخدم أمر SQL في القسم (2) لإعادة تسليحها.

---

⚠️ **تنبيه قانوني:** الأتمتة على بوابة BLS قد تخالف شروط استخدامها وقد تؤدي إلى حجب الحساب. استخدم حسابك الخاص فقط، بمعدلات بشرية، وبقرار نهائي بشري — والكابتشا تُحل بشر فقط.
