# نموذج بيانات Firestore — وحدة قدرة استعادة الخدمة

قاعدة البيانات: `sanadgrid` (مشروع `sanadgrid-5176a`). الأنواع المطابقة في الفرونت: `src/features/restoration/types.ts`.

## المبدأ

كل المجموعات **في المستوى الأعلى** (مو متداخلة)، وكل مستند يحمل:

| الحقل | المعنى |
| --- | --- |
| `sectorId` | القطاع: `central`, `western`, `eastern`, `southern` … |
| `visibility` | `public` = بيانات عامة تجريبية يقرأها أي زائر · `restricted` = بيانات فعلية لأعضاء القطاع فقط |

**التوسع لقطاع جديد = إضافة مستندات بـ `sectorId` جديد.** لا تغيير في الهيكل ولا في القواعد ولا في الكود.

سبب اختيار المستوى الأعلى بدل `sectors/{id}/substations`: نفس الاستعلام يشتغل لقطاع واحد أو لعدة قطاعات، والقواعد تتحقق من حقل واحد، ومعرّف المستند يبقى فريداً على مستوى الشركة.

## المجموعات

### `sectors/{sectorId}`
| الحقل | النوع | ملاحظات |
| --- | --- | --- |
| `nameAr`, `nameEn` | string | |
| `center` | GeoPoint | مركز الخريطة |
| `zoom` | number | |
| `areas` | array | `{ id: 'COA', nameAr, departments?: string[] }` |
| `monthlyLoadFactor` | number[12] | حمل كل شهر كنسبة من الذروة السنوية |
| `monthlyDerating` | number[12] | تخفيض السعة الحرارية حسب حرارة الجو |
| `forecastGrowth` | number | نمو الذروة المتوقعة، مثل `1.05` |
| `visibility` | string | |

### `substations/{id}` — المعرّف: `{sectorId}-{code}` مثل `central-ng-101`
| الحقل | النوع | ملاحظات |
| --- | --- | --- |
| `sectorId`, `areaId`, `department` | string | `department` قد يكون `null` |
| `code`, `district` | string | |
| `type` | `NG` \| `MDN` | |
| `voltageKv` | number | 33 أو 13.8 |
| `location` | GeoPoint | |
| `transformersMva` | number[] | السعة المؤكدة = المجموع − أكبر محول |
| `sensitiveCustomers`, `vipCustomers` | string[] | أنواع فقط (مستشفى، مركز بيانات) — بدون أسماء |
| `temporarySupplyMva` | number | مولدات/محطة متنقلة، `0` = لا يوجد |
| `visibility` | string | |

### `feeders/{id}` — `{stationId}-f{n}`
`sectorId`, `stationId`, `code`, `construction` (`underground`\|`overhead`), `ratingMva`, `peakLoadMva` (عند الذروة السنوية), `customers`, `visibility`.

حمل المحطة لا يُخزَّن — يُحسب من مجموع مغذياتها، عشان ما يصير فيه رقمين متعارضين.

### `ties/{id}` — `{sectorId}-tie-{nnn}`
نقطة ربط مفتوحة عادةً بين مغذيين من محطتين مختلفتين بنفس الجهد.
`sectorId`, `fromFeederId`, `toFeederId`, `construction`, `circuits` (1\|2), `capacityMva`, `switching` (`remote`\|`manual`), `visibility`.

### `networkBundles/{sectorId}_{visibility}_{n}` — اللي تقرأه اللوحة فعلياً
كل قراءة مستند في Firestore محسوبة (الحصة المجانية 50 ألف/يوم). قراءة القطاع مستنداً مستنداً = 159 قراءة لكل فتح صفحة، وهذا استهلك الحصة كاملة في يوم واحد (2026-09-18). الحل: عند النشر تنكتب نسخة مجمّعة من القطاع:

`sectorId`, `visibility`, `index`, `count` (عدد الأجزاء), `version` (وقت النشر), `payload` — نص JSON فيه `{ sector, substations, feeders, ties }`، مقسّم لأجزاء أقل من 700KB.

المجموعات التفصيلية (`substations`, `feeders`, `ties`) تبقى **مصدر الحقيقة للتعديل**، والحزمة نسخة للقراءة تتجدد مع كل نشر. اللوحة تقرأ الحزمة فقط (قراءة–قراءتين)، وتحتفظ بها محلياً وتقارن `version` قبل ما تعيد التحميل.

