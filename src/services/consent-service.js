
import { AppError } from '../utils/app-error.js';

export class ConsentService {
  constructor({
    consentRepository,
    userRepository,
    recordRegistryClient,
    auditService,
  }) {
    this.consentRepository = consentRepository;
    this.userRepository = userRepository;
    this.recordRegistryClient = recordRegistryClient;
    this.auditService = auditService;
  }

  async listForPatient(patientUserId) {
    const consents =
      await this.consentRepository.listActiveForPatient(patientUserId);

    return consents.map((consent) => ({
      doctorUserId: consent.doctor_user_id,
      doctorEmail: consent.doctor_email,
      doctorName: consent.doctor_name,
      licenseId: consent.license_id,
      expiresAt: consent.expires_at,
      createdAt: consent.created_at,
    }));
  }

  async listForDoctor(doctorUserId) {
    const consents =
      await this.consentRepository.listActiveForDoctor(doctorUserId);

    return consents.map((consent) => ({
      patientUserId: consent.patient_user_id,
      patientName: consent.patient_name,
      patientEmail: consent.patient_email,
      expiresAt: consent.expires_at,
      createdAt: consent.created_at,
    }));
  }

  async grantByLicense(patientUserId, licenseId, expiresAt) {
    if (typeof licenseId !== 'string' || !licenseId.trim()) {
      throw new AppError(
        400,
        "Enter the doctor's medical license number.",
        'LICENSE_REQUIRED',
      );
    }

    const doctor =
      await this.userRepository.findActiveDoctorByLicenseId(
        licenseId.trim(),
      );

    if (!doctor) {
      throw new AppError(
        404,
        'No active, approved doctor was found for that medical license number.',
        'DOCTOR_LICENSE_NOT_FOUND',
      );
    }

    return this.grant(patientUserId, doctor.id, expiresAt);
  }

  async grant(patientUserId, doctorId, expiresAt) {
    const expiry = new Date(expiresAt).getTime();

    if (
      !expiresAt ||
      Number.isNaN(expiry) ||
      expiry <= Date.now()
    ) {
      throw new AppError(
        400,
        'Consent expiry must be a future date.',
        'INVALID_CONSENT_EXPIRY',
      );
    }

    const patient = await this.userRepository.findById(patientUserId);

    if (!patient || patient.role !== 'patient') {
      throw new AppError(
        404,
        'Patient not found.',
        'PATIENT_NOT_FOUND',
      );
    }

    const doctor = await this.userRepository.findById(doctorId);

    if (
      !doctor ||
      doctor.role !== 'doctor' ||
      doctor.status !== 'active' ||
      !doctor.license_id
    ) {
      throw new AppError(
        404,
        'An active doctor with a registered medical license was not found.',
        'DOCTOR_LICENSE_NOT_FOUND',
      );
    }

    const existing = await this.consentRepository.findActive(
      patientUserId,
      doctorId,
    );

    if (existing) {
      throw new AppError(
        409,
        'Consent already exists for this doctor.',
        'CONSENT_EXISTS',
      );
    }

    // Consent is stored in PostgreSQL.
    // Blockchain-backed consent must be implemented separately.
    const consent = await this.consentRepository.grant({
      patientUserId,
      doctorUserId: doctorId,
      expiresAt: new Date(expiresAt),
      transactionHash: null,
    });

    // audit_events.resource_id is UUID, so use a valid UUID here.
    // Preserve both user IDs in metadata.
    const resourceId = consent.doctor_user_id;

    await this.auditService?.record({
      eventType: 'consent_granted',
      actorUserId: patientUserId,
      subjectUserId: patientUserId,
      resourceType: 'consent',
      resourceId,
      metadata: {
        patientId: consent.patient_user_id,
        doctorId: consent.doctor_user_id,
      },
    });

    return {
      id: `${consent.patient_user_id}:${consent.doctor_user_id}`,
      patientUserId: consent.patient_user_id,
      doctorUserId: consent.doctor_user_id,
      expiresAt: consent.expires_at,
      createdAt: consent.created_at,
    };
  }

  async revoke(patientUserId, doctorId) {
    const existing = await this.consentRepository.findActive(
      patientUserId,
      doctorId,
    );

    if (!existing) {
      throw new AppError(
        404,
        'Consent not found.',
        'CONSENT_NOT_FOUND',
      );
    }

    const revoked = await this.consentRepository.revoke({
      patientUserId,
      doctorUserId: doctorId,
      transactionHash: null,
    });

    if (!revoked) {
      throw new AppError(
        404,
        'Consent not found or already revoked.',
        'CONSENT_NOT_FOUND',
      );
    }

    // resource_id must be a UUID, not a patientUUID:doctorUUID pair.
    const resourceId = revoked.doctor_user_id;

    await this.auditService?.record({
      eventType: 'consent_revoked',
      actorUserId: patientUserId,
      subjectUserId: patientUserId,
      resourceType: 'consent',
      resourceId,
      metadata: {
        patientId: revoked.patient_user_id,
        doctorId: revoked.doctor_user_id,
      },
    });

    return {
      id: `${revoked.patient_user_id}:${revoked.doctor_user_id}`,
      patientUserId: revoked.patient_user_id,
      doctorUserId: revoked.doctor_user_id,
      revokedAt: revoked.revoked_at,
    };
  }

  async assertDoctorAccess(patientUserId, doctorUserId) {
    const consent = await this.consentRepository.findActive(
      patientUserId,
      doctorUserId,
    );

    if (!consent) {
      throw new AppError(
        403,
        'Valid patient consent is required to access these records.',
        'CONSENT_REQUIRED',
      );
    }
  }
}
