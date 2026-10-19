"use client";

import { useEffect, useState } from "react";
import Sidebar from "./Sidebar";

const PORTAL_LABELS = {
  admin: "Admin Portal",
  patient: "Patient Portal",
  doctor: "Doctor Portal",
  pharmacy: "Pharmacy Portal",
};

function getStoredUser() {
  try {
    return JSON.parse(window.localStorage.getItem("sch_user") || "null");
  } catch {
    return null;
  }
}

export default function PortalShell({
  role,
  eyebrow,
  title,
  subtitle,
  children,
}) {
  const [user, setUser] = useState(null);

  useEffect(() => {
    const storedUser = getStoredUser();

    if (storedUser?.role && storedUser.role !== role) {
      setUser(null);
      return;
    }

    setUser(storedUser);
  }, [role]);

  const portalLabel = PORTAL_LABELS[role] || "MediVault Portal";
  const userLabel =
    user?.name ||
    user?.fullName ||
    user?.email ||
    (role ? role.charAt(0).toUpperCase() + role.slice(1) : "User");

  const userEmail = user?.email || "";
  const userMedicalId = user?.license_id || "";

  return (
    <div className="shell">
      <Sidebar role={role} userLabel={userLabel} userEmail={userEmail} />

      <main className="main">
        <div
          className="topbar"
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: 16,
            flexWrap: "wrap",
          }}
        >
          <div style={{ minWidth: 0, flex: "1 1 260px" }}>
            <p className="eyebrow" style={{ marginBottom: 6 }}>
              {eyebrow || portalLabel}
            </p>

            <h1 className="page-title">{title}</h1>

            {subtitle && <p className="page-sub">{subtitle}</p>}
          </div>
        </div>
        {children}
      </main>
    </div>
  );
}
