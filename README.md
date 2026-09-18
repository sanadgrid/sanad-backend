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

النشر يستخدم **Workload Identity Federation**: GitHub يثبت هويته لـ Google مباشرة، بدون مفاتيح JSON ولا أي secret في GitHub. (إنشاء المفاتيح محظور أصلاً بسياسة المنظمة.)

1. افتح [Google Cloud Shell](https://shell.cloud.google.com/?project=sanadgrid-5176a) بحساب مالك المشروع.
2. شغّل سكربت الإعداد:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/sanadgrid/sanad-backend/main/scripts/setup-github-deploy.sh | bash
   ```

السكربت ينشئ حساب خدمة `github-deployer` بصلاحيات نشر قواعد وفهارس Firestore فقط، ويسمح لهذا الريبو تحديداً (`sanadgrid/sanad-backend`) باستخدامه. آمن تشغيله أكثر من مرة.

بعدها أي push على `main` ينشر القواعد. تقدر تشغله يدوياً من تبويب Actions ← Run workflow.

> تنبيه: النشر يستبدل القواعد الموجودة في Firebase Console. عدّل القواعد من هذا الريبو فقط، مو من الكونسول.

## القواعد الحالية

نموذج البيانات كامل في [docs/data-model.md](docs/data-model.md).

- `users/{uid}`: المستخدم المسجّل يقرأ ويكتب مستنده فقط (ملف شخصي، بدون صلاحيات).
- `sectors`, `substations`, `feeders`, `ties`, `zones`, `snapshots`: المستند اللي `visibility` حقه `public` يقرأه أي زائر، و`restricted` يقرأه عضو القطاع فقط. الكتابة للمشرف فقط.
- `admins/{uid}`: ينكتب من Firebase Console فقط. `members/{uid}`: يكتبه المشرف ويحدد القطاعات المسموحة لكل مستخدم.
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
