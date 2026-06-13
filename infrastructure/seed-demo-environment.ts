import * as fs from "fs";
import * as path from "path";
import { 
  S3Client, 
  PutObjectCommand, 
  ListObjectsV2Command 
} from "@aws-sdk/client-s3";
import { 
  CognitoIdentityProviderClient, 
  ListUserPoolsCommand, 
  ListUserPoolClientsCommand, 
  AdminGetUserCommand, 
  AdminCreateUserCommand, 
  AdminSetUserPasswordCommand, 
  AdminAddUserToGroupCommand,
  InitiateAuthCommand
} from "@aws-sdk/client-cognito-identity-provider";

// Resolve region
const region = "ap-south-1";

// Initialize AWS Clients using standard credential resolver chain
const s3Client = new S3Client({ region });
const cognitoClient = new CognitoIdentityProviderClient({ region });

// Setup clinical role user config
const defaultPassword = "HealthSecure@123";
const userConfigs = [
  // Admin (1)
  { email: "admin@healthsecure.com", role: "Admin" },
  // Doctors (5)
  { email: "doctor1@healthsecure.com", role: "Doctor" },
  { email: "doctor2@healthsecure.com", role: "Doctor" },
  { email: "doctor3@healthsecure.com", role: "Doctor" },
  { email: "doctor4@healthsecure.com", role: "Doctor" },
  { email: "doctor5@healthsecure.com", role: "Doctor" },
  // Nurses (3)
  { email: "nurse1@healthsecure.com", role: "Nurse" },
  { email: "nurse2@healthsecure.com", role: "Nurse" },
  { email: "nurse3@healthsecure.com", role: "Nurse" },
  // Analysts (2)
  { email: "analyst1@healthsecure.com", role: "Analyst" },
  { email: "analyst2@healthsecure.com", role: "Analyst" },
  // Receptionists (2)
  { email: "reception1@healthsecure.com", role: "Receptionist" },
  { email: "reception2@healthsecure.com", role: "Receptionist" }
];

// Helper to resolve API Gateway Ingest URL from Flutter AppConstants
function getApiBaseUrl(): string {
  if (process.env.API_BASE_URL) return process.env.API_BASE_URL;
  try {
    const constantsPath = path.join(__dirname, "../lib/core/constants/app_constants.dart");
    if (fs.existsSync(constantsPath)) {
      const content = fs.readFileSync(constantsPath, "utf8");
      const match = content.match(/apiBaseUrl\s*=\s*'([^']+)'/);
      if (match) return match[1];
    }
  } catch (_) {}
  return "https://5l6p1glnc3.execute-api.ap-south-1.amazonaws.com/prod/";
}

