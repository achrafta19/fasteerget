# BLS Vanguard

**Automated Schengen appointment capture console — BLS International Algeria.**
منصة أتمتة وحجز مواعيد تأشيرة إسبانيا للجزائريين، مع بوابة تحقق بشري للكابتشا.

---

## 🔑 الدخول

| الدور | المستخدم | كلمة المرور |
|---|---|---|
| **المالك** | **`blsvisa`** | من `SEED_OWNER_PASSWORD` — أو **مولَّدة عشوائية تُطبع مرة واحدة في سجل الخادم** |

> **لا توجد أي بيانات دخول افتراضية في هذا البناء.** عند أول تشغيل ينشئ النظام حساب
> `blsvisa` فقط. إن تركت `SEED_OWNER_PASSWORD` فارغًا، تُولَّد كلمة مرور قوية
> وتُطبع **مرة واحدة** في سجل الخادم:

```
+==========================================================+
|  BLS VANGUARD - OWNER ACCOUNT CREATED                     |
+==========================================================+
|  username : blsvisa                                      |
|  password : Xk7#mQp2vRt9wZa4Ls6                          |
+==========================================================+
```

لتعيينها بنفسك: `SEED_OWNER_PASSWORD='...'`

تجزئة كلمة المرور: **scrypt** + ملح لكل مستخدم · حدود المحاولات: 5 / 15 دقيقة لكل IP+مستخدم، 10 / 30 دقيقة لكل حساب، 20 / 15 دقيقة لكل IP.

---

## 🚀 فحص جاهزية الإطلاق — Launch readiness

**صفحة:** `/dashboard/launch` · **API:** `/api/launch/preflight`

9 فحوص · درجة مئوية · وكل فاشل يعرض **الحل**:

| الفحص | مطلوب |
|---|---|
| قاعدة البيانات متصلة | ✅ |
| `NODE_ENV=production` | ✅ |
| `ENGINE_SECRET` (≥16 حرفًا) | ✅ |
| `FORCE_HTTPS=true` | ✅ |
| **لا توجد بيانات دخول تجريبية** | ✅ |
| وضع الموصل | ~ |
| بيانات حساب BLS | ~ |
| بوابة الكابتشا البشرية | ✅ |
| النافذة الرسمية | ~ |

```bash
curl -sS $BASE/api/launch/preflight -b "bls_vanguard_session=$C"
# {"launchReady":false,"score":{...},"blockingIds":["secret","https"]}
```

---

## ⏰ نوافذ BLS الرسمية

| اليوم | الساعة | المنطقة الزمنية |
|---|---|---|
| الجمعة | 16:00 | Africa/Algiers (UTC+1) |
| الثلاثاء | 17:00 | Africa/Algiers (UTC+1) |

الحساب الزمني داخلي ومضبوط، حتى لو كان السيرفر يعمل بتوقيت UTC.
نافذة التنفيذ الفعلية: الجمعة 15:55–16:25 · الثلاثاء 16:55–17:25.

---

## 🚀 التشغيل

```bash
npm install
npx drizzle-kit push
cp .env.example .env      # ثم عدّل BLS_MODE ومصادقة BLS
npm run build && npm run start       # http://localhost:3000
```

تطبيق سطح المكتب (Electron):

```bash
cd desktop && npm install
VANGUARD_URL=http://localhost:3000 npm start
```

- **التثبيت خطوة بخطوة:** **[`deploy/STEP-BY-STEP.md`](./deploy/STEP-BY-STEP.md)** ← ابدأ من هنا
- نظرة التثبيت (Docker/PM2/سطح المكتب): **[`INSTALL.md`](./INSTALL.md)**
- حزمة جاهزة للتنزيل: `/bls-vanguard.tar.gz` من نفس الموقع
- كل الأوامر (تشغيل، قاعدة بيانات، API، cron، كابتشا، نسخ احتياطي): **[`COMMANDS.md`](./COMMANDS.md)**

---

## 🌍 لغات التطبيق — Languages / Langues

| اللغة | الاتجاه | ملاحظة |
|---|---|---|
| **العربية** (افتراضي) | RTL كامل |.language primary |
| **Français** | LTR | messages Professional |
| **English** | LTR | technical operators |

تبديل فوري من أي صفحة، ويُحفظ في `localStorage`. صفحات الحجز والبوابة مترجمة بالكامل.

---

## 🚫 سياسة حدود المواعيد — Booking limits

**صفحة المدير:** `/dashboard/policy`

