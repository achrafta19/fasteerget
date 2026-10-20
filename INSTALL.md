# دليل التثبيت — BLS Vanguard

## على ماذا يشغّل التطبيق؟ / What does it run on?

| الطبقة | التقنية | الإصدار | ملاحظة |
|---|---|---|---|
| Runtime | **Node.js** | 22 LTS (20 يعمل) | JavaScript server |
| Framework | **Next.js** (App Router) | 16 | واجهة + API في عملية واحدة |
| Database | **PostgreSQL** | 14+ (موصى 16) | 10 جداول Drizzle |
| ORM | Drizzle + `pg` | — | لا يحتاج migration runner |
| Desktop | **Electron** | 33 | غلاف اختياري — لا يشغّل السيرفر |
| Reverse proxy | Nginx | — | TLS عبر certbot |
| Process mgr | PM2 أو Docker | — | تبقي العملية حيّة |

**الحد الأدنى للسيرفر:** 1 vCPU · **1.5 GB RAM** · 10 GB SSD · Ubuntu 22.04/24.04 · IP عام.
**موصى به للإنتاج:** 2 vCPU · 4 GB RAM · PostgreSQL محلي · نطاق + TLS.
**لا يحتاج:** GPU · Redis (اختياري لاحقًا) · خدمات خارجية.

> مهم: شغّل **نسخة واحدة** فقط (`instances: 1`). المحرك يحفظ حالة الدورة داخل العملية، وتشغيل نسختين قد يسبب حجزًا مزدوجًا (القفل الذري يمنعه لكن الأفضل نسخة واحدة).

---

## 0 — افحص الجاهزية أولًا (30 ثانية)

```bash
bash deploy/preflight.sh
```

يفحص: Node · الذاكرة · القرص · ملفات المشروع · `.env` · اتصال PostgreSQL · عدد الجداول · وجود build · المنفذ 3000 · وشروط وضع `live`.
يطبع `PASS / WARN / FAIL` ويخرج برمز خطأ إذا كان هناك `FAIL`. شغّله على السيرفر **قبل** التثبيت وبعده.

---

## الطريقة A — معاينة سريعة (دقيقة واحدة)

المعاينة الحالية تعمل على الاستضافة المُدارة من المنصة ولا تحتاج أي تثبيت:

```
https://<preview-host>/         → الدخول
blsvisa / <كلمة المرور التي طُبعت مرة واحدة عند أول تشغيل>
أو الحدّدها بنفسك: SEED_OWNER_PASSWORD='…' في .env
```

هذه **بيئة تجريبية** (simulation). لا تحجز حقيقيًا، ولا تضمن بقاء العملية 24/7.

---

## الطريقة B — VPS بـ Docker (الأسهل للإنتاج)

```bash
# 1) على السيرفر
sudo apt update && sudo apt install -y docker.io docker-compose-plugin git
sudo usermod -aG docker $USER && newgrp docker

# 2) الكود
sudo mkdir -p /opt/vanguard && sudo chown $USER /opt/vanguard
git clone <your-repo> /opt/vanguard     # أو ارفع المجلد بـ scp/rsync
cd /opt/vanguard

# 3) الإعدادات
cp .env.example .env
nano .env
#   POSTGRES_PASSWORD=<قوي>
#   ENGINE_SECRET=<openssl rand -hex 24>
#   ENGINE_OPERATOR_ID=1
#   BLS_MODE=simulation        (أو live بعد توصيل الحساب)

# 4) التشغيل
docker compose up -d --build

# 5) المخطط والبيانات الأولية
docker compose exec app npx drizzle-kit push
curl -s http://127.0.0.1:3000/api/health     # → operational

# 6) التحقق
docker compose ps          # db + app + ticker كلها Up
docker compose logs -f app
```

الخدمات الثلاث تعمل تلقائيًا:
- **db** — PostgreSQL مع volume دائم
- **app** — الواجهة و API على المنفذ 3000
- **ticker** — نبضة حجز كل 60 ثانية (سيرفر الحجز الدائم)

**HTTPS:** ضع Nginx أمام 3000 و`certbot --nginx -d your-domain.dz`، أو استخدم Cloudflare Tunnel.

---

## الطريقة C — VPS بدون Docker (PM2 + systemd)

```bash
sudo DOMAIN=your-domain.dz bash deploy/install.sh /opt/vanguard
```

السكربت يقوم بـ: Node 22 · PostgreSQL + إنشاء القاعدة · `.env` بمفتاح سري عشوائي · `npm ci` · `drizzle-kit push` · `npm run build` · **PM2** · **مؤقّت نبضة كل دقيقة** · Nginx + TLS + UFW.

يدويًا:

```bash
npm ci && npx drizzle-kit push && npm run build
npm i -g pm2
pm2 start ecosystem.config.cjs && pm2 save && pm2 startup
sudo cp deploy/vanguard-tick.{service,timer} /etc/systemd/system/
sudo systemctl enable --now vanguard-tick.timer
sudo cp deploy/nginx.conf /etc/nginx/sites-available/vanguard && sudo ln -s ...
sudo certbot --nginx -d your-domain.dz
```

