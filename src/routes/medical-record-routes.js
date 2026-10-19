import { Router } from 'express';
import multer from 'multer';

import { createMedicalRecordController } from '../controllers/medical-record-controller.js';
import { authenticate } from '../middleware/authenticate.js';
import { authorize } from '../middleware/authorize.js';

const MAX_FILE_SIZE = 10 * 1024 * 1024;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 1
  }
});

// --------------------------------------------------
// PATIENT MEDICAL RECORD ROUTES
// --------------------------------------------------

export function createMedicalRecordRouter(
  authService,
  medicalRecordService
) {
  const router = Router();

  const controller =
    createMedicalRecordController(medicalRecordService);

  router.use(
    authenticate(authService),
    authorize('patient')
  );

  // Upload the patient's own medical record.
  router.post(
    '/me/records',
    upload.single('document'),
    controller.uploadForPatient
  );

  // List personal records.
  router.get(
    '/me/records',
    controller.listOwn
  );

  // Download a personal record.
  router.get(
    '/me/records/:recordId/download',
    controller.downloadOwn
  );

  // Verify record integrity.
  router.post(
    '/me/records/:recordId/verify',
    controller.verifyOwn
  );

  // Register a record on-chain.
  router.post(
    '/me/records/:recordId/register-on-chain',
    controller.registerOwnOnChain
  );

  // Mark or unmark an emergency-essential record.
  router.patch(
    '/me/records/:recordId/emergency-essential',
    controller.setOwnEmergencyEssential
  );

  // View individual-file access requests.
  router.get(
    '/me/record-access-requests',
    controller.listAccessRequestsForPatient
  );

  // Approve a doctor's request.
  router.post(
    '/me/record-access-requests/:requestId/approve',
    controller.approveRecordAccess
  );

  // Reject a doctor's request.
  router.post(
    '/me/record-access-requests/:requestId/reject',
    controller.rejectRecordAccess
  );

  // Revoke previously approved access.
  router.post(
    '/me/record-access-requests/:requestId/revoke',
    controller.revokeRecordAccess
  );

  return router;
}

// --------------------------------------------------
// DOCTOR MEDICAL RECORD ROUTES
// --------------------------------------------------

export function createDoctorMedicalRecordRouter(
  authService,
  medicalRecordService
) {
  const router = Router();

  const controller =
    createMedicalRecordController(medicalRecordService);

  router.use(
    authenticate(authService),
    authorize('doctor')
  );

  // List patient record metadata.
  router.get(
    '/patients/:patientId/records',
    controller.listForDoctor
  );

  // Request access to one specific file.
  router.post(
    '/patients/:patientId/records/:recordId/access-request',
    controller.requestRecordAccess
  );

  // Upload a record for a patient.
  router.post(
    '/patients/:patientId/records',
    upload.single('document'),
    controller.uploadForDoctor
  );

  // Download a record after the service authorizes access.
  router.get(
    '/patients/:patientId/records/:recordId/download',
    controller.downloadForDoctor
  );

  return router;
}