### قاعدة «موعد واحد لكل حساب»
```
يوجد بالفعل طلب نشط لهذا الجواز.
لا يمكن حجز موعد ثانٍ لنفس الحساب.
```
- تُحسب الطلبات **النشطة** فقط: `pending` · `searching` · `captured`
- `confirmed` و `failed` **لا تحجب** طلبًا جديدًا (يمكن إعادة المحاولة)
- المقارنة على **رقم الجواز** (case-insensitive) لا على اسم المستخدم
-_lookup بالuppercase في قاعدة البيانات_

### الحدود التي يتحكم بها المدير

| الحد | الافتراضي | النطاق | المعنى |
|---|---|---|---|
| `oneBookingPerPassport` | ✅ مفعّل | — | قاعدة «موعد واحد لكل حساب» |
| `maxActivePerPassport` | 1 | 1–20 | طلبات نشطة لكل جواز |
| `maxActivePerClient` | 2 | 1–50 | طلبات نشطة لكل مشغّل |
| `maxActiveWorkspace` | 500 | 1–100000 | طلبات نشطة لكل مشغّل (per-operator) |
| `maxDailySubmissions` | 50 | 1–100000 | طلبات جديدة في اليوم |
| `enforceCaps` | ✅ صارم | — | صارم = يرفض · متساهل = تحذير |

### السلوك
- **صارم** → `HTTP 409` + رسالة **ثلاثية اللغة** (عربي/فرنسي/إنجليزي) + العدادات
- **متساهل** → `HTTP 200` + الطلب يُحفظ + `warning` في الرد
- **الصلاحية:** `admin` فقط (`others → 403`)
- **التدقيق:** كل تغيير سياسة وكل طلب مرفوض يُسجَّل في `audit_logs`

**مُختبَر عمليًا:** `duplicate_booking` · `client_cap` · `passport_cap` · `workspace_cap` · `daily_cap`

---

## 🔑 دخول العملاء — Client access codes

| | |
|---|---|
| **الآلية** | رمز من **5 أرقام** يصدره الأدمن ويوزّعه على العميل |
| **بدون كلمة مرور** | العميل يدخل بالرمز فقط |
| **التحكم** | الأدمن يحدد: عدد الاستعمالات · مدة الصلاحية · التفعيل/الإيقاف |
| **الوجهة** | `/portal` — بوابة العميل (عربي) لملء طلب الحجز |
| **الأمان** | خصم ذري للاستعمال (لاRace condition) · حد 10 محاولات/15د · تدقيق كامل |

**مسار المشغّل:** Codes ← New code ← Issue ← نسخ الرمز وإرساله للعميل.

---

## 🔌 ربط BLS عبر ملء الخانات — Connector by form

**لا حاجة لتعديل أي ملف.** صفحة **Integration** تحتوي 12 حقلاً:

| الحقل | مثال |
|---|---|
| Operating mode | `live` |
| Gateway base URL | `https://bls.dz` |
| Login / Slots / Booking paths | من Network tab |
| Session cookie أو بريد+كلمة مرور | من جلستك |
| CAPTCHA solver key · Center id · Timeout | اختياري |

تُحفظ في قاعدة البيانات، **تتجاوز `.env`**، ولا تعود الأسرار للمتصفح (علامة `set` فقط).
زر **Verify connection** يرسل probe حقيقيًا ويعرض `HTTP status` + `latencyMs` + عدد السلوتات.

---

## 📋 استمارة الحجز الكاملة — Full booking form

**57 حقلًا في 9 أقسام** — كل خيارات نموذج BLS الرسمية، ثنائية اللغة.

| القسم | المحتوى |
|---|---|
| 📍 مركز الحجز | 10 مراكز · 5 فئات تأشيرة · 12 نوع طلب · مدة الإقامة · النافذة المفضّلة · الأولوية |
| 🪪 بيانات مقدم الطلب | الاسم (لاتيني/عربي) · الجواز · التعريف الوطني · الإصدار/الانتهاء · الميلاد · الجنس · الحالة · الجنسية |
| 📞 الاتصال | الهاتف · البريد · العنوان · الولاية · البريدي · SMS · Email |
| 💼 مهني/مالي | القطاع · المهنة · جهة العمل · المنصب · الدخل الشهري · مصدر التمويل · المؤسسة |
| ✈️ السفر | الفندق · رقم الحجز · الرحلة · التاريخ · مطار الوصول · الأمتعة |
| 👨‍👩‍👧‍👦 المرافقون | الزوج · الأطفال · رئيس المجموعة · حجم المجموعة · البصمات |
| 💌 الدعوة | الداعي · العنوان · الهاتف · صلة القرابة |
| 🛡️ التأمين والسجل | التأمين · الشركة · الوثيقة · سجل شنغن · عدد التأشيرات · رفض سابق |
| 📝 ملاحظات | نص حر |

