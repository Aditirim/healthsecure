import * as fs from "fs";
import * as path from "path";
import { 
  S3Client, 
  ListObjectsV2Command, 
  GetObjectCommand, 
  PutObjectCommand, 
  DeleteObjectCommand 
} from "@aws-sdk/client-s3";

const region = "ap-south-1";
const s3Client = new S3Client({ region });

const rawBucketName = process.env.RAW_BUCKET_NAME || "healthsecure-raw-data";
const quarantineBucketName = process.env.QUARANTINE_BUCKET_NAME || "healthsecure-quarantine";

// Validation helper functions matching Lambda new logic
function validateRecord(record: any, key: string): string[] {
  let entityType = "patient"; // default
  if (record.entityType) {
    entityType = record.entityType.toLowerCase();
  } else if (key.startsWith("raw-patient-data/")) {
    entityType = "patient";
  } else if (key.startsWith("visits/")) {
    entityType = "visit";
  } else if (key.startsWith("vitals/")) {
    entityType = "vitals";
  } else if (record.visitId || record.visitID || record.physician || record.providerName) {
    entityType = "visit";
  } else if (record.vitalsId || record.vitalsID || record.temperature !== undefined || record.spo2 !== undefined) {
    entityType = "vitals";
  } else if (record.patientId && record.dob && record.gender) {
    entityType = "patient";
  }

  const errors: string[] = [];

  const validatePhone = (phoneFieldVal: any, fieldName: string) => {
    if (phoneFieldVal !== undefined && phoneFieldVal !== null && phoneFieldVal.toString().trim() !== "") {
      const normalized = phoneFieldVal.toString().replace(/[\s()+-]/g, "");
      const phoneRegex = /^\d{8,15}$/;
      if (!phoneRegex.test(normalized)) {
        errors.push(`Rule Violation: Field '${fieldName}' value '${phoneFieldVal}' is invalid. Normalized value '${normalized}' must contain between 8 and 15 digits.`);
      }
    }
  };

  const validateBP = (bpFieldVal: any, fieldName: string) => {
    if (bpFieldVal !== undefined && bpFieldVal !== null && bpFieldVal.toString().trim() !== "") {
      const bpRegex = /^\d{2,3}\/\d{2,3}$/;
      if (!bpRegex.test(bpFieldVal.toString().trim())) {
        errors.push(`Rule Violation: Blood Pressure field '${fieldName}' value '${bpFieldVal}' must strictly match 'Systolic/Diastolic' format (e.g., '120/80').`);
      }
    }
  };

  const validateWeight = (weightVal: any, fieldName: string) => {
    if (weightVal !== undefined && weightVal !== null && weightVal.toString().trim() !== "") {
      const parsedWeight = parseFloat(weightVal);
      if (isNaN(parsedWeight) || parsedWeight <= 0) {
        errors.push(`Rule Violation: Field '${fieldName}' must be a positive number. Got: '${weightVal}'.`);
      }
    }
  };

  if (entityType === "patient") {
    const patientId = record.patientId || record.patientID || record.id;
    if (!patientId || patientId.toString().trim() === "") {
      errors.push("Rule Violation: Patient ID is required and cannot be blank.");
    } else {
      const patientIdRegex = /^PT-\d+$/;
      if (!patientIdRegex.test(patientId.toString().trim())) {
        errors.push(`Rule Violation: Patient ID '${patientId}' must match the clinical PT-number structure (e.g., 'PT-107').`);
      }
    }

    const name = record.name;
    if (!name || name.toString().trim() === "") {
      errors.push("Rule Violation: Name is required and cannot be blank.");
    }

    const dob = record.dob || record.dateOfBirth;
    if (!dob || dob.toString().trim() === "") {
      errors.push("Rule Violation: Date of Birth is required and cannot be blank.");
    }

    const gender = record.gender;
    if (!gender || gender.toString().trim() === "") {
      errors.push("Rule Violation: Gender is required and cannot be blank.");
    }

    // Optional validations
    const phone = record.phone || record.phoneNumber;
    if (phone !== undefined && phone !== null) {
      validatePhone(phone, "phone");
    }
    
    const emergencyContact = record.emergencyContact;
    if (emergencyContact !== undefined && emergencyContact !== null) {
      const phoneMatch = emergencyContact.toString().match(/\+?\d[\d\s()+-]{7,20}/);
      if (phoneMatch) {
        validatePhone(phoneMatch[0], "emergencyContactPhone");
      }
    }

    const bp = record.bloodPressure || record.bp;
    validateBP(bp, "bloodPressure");

    const weight = record.weight;
    validateWeight(weight, "weight");

  } else if (entityType === "visit") {
    const visitId = record.visitId || record.id;
    if (!visitId || visitId.toString().trim() === "") {
      errors.push("Rule Violation: Visit ID (visitId) is required and cannot be blank.");
    }

    const patientId = record.patientId;
    if (!patientId || patientId.toString().trim() === "") {
      errors.push("Rule Violation: Patient ID (patientId) is required and cannot be blank.");
    }

    const physician = record.physician || record.providerName;
    if (!physician || physician.toString().trim() === "") {
      errors.push("Rule Violation: Physician/Provider Name is required and cannot be blank.");
    }

    const visitDate = record.visitDate || record.date;
    if (!visitDate || visitDate.toString().trim() === "") {
      errors.push("Rule Violation: Visit Date (visitDate) is required and cannot be blank.");
    }

  } else if (entityType === "vitals") {
    const vitalsId = record.vitalsId || record.id;
    if (!vitalsId || vitalsId.toString().trim() === "") {
      errors.push("Rule Violation: Vitals ID (vitalsId) is required and cannot be blank.");
    }

    const patientId = record.patientId;
    if (!patientId || patientId.toString().trim() === "") {
      errors.push("Rule Violation: Patient ID (patientId) is required and cannot be blank.");
    }

    const bp = record.bloodPressure || record.bp;
    validateBP(bp, "bloodPressure");

    const weight = record.weight;
    validateWeight(weight, "weight");

    const phone = record.phone || record.phoneNumber;
    validatePhone(phone, "phone");
  }

  return errors;
}

