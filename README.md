# sanad — Backend (Firebase)

الباك اند هو Firebase: قواعد أمان Firestore + الفهارس. أي `push` على `main` ينشرها تلقائياً عبر GitHub Actions.

الفرونت اند في ريبو منفصل: [sanad-frontend](https://github.com/sanadgrid/sanad-frontend) (ينشر على Netlify).

## الملفات

| الملف | وظيفته |
| --- | --- |
| `firestore.rules` | قواعد الأمان — مين يقرأ/يكتب أي مسار |
| `firestore.indexes.json` | الفهارس المركبة للاستعلامات |
| `firebase.json` | يربط الملفات فوق بأداة Firebase CLI |
| `.github/workflows/deploy.yml` | النشر التلقائي عند كل push |

## إعداد النشر التلقائي (مرة واحدة)

1. Firebase Console ← ⚙ Project settings ← **Service accounts** ← **Generate new private key** (ينزل ملف JSON).
2. Google Cloud Console ← IAM ← أعط حساب الخدمة هذي الأدوار:
   - `Firebase Rules Admin`
   - `Cloud Datastore Index Admin`
   - `Service Usage Viewer`
3. GitHub ← هذا الريبو ← Settings ← Secrets and variables ← Actions ← **New repository secret**:
   - الاسم: `FIREBASE_SERVICE_ACCOUNT`
   - القيمة: محتوى ملف JSON كامل.
4. احذف ملف JSON من جهازك أو احفظه في مكان آمن. **لا ترفعه على Git أبداً** (الـ `.gitignore` يحجبه احتياطاً).

بعدها أي push على `main` ينشر القواعد. تقدر تشغله يدوياً من تبويب Actions ← Run workflow.

> تنبيه: النشر يستبدل القواعد الموجودة في Firebase Console. عدّل القواعد من هذا الريبو فقط، مو من الكونسول.

## القواعد الحالية

- `users/{uid}`: المستخدم المسجّل يقرأ ويكتب مستنده فقط.
- أي مسار ثاني: مرفوض. كل collection جديدة لازم تضيف لها قاعدة صريحة.

## تجربة محلية (اختياري)

```bash
npx firebase-tools login
npx firebase-tools deploy --only firestore --project <project-id>
```

## خريطة الطبقات

| الطبقة | في سند |
| --- | --- |
| التطبيق (الواجهة) | ريبو `sanad-frontend` — React على Netlify |
| البيانات والأدوات | Firestore + Firebase Auth (هذا الريبو يحكم قواعدها) |
| البنية السحابية | Netlify (فرونت) + Firebase/Google Cloud (باك) |
| الذكاء الاصطناعي (مستقبلاً) | Cloud Functions في مجلد `functions/` هنا — تستدعي نموذج LLM وتحتفظ بمفتاح الـ API سرّياً. مفاتيح الـ AI ما تنحط في الفرونت أبداً. |