// Main execution function
async function run() {
  console.log("=========================================");
  console.log("STARTING AWS DEMO DATA SEEDER UTILITY");
  console.log("=========================================");

  try {
    // 1. Resolve Cognito User Pool and App Client IDs dynamically
    let userPoolId = process.env.COGNITO_USER_POOL_ID || "";
    let clientId = process.env.COGNITO_CLIENT_ID || "";

    if (!userPoolId) {
      console.log("Searching for Cognito User Pool 'healthsecure-user-pool'...");
      const pools = await cognitoClient.send(new ListUserPoolsCommand({ MaxResults: 60 }));
      const targetPool = pools.UserPools?.find(p => p.Name === "healthsecure-user-pool");
      if (targetPool?.Id) {
        userPoolId = targetPool.Id;
        console.log(`Found User Pool ID: ${userPoolId}`);
      } else {
        throw new Error("Cognito user pool 'healthsecure-user-pool' could not be resolved automatically.");
      }
    }

    if (!clientId) {
      console.log(`Searching for Client ID on User Pool: ${userPoolId}...`);
      const clients = await cognitoClient.send(new ListUserPoolClientsCommand({ UserPoolId: userPoolId, MaxResults: 60 }));
      const targetClient = clients.UserPoolClients?.find(c => c.ClientName === "healthsecure-app-client");
      if (targetClient?.ClientId) {
        clientId = targetClient.ClientId;
        console.log(`Found Client ID: ${clientId}`);
      } else if (clients.UserPoolClients && clients.UserPoolClients.length > 0) {
        clientId = clients.UserPoolClients[0].ClientId || "";
        console.log(`Fallback Client ID: ${clientId}`);
      } else {
        throw new Error("Cognito App Client could not be resolved automatically.");
      }
    }

    // 2. Discover S3 Bucket Names
    const rawBucketName = process.env.RAW_BUCKET_NAME || "healthsecure-raw-data";
    const quarantineBucketName = process.env.QUARANTINE_BUCKET_NAME || "healthsecure-quarantine";
    console.log(`Using S3 Raw Bucket: ${rawBucketName}`);
    console.log(`Using S3 Quarantine Bucket: ${quarantineBucketName}`);

    // 3. Resolve API Gateway Endpoint
    const apiBaseUrl = getApiBaseUrl();
    console.log(`Using API Base Url: ${apiBaseUrl}`);

    // 4. Create Cognito Users
    console.log("\nCreating Cognito Users...");
    let usersCreatedCount = 0;
    for (const config of userConfigs) {
      const email = config.email;
      const role = config.role;
      try {
        // Check if user exists
        await cognitoClient.send(new AdminGetUserCommand({
          UserPoolId: userPoolId,
          Username: email
        }));
        console.log(`- User already exists: ${email} (Role: ${role})`);
        // Reset password to HealthSecure@123 to ensure it is verified and log-in ready
        await cognitoClient.send(new AdminSetUserPasswordCommand({
          UserPoolId: userPoolId,
          Username: email,
          Password: defaultPassword,
          Permanent: true
        }));
      } catch (err: any) {
        if (err.name === "UserNotFoundException") {
          // Create User
          await cognitoClient.send(new AdminCreateUserCommand({
            UserPoolId: userPoolId,
            Username: email,
            UserAttributes: [
              { Name: "email", Value: email },
              { Name: "email_verified", Value: "true" }
            ],
            MessageAction: "SUPPRESS"
          }));
          
          // Set Permanent Password
          await cognitoClient.send(new AdminSetUserPasswordCommand({
            UserPoolId: userPoolId,
            Username: email,
            Password: defaultPassword,
            Permanent: true
          }));

          // Add User to Cognito Group/Role
          await cognitoClient.send(new AdminAddUserToGroupCommand({
            UserPoolId: userPoolId,
            Username: email,
            GroupName: role
          }));

          console.log(`- Created User: ${email} (Role: ${role})`);
          usersCreatedCount++;
        } else {
          console.error(`Error managing Cognito user ${email}:`, err);
        }
      }
    }

    // 5. Generate 50 Patients
    console.log("\nGenerating and Uploading Patients...");
    const firstNames = ["Marcus", "Sarah", "Elena", "Alan", "Ellie", "Arthur", "Jane", "John", "Clara", "Alice", "Robert", "James", "Patricia", "Jennifer", "Elizabeth", "William", "Linda", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Karen", "Christopher", "Nancy", "Daniel", "Lisa", "Matthew"];
    const lastNames = ["Brody", "Chen", "Rostova", "Grant", "Sattler", "Pendleton", "Doe", "Smith", "Barton", "Vance", "Mercer", "Green", "Geller", "Williams", "Brown", "Jones", "Miller", "Davis", "Garcia", "Rodriguez", "Wilson", "Martinez", "Anderson", "Taylor", "Thomas", "Moore", "Jackson", "White", "Harris", "Martin"];
    const bloodGroups = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"];
    const insuranceProviders = ["Blue Cross Blue Shield", "Aetna", "UnitedHealthcare", "Cigna", "Humana", "Medicare"];
    const genders = ["Male", "Female", "Other"];
    const doctorNames = ["Dr. Marcus Brody", "Dr. Sarah Chen", "Dr. Elena Rostova", "Dr. Alan Grant", "Dr. Ellie Sattler"];
    const doctorEmails = ["doctor1@healthsecure.com", "doctor2@healthsecure.com", "doctor3@healthsecure.com", "doctor4@healthsecure.com", "doctor5@healthsecure.com"];

    const patientList: any[] = [];
    for (let i = 0; i < 50; i++) {
      const fn = firstNames[i % firstNames.length];
      const ln = lastNames[i % lastNames.length];
      const name = `${fn} ${ln}`;
      const patientId = `PT-${100 + i}`;
      const mrn = `MRN-${8000 + i}-${10 + (i % 90)}`;
      const phone = `+1 (555) 019-92${i.toString().padStart(2, "0")}`;
      const address = `${100 + i * 7} Clinical Parkway, Suite ${i + 1}, Seattle, WA 98101`;
      const bloodGroup = bloodGroups[i % bloodGroups.length];
      const insuranceProvider = insuranceProviders[i % insuranceProviders.length];
      const emergencyContact = `${lastNames[(i + 1) % lastNames.length]} (Spouse) - +1 (555) 019-99${(99 - i).toString().padStart(2, "0")}`;
      const dob = `19${50 + (i % 45)}-${((i % 12) + 1).toString().padStart(2, "0")}-${((i % 28) + 1).toString().padStart(2, "0")}`;
      const gender = genders[i % genders.length];
      const primaryCarePhysician = doctorNames[i % doctorNames.length];

      const patientData = {
        patientId,
        mrn,
        name,
        dob,
        gender,
        phone,
        address,
        bloodGroup,
        insuranceProvider,
        emergencyContact,
        primaryCarePhysician,
        consentStatus: "signed",
        isDataEncrypted: true,
        lastAuditDate: new Date().toISOString(),
        complianceScore: 100.0
      };

      patientList.push(patientData);

      // Upload patient record directly to S3 (Idempotent: writes to PT-XXX-seed.json key)
      const fileKey = `raw-patient-data/${patientId}-seed.json`;
      await s3Client.send(new PutObjectCommand({
        Bucket: rawBucketName,
        Key: fileKey,
        Body: JSON.stringify(patientData, null, 2),
        ContentType: "application/json",
        ServerSideEncryption: "aws:kms"
      }));
    }
    console.log(`- Uploaded 50 patient records to raw-patient-data/`);

    // 6. Generate 150 Visits
    console.log("\nGenerating and Uploading Visits...");
    const chiefComplaints = [
      "Routine annual exam", "Chest tightness & shortness of breath", "Diabetes HbA1c review",
      "Persistent dry cough for 2 weeks", "Severe migraine headaches", "Chronic lower back pain",
      "Follow-up post-cardiac stent", "Fever & sore throat", "Joint pain and knee swelling",
      "Abdominal discomfort & nausea", "Allergy evaluation", "Blood pressure calibration"
    ];
    const diagnoses = [
      "Essential hypertension", "Type 2 diabetes mellitus", "Acute viral bronchitis",
      "Migraine without aura", "Lumbago with sciatica", "Hyperlipidemia, mixed",
      "Acute pharyngitis", "Osteoarthritis of knee", "Gastroesophageal reflux disease",
      "Normal physical checkup", "Allergic rhinitis, unspecified"
    ];

    for (let i = 0; i < 150; i++) {
      const patient = patientList[i % patientList.length];
      const docIndex = i % doctorNames.length;
      const docName = doctorNames[docIndex];
      const docEmail = doctorEmails[docIndex];
      
      const complaint = chiefComplaints[i % chiefComplaints.length];
      const dx = diagnoses[i % diagnoses.length];
      const visitDate = new Date();
      visitDate.setDate(visitDate.getDate() - (i % 90)); // trailing 90 days
      const followUpDate = new Date(visitDate);
      followUpDate.setDate(followUpDate.getDate() + 30);

      const visitData = {
        id: `VS-${1000 + i}`,
        patientId: patient.patientId,
        patientName: patient.name,
        mrn: patient.mrn,
        providerName: docName,
        visitDate: visitDate.toISOString(),
        syncStatus: "synced",
        hasPhysicianSignature: true,
        billingCoded: true,
        complianceCleared: true,
        notes: `Chief Complaint: ${complaint}. Clinical Assessment & Diagnosis: ${dx}.`,
        doctorId: docEmail,
        chiefComplaint: complaint,
        diagnosis: dx,
        followUpDate: followUpDate.toISOString()
      };

      const fileKey = `visits/VS-${1000 + i}-seed.json`;
      await s3Client.send(new PutObjectCommand({
        Bucket: rawBucketName,
        Key: fileKey,
        Body: JSON.stringify(visitData, null, 2),
        ContentType: "application/json",
        ServerSideEncryption: "aws:kms"
      }));
    }
    console.log(`- Uploaded 150 visit records to visits/`);

    // 7. Generate 300 Vitals (Mixed normal/abnormal)
    console.log("\nGenerating and Uploading Vitals...");
    for (let i = 0; i < 300; i++) {
      const patient = patientList[i % patientList.length];
      const generateAbnormal = (i % 4 === 0); // 25% abnormal readings
      
      let systolic, diastolic, hr, spo2, glucose, temp;
      const height = 150 + (i % 40); // 150 to 190 cm
      const weight = 50 + (i % 60);  // 50 to 110 kg
      const bmi = parseFloat((weight / Math.pow(height / 100, 2)).toFixed(1));

      if (generateAbnormal) {
        // High BP or Low BP
        if (i % 2 === 0) {
          systolic = 140 + (i % 30);
          diastolic = 90 + (i % 15);
        } else {
          systolic = 80 + (i % 9);
          diastolic = 50 + (i % 9);
        }
        hr = (i % 2 === 0) ? 50 - (i % 5) : 105 + (i % 20); // bradycardia vs tachycardia
        temp = (i % 2 === 0) ? 96.0 - (i % 10) / 10 : 100.8 + (i % 20) / 10;
        spo2 = 88 + (i % 7); // low oxygen
        glucose = 145 + (i % 100);
      } else {
        // Normal vitals bounds
        systolic = 110 + (i % 15);
        diastolic = 72 + (i % 10);
        hr = 65 + (i % 25);
        temp = 97.4 + (i % 15) / 10;
        spo2 = 96 + (i % 4);
        glucose = 80 + (i % 40);
      }

      const recordedAt = new Date();
      recordedAt.setDate(recordedAt.getDate() - (i % 90));

      const vitalsData = {
        vitalsId: `VTL-${5000 + i}`,
        patientId: patient.patientId,
        bloodPressure: `${systolic}/${diastolic}`,
        heartRate: hr,
        temperature: parseFloat(temp.toFixed(1)),
        spo2,
        weight,
        height,
        bmi,
        bloodSugar: glucose,
        recordedAt: recordedAt.toISOString()
      };

      const fileKey = `vitals/VTL-${5000 + i}-seed.json`;
      await s3Client.send(new PutObjectCommand({
        Bucket: rawBucketName,
        Key: fileKey,
        Body: JSON.stringify(vitalsData, null, 2),
        ContentType: "application/json",
        ServerSideEncryption: "aws:kms"
      }));
    }
    console.log(`- Uploaded 300 vitals records to vitals/`);

    // 8. Generate 15 Invalid Records
    console.log("\nGenerating and Uploading Invalid Records (to trigger Validation Lambda & Quarantine)...");
    const invalidRecords = [
      // 4 records missing patientId
      ...Array.from({ length: 4 }).map((_, idx) => ({
        name: `Invalid Patient ID Check ${idx}`,
        dob: "1980-05-12",
        gender: "Male",
        phone: "+1 (555) 123-4567",
        address: "123 Clinical Way",
        bloodGroup: "O+",
        insuranceProvider: "Medicare",
        emergencyContact: "None",
        bloodPressure: "120/80",
        weight: 70.0
      })),
      // 4 records with negative weight
      ...Array.from({ length: 4 }).map((_, idx) => ({
        patientId: `PT-99${idx}`,
        name: `Invalid Negative Weight Check ${idx}`,
        dob: "1980-05-12",
        gender: "Female",
        phone: "+1 (555) 123-4567",
        address: "123 Clinical Way",
        bloodGroup: "O+",
        insuranceProvider: "Medicare",
        emergencyContact: "None",
        bloodPressure: "120/80",
        weight: -70.0 - idx
      })),
      // 4 records with invalid BP format
      ...Array.from({ length: 4 }).map((_, idx) => ({
        patientId: `PT-99${idx + 4}`,
        name: `Invalid BP Format Check ${idx}`,
        dob: "1980-05-12",
        gender: "Other",
        phone: "+1 (555) 123-4567",
        address: "123 Clinical Way",
        bloodGroup: "O+",
        insuranceProvider: "Medicare",
        emergencyContact: "None",
        bloodPressure: `BP_ERROR_${idx}`,
        weight: 70.0
      })),
      // 3 records with invalid phone formats
      ...Array.from({ length: 3 }).map((_, idx) => ({
        patientId: `PT-99${idx + 8}`,
        name: `Invalid Phone Length Check ${idx}`,
        dob: "1980-05-12",
        gender: "Male",
        phone: "123", // too short
        address: "123 Clinical Way",
        bloodGroup: "O+",
        insuranceProvider: "Medicare",
        emergencyContact: "None",
        bloodPressure: "120/80",
        weight: 70.0
      }))
    ];

    for (let i = 0; i < invalidRecords.length; i++) {
      const fileKey = `raw/invalid-seed/invalid-${i}.json`;
      await s3Client.send(new PutObjectCommand({
        Bucket: rawBucketName,
        Key: fileKey,
        Body: JSON.stringify(invalidRecords[i], null, 2),
        ContentType: "application/json",
        ServerSideEncryption: "aws:kms"
      }));
    }
    console.log(`- Uploaded 15 invalid validation-failing records to raw/invalid-seed/`);

    // 9. Generate CloudTrail Cognito Authentication Audits & Tokens
    console.log("\nGenerating Cognito Login Events & Fetching Auth Tokens...");
    const authTokens: string[] = [];
    for (const config of userConfigs.slice(0, 5)) { // Login a subset of users to prevent spam
      const email = config.email;
      try {
        const authResponse = await cognitoClient.send(new InitiateAuthCommand({
          ClientId: clientId,
          AuthFlow: "USER_PASSWORD_AUTH",
          AuthParameters: {
            USERNAME: email,
            PASSWORD: defaultPassword
          }
        }));
        console.log(`- Cognito login audit successfully generated for: ${email}`);
        if (authResponse.AuthenticationResult?.AccessToken) {
          authTokens.push(authResponse.AuthenticationResult.AccessToken);
        }
      } catch (err: any) {
        console.warn(`- Failed authentication login audit for ${email}:`, err.message || err);
      }
    }

    // 10. Generate CloudWatch metrics by calling REST API Gateway
    console.log("\nExecuting Sample HTTP API Gateway Requests (generating CloudWatch Telemetry)...");
    let apiRequestsTriggered = 0;
    const sampleToken = authTokens[0] || "";

    // A. POST /patient API Requests (Valid)
    const apiPatientData = {
      patientId: "PT-901",
      name: "API Test Patient",
      dob: "1985-05-12",
      gender: "Male",
      phone: "+1 (555) 123-4567",
      address: "128 Ingress Lane, API City, WA 98101",
      bloodGroup: "A+",
      insuranceProvider: "Medicare",
      emergencyContact: "None"
    };

    try {
      const patientResponse = await fetch(`${apiBaseUrl}patient`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(sampleToken ? { "Authorization": `Bearer ${sampleToken}` } : {})
        },
        body: JSON.stringify(apiPatientData)
      });
      console.log(`- Ingest Gateway POST /patient completed. Status: ${patientResponse.status}`);
      apiRequestsTriggered++;
    } catch (err: any) {
      console.warn("- Warning: Ingest API Gateway POST /patient endpoint unreachable:", err.message || err);
    }

    // B. POST /patient API Requests (Invalid to generate 400s)
    const apiBadPatientData = { ...apiPatientData, patientId: "BAD_ID_FORMAT" };
    try {
      const patientBadResponse = await fetch(`${apiBaseUrl}patient`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(sampleToken ? { "Authorization": `Bearer ${sampleToken}` } : {})
        },
        body: JSON.stringify(apiBadPatientData)
      });
      console.log(`- Ingest Gateway POST /patient (Invalid) completed. Status: ${patientBadResponse.status}`);
      apiRequestsTriggered++;
    } catch (_) {}

    // C. POST /visit and POST /vitals (Mock API Gatway endpoints)
    try {
      const visitRes = await fetch(`${apiBaseUrl}visit`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: "CloudWatch API Test" })
      });
      console.log(`- Gateway Mock POST /visit completed. Status: ${visitRes.status}`);
      apiRequestsTriggered++;

      const vitalsRes = await fetch(`${apiBaseUrl}vitals`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: "CloudWatch API Test" })
      });
      console.log(`- Gateway Mock POST /vitals completed. Status: ${vitalsRes.status}`);
      apiRequestsTriggered++;
    } catch (_) {}

    // 11. Bounded Wait for asynchronous S3 notifications/Lambdas to complete quarantine processing
    const waitTimeSeconds = 10;
    console.log(`\nWaiting ${waitTimeSeconds} seconds for AWS S3 Lambda trigger quarantine events to settle...`);
    await new Promise(resolve => setTimeout(resolve, waitTimeSeconds * 1000));

    // 12. Check Quarantine Bucket Count
    console.log("\nVerifying Quarantine files...");
    let quarantineRecordsCount = 0;
    try {
      const listRes = await s3Client.send(new ListObjectsV2Command({
        Bucket: quarantineBucketName,
        Prefix: "quarantine-records/"
      }));
      quarantineRecordsCount = listRes.Contents?.length || 0;
      console.log(`- Found ${quarantineRecordsCount} records in quarantine bucket.`);
    } catch (err: any) {
      console.warn("- Warning: Could not list quarantine bucket items:", err.message || err);
    }

    console.log("\n=========================================");
    console.log("SEED COMPLETED SUCCESSFULLY");
    console.log("=========================================");
    
    // Print Verification Report
    console.log("\n--- VERIFICATION REPORT ---");
    console.log(`Users Created               : ${usersCreatedCount} (Cognito UserPool: ${userPoolId})`);
    console.log(`Patients Created            : 50 (S3 raw-patient-data/)`);
    console.log(`Visits Created              : 150 (S3 visits/)`);
    console.log(`Vitals Created              : 300 (S3 vitals/)`);
    console.log(`Invalid Records Created     : 15 (S3 raw/invalid-seed/)`);
    console.log(`Files Found In Quarantine   : ${quarantineRecordsCount} (S3 quarantine-records/)`);
    console.log(`CloudWatch Metrics Generated: ${apiRequestsTriggered} API Gateway / Lambda invoker checks`);
    console.log("---------------------------\n");

  } catch (error: any) {
    console.error("\nCRITICAL SEEDER UTILITY EXCEPTION ERROR:");
    console.error(error.message || error);
    process.exit(1);
  }
}

// Execute Seeder
run();