---

## الطريقة D — تطبيق سطح المكتب (Electron)

الغلاف المكتبي **عميل فقط**: يعرض الكونسول ويُبقي المحرك نشطًا، لكن السيرفر يجب أن يعمل في مكان آخر.

```bash
cd desktop
npm install
VANGUARD_URL=https://your-domain.dz npm start     # نافذة أصلية
npm run dist                                       # ملف تثبيت في release/
```

> لا يمكن تشغيله داخل معاينة المتصفح — يحتاج جهازًا (Windows/macOS/Linux).

---

## قائمة الانتقال إلى الحجز الحقيقي (Live)

| # | الخطوة | الأمر / الملف |
|---|---|---|
| 1 | غيّر كلمة مرور المالك | `COMMANDS.md` §10 |
| 2 | اضبط `ENGINE_SECRET` قويًا | `.env` |
| 3 | فعّل HTTPS | certbot / Cloudflare |
| 4 | اسحب HAR من جلستك في BLS وثبّت المسارات | `src/lib/bls/adapter.ts` |
| 5 | أضف مصادقة الحساب | `BLS_SESSION_COOKIE` أو بريد+كلمة مرور |
| 6 | أضف متصفحًا آليًا للبوابات التي تعتمد JS | Playwright + التقاط صورة الكابتشا |
| 7 | فعّل تنبيهات فورية (Telegram/Email) | **غير مُنفّذ بعد** — أولوية عالية |
| 8 | شغّل `BLS_MODE=live` وأعد التشغيل | `docker compose up -d` |
| 9 | نفّذ `Run drill` في صفحة Integration | يجب أن يعيد `live · reachable` |
| 10 | جرّب دورة واحدة بـ `Force drill` | راقب بوابة الكابتشا البشرية |

⚠️ **الكابتشا تبقى بشرية.** لا OCR ولا تجاوز. والخطوة النهائية (الدفع/التأكيد) تبقى بيد الإنسان.

---

## النسخ الاحتياطي / الاستعادة

```bash
# نسخ
docker compose exec -T db pg_dump -U vanguard vanguard | gzip > backup-$(date +%F).sql.gz

# استعادة
gunzip -c backup-2026-10-18.sql.gz | docker compose exec -T db psql -U vanguard vanguard

# جدولة يومية (cron)
0 3 * * * cd /opt/vanguard && docker compose exec -T db pg_dump -U vanguard vanguard | gzip > /backups/vanguard-$(date +\%F).sql.gz
```

---

## الصيانة

```bash
docker compose logs -f app              # اللوجات
docker compose restart app              # إعادة تشغيل
docker compose up -d --build            # تحديث بعد سحب كود جديد
docker compose exec app npx drizzle-kit push   # بعد تغيير المخطط
# جلسة عالقة في running:
psql "$DATABASE_URL" -c "update automation_sessions set status='armed' where status='running'"
```

**مؤشرات المراقبة:** `/api/health` · عدد الكابتشا المعلّقة · آخر `automation_runs` · تفويت نافذة فتح (لا يوجد تنبيه حاليًا — راجعه يدويًا).

---

## استكشاف الأخطاء

| العرض | السبب المرجّح | الحل |
|---|---|---|
| 500 على كل الصفحات | `DATABASE_URL` خاطئ أو القاعدة غير مهيّأة | تحقق من `.env` ثم `drizzle-kit push` |
| الدخول يفشل | القاعدة فارغة (لا seed) | افتح `/api/health` مرة ليعمل seed |
| `health` يعمل والكونسول لا | جلسة منتهية | سجّل الدخول من جديد |
| المحرك لا يطلق | خارج النافذة الرسمية | طبيعي — استخدم `Force drill` للتدريب |
| الكابتشا تنتهي دائمًا | لا أحد يراقب الكونسول | فعّل التنبيهات الفورية (خطوة 7) |
| `ticker` يفشل | `ENGINE_SECRET` أو `OPERATOR_ID` خاطئ | `select id from operators where username='blsvisa'` |

---

## الملفات المرجعية

| الملف | المحتوى |
|---|---|
| `README.md` | نظرة عامة + بيانات الدخول + البنية |
| `COMMANDS.md` | كل الأوامر: بناء، قاعدة بيانات، API، cron، تغيير كلمة المرور |
| `INSTALL.md` | هذا الدليل |
| `Dockerfile` · `docker-compose.yml` | نشر Docker |
| `deploy/install.sh` | تثبيت VPS تلقائي |
| `deploy/nginx.conf` | Reverse proxy + TLS |
| `deploy/vanguard-tick.{service,timer}` | نبضة المحرك الدائمة |
| `ecosystem.config.cjs` | إعداد PM2 |
| `desktop/README.md` | التطبيق المكتبي |
| `.env.example` | كل متغيرات البيئة |