### `mapLayerIndex/{sectorId}` — فهرس الطبقات المستوردة
مستند واحد فيه مصفوفة أوصاف الطبقات (`layers`) بدل قراءة ~100 مستند وصف مع كل فتح. يتحدّث مع كل استيراد أو حذف. `sectorId`, `visibility: 'restricted'`, `layers`, `updatedAt`.

### `mapLayers/{layerId}` و `mapLayerChunks/{layerId}_{n}` — طبقات مستوردة من KMZ/KML
الاستيراد يتم من صفحة المشرف داخل المتصفح ويكتب مباشرة هنا. **الملف نفسه ما يمر على أي ريبو.**

`mapLayers`: `sectorId`, `visibility` (دائماً `restricted` للبيانات الفعلية), `name`, `path` (مسار المجلد في الملف الأصلي), `sourceFile`, `importedAt`, `counts` `{ point, line, polygon }`, `bbox` `[west, south, east, north]`, `chunks` (عدد الأجزاء), `style` `{ color }`.

`mapLayerChunks`: `sectorId`, `visibility`, `layerId`, `index`, `features` — نص JSON لمصفوفة عناصر GeoJSON مختصرة (`{ t: 'p'|'l'|'g', n: name, d: description, c: coordinates }`)، كل جزء أقل من 700KB.

ليش مو مستند لكل عنصر؟ الملف فيه آلاف العناصر، ومستند لكل عنصر يعني آلاف القراءات مع كل فتح للخريطة. الطبقة تنقرأ كأجزاء قليلة، وفقط لما المستخدم يفعّلها.

المحطات الفعلية اللي بتدخل في **الحساب** مكانها `substations` + `feeders` + `ties` (تحتاج أحمال وسعات). الطبقات هنا للعرض الجغرافي فقط.

### `zones/{id}` (لاحقاً)
مناطق التخطيط، المشاريع الكبرى، مواقع البحث عن محطات. `sectorId`, `kind`, `name`, `geometry` (GeoJSON كنص — Firestore ما يدعم المصفوفات المتداخلة), `visibility`.

### `snapshots/{sectorId}_{period}_{scenario}` (اختياري)
نتائج محسوبة محفوظة للتقارير والمقارنة الزمنية. الحساب نفسه يتم في الفرونت (`engine.ts`) وممكن ينتقل لـ Cloud Function بدون تغيير.

### الصلاحيات
| المجموعة | من يكتبها | الغرض |
| --- | --- | --- |
| `admins/{uid}` | **Firebase Console فقط** | وجود المستند = مشرف |
| `members/{uid}` | المشرف | `{ sectors: ['central', ...] }` — القطاعات المسموح قراءة بياناتها الفعلية |
| `users/{uid}` | صاحبه | ملف شخصي فقط، **لا صلاحيات فيه** |

العضوية منفصلة عن `users` عمداً: لو كانت داخل ملف المستخدم لقدر أي مستخدم يضيف نفسه لأي قطاع.

## الاستعلامات

```ts
// زائر بدون تسجيل دخول — لازم فلتر visibility وإلا القواعد ترفض الاستعلام كله
query(collection(db, 'substations'),
  where('sectorId', '==', 'central'), where('visibility', '==', 'public'))

// عضو مسجّل في القطاع — يشوف العام والفعلي
query(collection(db, 'substations'), where('sectorId', '==', 'central'))
```

فلترين مساواة على حقلين ما يحتاجون فهرس مركّب. لو انضاف ترتيب أو فلتر نطاق (مثل `orderBy('code')`) ينضاف الفهرس في `firestore.indexes.json`.

## أول مشرف

1. Firebase Console → Authentication → فعّل Google.
2. سجّل دخول مرة في الموقع، ثم انسخ الـ UID من Authentication → Users.
3. Firestore → Start collection → `admins` → Document ID = الـ UID → أي حقل (مثل `createdAt`).

## البيانات الفعلية

- لا ترفع بيانات فعلية في أي ريبو. تدخل Firestore فقط، بـ `visibility: 'restricted'`، من مشرف مسجّل دخول.
- قبلها: ريبو الفرونت يتحول لخاص أو تتأكد إن ما فيه أي بيانات، وتنضاف العضويات في `members`.