**سلوك ذكي:** الحقول تظهر شرطيًا (مثلاً «شركة التأمين» فقط عند تفعيل التأمين) · الحقول الإلزامية تنبّه قبل الإرسال · **الحفظ يربط الطلب تلقائيًا بأول محرك مسلّح**.

الصفحة: **`/dashboard/booking`** (للمشغّل) و **`/portal`** (للعميل).

---

## 🧭 الواجهات

| المسار | الوظيفة |
|---|---|
| `/` | صفحة الدخول + عرض نوافذ الفتح |
| `/dashboard/console` | **بوابة الكابتشا البشرية** + التحكم بالمحرك + Autopilot |
| `/dashboard/overview` | لوحة القيادة والعدّادات والإحصائيات |
| `/dashboard/applicants` | ملفات المتقدمين |
| `/dashboard/appointments` | طابور المواعيد والحالات |
| `/dashboard/automation` | Engine Bay — تسليح وتشغيل الجلسات |
| `/dashboard/integration` | ربط BLS، فحص الجاهزية، واختبار الاتصال |
| `/dashboard/notifications` | التنبيهات |
| `/dashboard/audit` | سجل التدقيق |
| `/dashboard/booking` | استمارة الحجز الكاملة (57 حقلًا) |
| `/dashboard/codes` | إصدار وإدارة أكواد العملاء |
| `/dashboard/settings` | الصلاحيات + كلمة المرور + الجلسات |
| `/dashboard/system` | حالة النظام ورسائل الأخطاء |
| `/dashboard/operators` | إدارة المشغلين والأدوار |
| `/portal` | بوابة العميل (عربي) — يُدخل بالرمز |
| `/legal` | إشعار الخصوصية (عام) |

---

## 🏗️ البنية

```
src/
├── app/
│   ├── page.tsx                  # landing + login
│   ├── dashboard/…               # الواجهات العشر
│   └── api/
│       ├── auth/{login,logout,me}
│       ├── applicants · appointments
│       ├── automation · automation/[id]
│       ├── captcha · captcha/[id] # بوابة بشرية
│       ├── engine/tick            # سيرفر الحجز الدائم
│       ├── integration            # فحص واختبار BLS
│       ├── notifications · stats
│       └── health
├── lib/
│   ├── bls/adapter.ts            # simulation | live
│   ├── bls/human-loop.ts         # لا تجاوز كابتشا — إنسان فقط
│   ├── bls/schedule.ts           # Africa/Algiers timezone-safe
│   ├── automation-engine.ts      # probe → captcha gate → capture
│   ├── auth.ts · session.ts      # scrypt + session tokens
│   ├── rate-limit.ts
│   └── seed.ts
└── db/{index,schema}.ts          # Drizzle + PostgreSQL
desktop/                          # غلاف Electron + نبضة المحرك
```

**الجداول:** operators · applicants · appointments · automation_sessions ·
automation_runs · captcha_challenges · notifications · audit_logs · settings · auth_sessions

---

## 🧩 المبادئ

- **الكابتشا تُحل بشرًا فقط.** المحرك يُنشئ تحديًا في القاعدة، ينتظر، ويستأنف بالتوكن البشري. لا OCR، لا تجاوز.
- **قفل ذري** يمنع الحجز المزدوج، مع استرجاع الجلسات العالقة.
- **احترام التزامن والأولوية** حسب إعدادات كل جلسة.
- **سجل تدقيق** لكل عملية حساسة.
- **بيانات الاعتماد على السيرفر فقط** (متغيرات بيئة) ولا تصل للمتصفح.

---

## ⚠️ تنبيه

الأتمتة على بوابة BLS قد تخالف شروط استخدامها وقد تُعرّض الحساب للحجب.
استخدم حسابك الخاص فقط، بمعدلات بشرية، وابقِ القرار النهائي والدفع بيد الإنسان.

---

## 📚 ملفات مرجعية

- [`INSTALL.md`](./INSTALL.md) — على ماذا يشغّل، Docker، VPS، سطح المكتب، قائمة الانتقال Live
- [`COMMANDS.md`](./COMMANDS.md) — كل الأوامر والاستعلامات وcron وبيانات الدخول
- [`desktop/README.md`](./desktop/README.md) — تشغيل وبناء التطبيق المكتبي
- [`.env.example`](./.env.example) — كل متغيرات البيئة
