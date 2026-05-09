# Worker Portal (Employee app)

Flutter app for shop-floor employees. Companion to the admin app at the
repo root. Mirrors the admin app's deep-navy / electric-blue ERP theme
so the two read as one product.

## Features

| Tab                 | What it does                                                        | API used                                                            |
| ------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Enter Production    | Lists my open shifts; sheet to log production + timer + feedback    | `GET /shift/employee-open-shifts?id=…`, `POST /shift/enter-shift-production` |
| Shift History       | Two tabs — open + closed shifts (last 30)                           | `GET /shift/employee-open-shifts?id=…`, `GET /shift/employee-closed-shifts?id=…` |
| Wastage Report      | My last 50 wastage entries with totals                              | `GET /wastage/get-by-employee?id=…`                                 |
| Payroll             | Monthly slip + advance-request flow                                 | `GET /payroll/slip/:empId?year=…&month=…`, `GET /payroll/advance?employeeId=…`, `POST /payroll/advance` |

## Auth

- Login via the existing `POST /user/login-user` (email + password).
- Bootstrap `GET /user/me` returns the linked Employee doc; the id is
  what every other endpoint here filters by.
- Session persists in `SharedPreferences`; `LoginController._handleAutoLogin`
  validates the token on cold start and falls back to cached fields
  when offline.

The User → Employee link is a new `User.employee` ref added in this
work. Existing admin users will need the field set (e.g. via a one-off
script or admin UI) before the worker portal lights up.

## Layout

```
employee_app/
├── main.dart                       # entry — GetMaterialApp + AuthGate
└── src/
    ├── core/api_client.dart        # shared Dio with JWT cookie interceptor
    ├── theme/erp_theme.dart        # ErpColors / ErpTextStyles / ErpDecorations
    └── features/
        ├── auth/                   # login + session
        ├── home/                   # dashboard (4 cards)
        ├── shift_production/       # close-an-open-shift flow
        ├── shift_history/          # open + closed tabs
        ├── wastage/                # last 50 records
        └── payroll/                # slip + advance request
```

## Wiring into a Flutter project

This folder is just source; standard Flutter scaffolding (`pubspec.yaml`,
`android/`, `ios/`, etc.) lives outside the repo, matching the admin app's
layout. Required packages:

```yaml
dependencies:
  flutter:
    sdk: flutter
  get: ^4.6.6
  dio: ^5.3.0
  shared_preferences: ^2.2.0
  intl: ^0.19.0
```

Point `main.dart` at the entry file in this folder when generating
`lib/main.dart`, or copy it in.
