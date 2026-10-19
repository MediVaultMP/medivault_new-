# MediVault API Contract

**Version:** `/api/v1`  
**Status:** Code-derived draft. Confirm service-level behavior and all route definitions before treating this as a stable external API specification.

## General conventions

- JSON requests use `Content-Type: application/json`, except file uploads, which use `multipart/form-data`.
- The application parses JSON request bodies up to 1 MiB.
- Protected routes require authentication through `authenticate(authService)`. Role restrictions are specified below.
- Use the authentication token returned by login according to the authentication middleware implementation.
- UUID path parameters are validated where specified by the controller.
- The standard not-found response is:
  `404 { "error": { "code": "NOT_FOUND", "message": "Route not found." } }`
- Zod validation errors return HTTP 400:
  `{ "error": { "code": "VALIDATION_ERROR", "message": "Invalid request body.", "details": [...] } }`
- The validation handler may use the message "Invalid request body." for parameter validation errors as well.
- Multer upload errors return HTTP 400:
  `{ "error": { "code": "UPLOAD_ERROR", "message": "File must not exceed 10 MB." } }`
  or
  `{ "error": { "code": "UPLOAD_ERROR", "message": "Invalid file upload." } }`
- Other application errors use:
  `{ "error": { "code": "...", "message": "..." } }`
- HTTP 5xx responses hide internal error details.
- Some routers are mounted conditionally when their services are configured. If a router is not mounted, its paths return 404.

---

## Authentication and health

| Method | Path | Access | Request | Success response |
|---|---|---|---|---|
| POST | `/api/v1/auth/register` | Public | JSON: `name`, `email`, `password`, `role`; `licenseId` required for `doctor` and `pharmacy`, forbidden for `patient`. Password must be 12–128 characters and include lowercase, uppercase, digit, and special character. Name must be 1–200 characters after trimming. Email must be valid and at most 254 characters. | HTTP 201: `{ user, token }` |
| POST | `/api/v1/auth/login` | Public | JSON: `email`, `password`. Email must be valid and at most 254 characters; password must be 12–128 characters. | Authentication service response; confirm exact fields in `auth-service.js`. |
| GET | `/api/v1/health` | Public | None | `{ "status": "ok" }` |
| GET | `/api/v1/health/me` | Authenticated | None | `{ user }` |
| GET | `/api/v1/health/doctor-only` | Doctor | None | `{ "status": "ok" }` |

### Registration notes

- Patients are registered with active status.
- Doctor and pharmacy accounts are registered with pending status.
- Pending professional accounts do not receive an authentication token at registration.
- Professional registration requires a license ID, but this requirement alone does not establish independent verification with a licensing authority.
- Duplicate email addresses are rejected by the authentication service.

---

## Patient profile and wallet

All `/api/v1/patients/me/profile` routes require the `patient` role.

| Method | Path | Access | Request | Success response |
|---|---|---|---|---|
| GET | `/api/v1/patients/me/profile` | Patient | None | Profile response; confirm the exact wrapper in the profile controller. |
| POST | `/api/v1/patients/me/profile` | Patient | JSON profile fields | Profile creation response; confirm the schema and status code in the controller. |
| PATCH | `/api/v1/patients/me/profile` | Patient | JSON fields to update | Profile update response; confirm the schema in the controller. |
| PUT | `/api/v1/patients/me/wallet` | Patient | Wallet payload | Confirm the exact schema and response in the wallet controller. |
| PUT | `/api/v1/account/wallet` | Authenticated user | Wallet payload | Confirm the exact schema and response in the wallet controller. |

The account wallet route does not apply a role restriction in the route definition described in this draft. Confirm service-level authorization before publishing this as a stable contract.

---

## Medical records

Patient routes require the `patient` role. Doctor routes require the `doctor` role.

Patient and record IDs are UUIDs where validated by the relevant controllers.

### Upload rules

- Multipart file field: `document`.
- Maximum number of files: one.
- Maximum file size: 10 MiB.
- Allowed extension and MIME-type pairs:
  - `.pdf` — `application/pdf`
  - `.png` — `image/png`
  - `.jpg` — `image/jpeg`
  - `.jpeg` — `image/jpeg`
  - `.doc` — `application/msword`
  - `.docx` — `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
- Optional metadata:
  - `title`: trimmed string, 1–200 characters.
  - `category`: one of `lab-result`, `imaging`, `prescription`, `clinical-note`, or `other`.
- Unknown upload metadata fields are rejected.

### Patient record endpoints

| Method | Path | Access | Request | Success response |
|---|---|---|---|---|
| POST | `/api/v1/patients/me/records` | Patient | Multipart `document`; optional `title`, `category` | HTTP 201: `{ record }` |
| GET | `/api/v1/patients/me/records` | Patient | None | `{ records }` |
| GET | `/api/v1/patients/me/records/:recordId/download` | Patient | `recordId` UUID | File bytes with content type and attachment filename |
| POST | `/api/v1/patients/me/records/:recordId/verify` | Patient | `recordId` UUID | `{ verification }` |
| POST | `/api/v1/patients/me/records/:recordId/register-on-chain` | Patient | `recordId` UUID | `{ record }` |
| PATCH | `/api/v1/patients/me/records/:recordId/emergency-essential` | Patient | JSON `{ "isEmergencyEssential": boolean }` | `{ record }` |
| GET | `/api/v1/patients/me/record-access-requests` | Patient | None | `{ requests }` |
| POST | `/api/v1/patients/me/record-access-requests/:requestId/approve` | Patient | `requestId` UUID | `{ request }` |
| POST | `/api/v1/patients/me/record-access-requests/:requestId/reject` | Patient | `requestId` UUID | `{ request }` |
| POST | `/api/v1/patients/me/record-access-requests/:requestId/revoke` | Patient | `requestId` UUID | `{ request }` |

### Doctor record endpoints

| Method | Path | Access | Request | Success response |
|---|---|---|---|---|
| GET | `/api/v1/doctor/patients/:patientId/records` | Doctor | `patientId` UUID | `{ records }` |
| POST | `/api/v1/doctor/patients/:patientId/records/:recordId/access-request` | Doctor | `patientId` and `recordId` UUIDs | HTTP 201: `{ request }` |
| POST | `/api/v1/doctor/patients/:patientId/records` | Doctor | Multipart `document`; optional `title`, `category` | HTTP 201: `{ record }` |
| GET | `/api/v1/doctor/patients/:patientId/records/:recordId/download` | Doctor | `patientId` and `recordId` UUIDs | File bytes with content type and attachment filename |

Route-level role checks do not, by themselves, establish patient ownership or consent. Those rules must also be enforced by the corresponding services and repositories.

---

## Patient-doctor consent

Patient consent routes require authentication and the `patient` role. Doctor consent routes require authentication and the `doctor` role.

The patient's identity is obtained from the authenticated user's identity (`req.user.sub`), rather than from a patient ID supplied in the request body.

| Method | Path | Access | Request | Success response |
|---|---|---|---|---|
| GET | `/api/v1/consents` | Patient | None | `{ consents }` |
| POST | `/api/v1/consents` | Patient | JSON: `licenseId`, `expiresAt` | HTTP 201: `{ consent }` |
| DELETE | `/api/v1/consents/:doctorId` | Patient | `doctorId` must be a UUID | `{ consent }` |
| GET | `/api/v1/doctor/patients` | Doctor | None | `{ patients }` |

### Grant consent

**Endpoint:** `POST /api/v1/consents`

Example request:

```json
{
  "licenseId": "DOCTOR-LICENSE-ID",
  "expiresAt": "2027-01-01T00:00:00.000Z"
}