async function run() {
  console.log("=========================================");
  console.log("STARTING REMEDIATION REPAIR UTILITY");
  console.log("=========================================");

  try {
    let totalProcessed = 0;
    let falsePositivesRecovered = 0;
    let invalidRemaining = 0;

    // 1. List objects in quarantine bucket under prefix quarantine-records/
    console.log(`Listing objects in quarantine bucket '${quarantineBucketName}'...`);
    const listRes = await s3Client.send(new ListObjectsV2Command({
      Bucket: quarantineBucketName,
      Prefix: "quarantine-records/"
    }));

    const contents = listRes.Contents || [];
    console.log(`Found ${contents.length} objects in quarantine bucket prefix.`);

    for (const object of contents) {
      if (!object.Key) continue;
      totalProcessed++;

      // 2. Get quarantined object
      const getRes = await s3Client.send(new GetObjectCommand({
        Bucket: quarantineBucketName,
        Key: object.Key
      }));

      const bodyStr = await getRes.Body?.transformToString() || "";
      let quarantinePayload: any;
      try {
        quarantinePayload = JSON.parse(bodyStr);
      } catch (_) {
        // Not a standard quarantine format or invalid JSON, skip or count as invalid
        console.warn(`- Skipping malformed quarantine JSON: ${object.Key}`);
        invalidRemaining++;
        continue;
      }

      // Extract original details
      const payload = quarantinePayload.payload || quarantinePayload;
      const originalSource = quarantinePayload.originalSource || {
        bucket: rawBucketName,
        key: `raw-patient-data/${object.Key.split("/").pop()}`
      };

      // 3. Re-validate payload using the new entity-aware engine
      const validationErrors = validateRecord(payload, originalSource.key);

      if (validationErrors.length === 0) {
        // False Positive! Let's restore the record back to healthsecure-raw-data
        console.log(`- Falsely Quarantined Record Found: ${originalSource.key}. Restoring...`);
        
        await s3Client.send(new PutObjectCommand({
          Bucket: rawBucketName,
          Key: originalSource.key,
          Body: JSON.stringify(payload, null, 2),
          ContentType: "application/json",
          ServerSideEncryption: "aws:kms"
        }));

        // Delete from quarantine bucket
        await s3Client.send(new DeleteObjectCommand({
          Bucket: quarantineBucketName,
          Key: object.Key
        }));

        console.log(`  Successfully restored S3 object and pruned from quarantine vault.`);
        falsePositivesRecovered++;
      } else {
        // Record is indeed invalid under new rules. Keep in quarantine
        console.log(`- Record is genuinely invalid: ${originalSource.key}. Errors: ${validationErrors.join(", ")}`);
        invalidRemaining++;
      }
    }

    // 4. Sleep to let S3 ingestion notifications settle
    console.log("\nWaiting 5 seconds for S3 notifications to finish processing...");
    await new Promise(resolve => setTimeout(resolve, 5000));

    // 5. Query raw bucket counts to generate Data Quality Report
    console.log("\nQuerying S3 raw bucket for active records counts...");
    const rawListRes = await s3Client.send(new ListObjectsV2Command({
      Bucket: rawBucketName
    }));
    const rawContents = rawListRes.Contents || [];

    let totalPatients = 0;
    let totalVisits = 0;
    let totalVitals = 0;

    for (const obj of rawContents) {
      if (!obj.Key) continue;
      if (obj.Key.startsWith("raw-patient-data/")) totalPatients++;
      else if (obj.Key.startsWith("visits/")) totalVisits++;
      else if (obj.Key.startsWith("vitals/")) totalVitals++;
    }

    const validRecords = totalPatients + totalVisits + totalVitals;

    // Remaining quarantine files count
    const finalQuarantineList = await s3Client.send(new ListObjectsV2Command({
      Bucket: quarantineBucketName,
      Prefix: "quarantine-records/"
    }));
    const quarantinedRecords = finalQuarantineList.Contents?.length || 0;

    // Output Audit Report JSON
    const reportData = {
      totalPatients,
      totalVisits,
      totalVitals,
      validRecords,
      quarantinedRecords,
      falsePositivesDetected: falsePositivesRecovered,
      falsePositivesRecovered
    };

    const reportPath = path.join(__dirname, "validation-audit-report.json");
    fs.writeFileSync(reportPath, JSON.stringify(reportData, null, 2), "utf8");
    console.log(`Audit report generated at: ${reportPath}`);

    // Print Console Summary
    console.log("\n=========================================");
    console.log("REMEDIATION COMPLETED SUCCESSFULLY");
    console.log("=========================================");
    console.log(`Valid Restored   : ${falsePositivesRecovered}`);
    console.log(`Invalid Remaining: ${quarantinedRecords}`);
    console.log(`Total Processed  : ${totalProcessed}`);
    console.log("-----------------------------------------");
    console.log(`Patients Active  : ${totalPatients}`);
    console.log(`Visits Active    : ${totalVisits}`);
    console.log(`Vitals Active    : ${totalVitals}`);
    console.log(`Total Active Raw : ${validRecords}`);
    console.log("=========================================\n");

  } catch (err: any) {
    console.error("\nCRITICAL REMEDIATION EXCEPTION ERROR:");
    console.error(err.message || err);
    process.exit(1);
  }
}

run();
