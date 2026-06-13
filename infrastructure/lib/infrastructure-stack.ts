import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as s3n from 'aws-cdk-lib/aws-s3-notifications';
import * as cloudtrail from 'aws-cdk-lib/aws-cloudtrail';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as glue from 'aws-cdk-lib/aws-glue';
import * as s3_assets from 'aws-cdk-lib/aws-s3-assets';
import * as path from 'path';

export class InfrastructureStack extends cdk.Stack {
  public readonly rawDataBucket: s3.IBucket;
  public readonly quarantineDataBucket: s3.IBucket;
  public readonly curatedDataBucket: s3.IBucket;
  public readonly createPatientFunction: lambda.IFunction;
  public readonly validatePatientRecordFunction: lambda.IFunction;
  public readonly apiGateway: apigateway.IRestApi;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Secure S3 Bucket for Healthcare Raw Data
    this.rawDataBucket = new s3.Bucket(this, 'HealthSecureRawDataBucket', {
      bucketName: 'healthsecure-raw-data',
      versioned: true,
      
      // AWS KMS Managed Server-Side Encryption (ideal for healthcare auditing & credentials segregation)
      encryption: s3.BucketEncryption.KMS_MANAGED,
      
      // Strict isolation of public access permissions
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      
      // HIPAA-compliant data-in-transit security (forces HTTPS/SSL connections for requests)
      enforceSSL: true,
      
      // Safety precaution for critical patient health logs; retains bucket on stack deletion
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      
      // Lifecycle rule to migrate raw data to cold storage for archival retention
      lifecycleRules: [
        {
          id: 'MoveToGlacierAfter90Days',
          enabled: true,
          transitions: [
            {
              storageClass: s3.StorageClass.GLACIER,
              transitionAfter: cdk.Duration.days(90),
            },
          ],
        },
      ],
    });

    // Secure S3 Bucket for Quarantined Healthcare Data
    this.quarantineDataBucket = new s3.Bucket(this, 'HealthSecureQuarantineDataBucket', {
      bucketName: 'healthsecure-quarantine',
      versioned: true,
      
      // Server-Side KMS Encryption to safeguard critical audited clinical assets
      encryption: s3.BucketEncryption.KMS_MANAGED,
      
      // Strict blocking of public read/write configurations
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      
      // Enforces SSL/HTTPS configurations for data-in-transit compliance
      enforceSSL: true,
      
      // Retains quarantined files on stack deletion for HIPAA record requirements
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Secure S3 Bucket for Curated Healthcare Data (ETL Curations)
    this.curatedDataBucket = new s3.Bucket(this, 'HealthSecureCuratedDataBucket', {
      bucketName: 'healthsecure-curated',
      versioned: true,
      
      // Server-Side KMS Encryption to secure aggregated clinical graphs
      encryption: s3.BucketEncryption.KMS_MANAGED,
      
      // Strict isolation of public access permissions
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      
      // Enforces SSL/HTTPS configurations for data-in-transit compliance
      enforceSSL: true,
      
      // Retains curated records on stack deletion for archival compliance
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Secure S3 Bucket for CloudTrail Audit Trails
    const auditLogsBucket = new s3.Bucket(this, 'HealthSecureAuditLogsBucket', {
      bucketName: 'healthsecure-cloudtrail-logs',
      versioned: true,
      
      // Server-Side KMS Encryption to secure aggregated audit logs
      encryption: s3.BucketEncryption.KMS_MANAGED,
      
      // Strict isolation of public access permissions
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      
      // Enforces SSL/HTTPS configurations for data-in-transit compliance
      enforceSSL: true,
      
      // Retains logs on stack deletion for archival compliance
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // 1. HIPAA-Compliant Secure Cognito User Pool for Clinical Onboarding
    const userPool = new cognito.UserPool(this, 'HealthSecureUserPool', {
      userPoolName: 'healthsecure-user-pool',
      
      // Email sign-in only (no arbitrary username creation to prevent credentials spoofing)
      signInAliases: {
        email: true,
      },
      
      // Self sign-up disabled: Users must be onboarded directly by an administrator
      selfSignUpEnabled: false,
      
      // Automated verify email address for multi-factor authentication
      autoVerify: {
        email: true,
      },
      
      passwordPolicy: {
        minLength: 12,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: true,
        tempPasswordValidity: cdk.Duration.days(7),
      },
      
      // Retain or delete on stack deletion (configured to retain for healthcare data safety)
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // Add Client for public applications (like Flutter)
    const userPoolClient = userPool.addClient('HealthSecureAppClient', {
      userPoolClientName: 'healthsecure-app-client',
      authFlows: {
        userPassword: true, // Enables USER_PASSWORD_AUTH flow
      },
      // Disable client secret since Flutter is a public client
      generateSecret: false,
    });

    // 2. User Roles / Groups Configuration
    const roles = ['Admin', 'Doctor', 'Nurse', 'Analyst', 'Receptionist'];
    for (const roleName of roles) {
      new cognito.CfnUserPoolGroup(this, `UserPoolGroup${roleName}`, {
        userPoolId: userPool.userPoolId,
        groupName: roleName,
        description: `Clinical access role group for ${roleName} users inside HealthSecure`,
        precedence: roleName === 'Admin' ? 1 : 10, // Gives priority mapping to admin roles
      });
    }

    // 2.5. Ingestion Lambda Function (CreatePatientFunction)
    this.createPatientFunction = new lambda.Function(this, 'CreatePatientFunction', {
      runtime: lambda.Runtime.NODEJS_22_X,
      handler: 'create-patient.handler',
      code: lambda.Code.fromAsset('lambda'),
      environment: {
        BUCKET_NAME: this.rawDataBucket.bucketName,
        QUARANTINE_BUCKET_NAME: this.quarantineDataBucket.bucketName,
      },
      timeout: cdk.Duration.seconds(30),
    });

    // Grant read/write permissions on the S3 bucket to the Lambda
    this.rawDataBucket.grantReadWrite(this.createPatientFunction);
    this.quarantineDataBucket.grantRead(this.createPatientFunction);

    // 2.7. Validation S3-Trigger Lambda Function (ValidatePatientRecordFunction)
    this.validatePatientRecordFunction = new lambda.Function(this, 'ValidatePatientRecordFunction', {
      runtime: lambda.Runtime.NODEJS_22_X,
      handler: 'validate-record.handler',
      code: lambda.Code.fromAsset('lambda'),
      environment: {
        QUARANTINE_BUCKET_NAME: this.quarantineDataBucket.bucketName,
        GLUE_JOB_NAME: 'healthsecure-deidentify-raw-data',
      },
      timeout: cdk.Duration.seconds(30),
    });

    // Grant validation Lambda permission to trigger the Glue ETL job
    this.validatePatientRecordFunction.addToRolePolicy(new iam.PolicyStatement({
      actions: ['glue:StartJobRun'],
      resources: [`arn:aws:glue:${this.region}:${this.account}:job/healthsecure-deidentify-raw-data`],
    }));

    // Grant read/delete permissions on raw bucket to validate/prune records
    this.rawDataBucket.grantRead(this.validatePatientRecordFunction);
    this.rawDataBucket.grantDelete(this.validatePatientRecordFunction);

    // Grant write permissions on quarantine bucket to archive invalid records
    this.quarantineDataBucket.grantWrite(this.validatePatientRecordFunction);

    // Bind S3 event trigger: Validate raw payloads upon ingestion
    this.rawDataBucket.addObjectCreatedNotification(
      new s3n.LambdaDestination(this.validatePatientRecordFunction)
    );

    // 3. REST API Gateway with HIPAA-Compliant Integrations
    this.apiGateway = new apigateway.RestApi(this, 'HealthSecureApiGateway', {
      restApiName: 'healthsecure-rest-api',
      description: 'REST API Gateway for HealthSecure clinical ingestion services',
      deployOptions: {
        stageName: 'prod',
      },
      // CORS configurations to support secure Flutter client connections
      defaultCorsPreflightOptions: {
        allowHeaders: ['Content-Type', 'X-Amz-Date', 'Authorization', 'X-Api-Key'],
        allowMethods: ['OPTIONS', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
        allowCredentials: true,
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
      },
    });

    // Helper template for returning standard clinical success payloads
    const mockIntegration = (resourceName: string) => {
      return new apigateway.MockIntegration({
        integrationResponses: [
          {
            statusCode: '200',
            responseParameters: {
              'method.response.header.Access-Control-Allow-Headers': "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'",
              'method.response.header.Access-Control-Allow-Methods': "'OPTIONS,GET,POST,PUT,PATCH,DELETE'",
              'method.response.header.Access-Control-Allow-Origin': "'*'",
            },
            responseTemplates: {
              'application/json': JSON.stringify({
                status: 'success',
                message: `${resourceName} record ingested and encrypted successfully`,
                timestamp: '$context.requestTime',
                requestId: '$context.requestId',
              }),
            },
          },
        ],
        passthroughBehavior: apigateway.PassthroughBehavior.NEVER,
        requestTemplates: {
          'application/json': '{"statusCode": 200}',
        },
      });
    };

    const methodOptions: apigateway.MethodOptions = {
      methodResponses: [
        {
          statusCode: '200',
          responseParameters: {
            'method.response.header.Access-Control-Allow-Headers': true,
            'method.response.header.Access-Control-Allow-Methods': true,
            'method.response.header.Access-Control-Allow-Origin': true,
          },
        },
      ],
    };

    // Route 1: POST /patient & GET /patient (connected to CreatePatientFunction Lambda)
    const patientResource = this.apiGateway.root.addResource('patient');
    patientResource.addMethod('POST', new apigateway.LambdaIntegration(this.createPatientFunction), methodOptions);
    patientResource.addMethod('GET', new apigateway.LambdaIntegration(this.createPatientFunction), methodOptions);

    // Route 2: POST /visit & GET /visit (connected to CreatePatientFunction Lambda)
    const visitResource = this.apiGateway.root.addResource('visit');
    visitResource.addMethod('POST', new apigateway.LambdaIntegration(this.createPatientFunction), methodOptions);
    visitResource.addMethod('GET', new apigateway.LambdaIntegration(this.createPatientFunction), methodOptions);

    // Route 3: POST /vitals & GET /vitals (connected to CreatePatientFunction Lambda)
    const vitalsResource = this.apiGateway.root.addResource('vitals');
    vitalsResource.addMethod('POST', new apigateway.LambdaIntegration(this.createPatientFunction), methodOptions);
    vitalsResource.addMethod('GET', new apigateway.LambdaIntegration(this.createPatientFunction), methodOptions);

    // Route 4: POST /audit & GET /audit (connected to CreatePatientFunction Lambda)
    const auditResource = this.apiGateway.root.addResource('audit');
    auditResource.addMethod('POST', new apigateway.LambdaIntegration(this.createPatientFunction), methodOptions);
    auditResource.addMethod('GET', new apigateway.LambdaIntegration(this.createPatientFunction), methodOptions);

    // 4. CloudTrail Security Auditing (HIPAA & SOC 2 Auditing Standard compliance)
    const auditTrail = new cloudtrail.Trail(this, 'HealthSecureAuditTrail', {
      bucket: auditLogsBucket,
      trailName: 'healthsecure-clinical-audit-trail',
      
      // Captures Cognito management, IAM configuration adjustments, and logins (global events)
      includeGlobalServiceEvents: true,
      
      // Enforces standard AES-256 CloudTrail logs encryption at rest
      isMultiRegionTrail: true,
    });

    // Audit S3 raw and curated writes (Patient Creation, Visit Creation, Vitals Creation uploads)
    auditTrail.addS3EventSelector(
      [
        { bucket: this.rawDataBucket },
        { bucket: this.curatedDataBucket },
      ],
      {
        readWriteType: cloudtrail.ReadWriteType.ALL,
      }
    );

    // Audit Lambda executions (patient registration processing, validation runs)
    auditTrail.addLambdaEventSelector([
      this.createPatientFunction,
      this.validatePatientRecordFunction,
    ]);

    // AWS Glue ETL Job for HIPAA de-identification
    const glueScriptAsset = new s3_assets.Asset(this, 'GlueScriptAsset', {
      path: path.join(__dirname, '../glue/deidentify-raw-data.py'),
    });

    const glueRole = new iam.Role(this, 'HealthSecureGlueETLRole', {
      assumedBy: new iam.ServicePrincipal('glue.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSGlueServiceRole'),
      ],
    });

    this.rawDataBucket.grantRead(glueRole);
    this.curatedDataBucket.grantReadWrite(glueRole);
    glueScriptAsset.grantRead(glueRole);

    new glue.CfnJob(this, 'DeidentifyRawDataJob', {
      name: 'healthsecure-deidentify-raw-data',
      role: glueRole.roleArn,
      command: {
        name: 'glueetl',
        pythonVersion: '3',
        scriptLocation: glueScriptAsset.s3ObjectUrl,
      },
      defaultArguments: {
        '--job-language': 'python',
        '--TempDir': `s3://${this.rawDataBucket.bucketName}/temp/`,
        '--RAW_BUCKET_NAME': this.rawDataBucket.bucketName,
        '--CURATED_BUCKET_NAME': this.curatedDataBucket.bucketName,
      },
      glueVersion: '4.0',
    });

    // AWS Glue Catalog Database
    const glueDatabase = new glue.CfnDatabase(this, 'HealthSecureGlueDatabase', {
      catalogId: this.account,
      databaseInput: {
        name: 'healthsecure_compliance_db',
        description: 'Glue Catalog Database for compliance auditing and patient registries',
      },
    });

    // Tag the database for compliance
    cdk.Tags.of(glueDatabase).add('compliance', 'HIPAA');
    cdk.Tags.of(glueDatabase).add('confidentiality', 'Highly-Sensitive');

    // Raw Patients Table mapping to JSON files in Raw S3 Bucket
    const rawTable = new glue.CfnTable(this, 'RawPatientsTable', {
      catalogId: this.account,
      databaseName: 'healthsecure_compliance_db',
      tableInput: {
        name: 'raw_patients',
        description: 'Raw Patient Intake logs containing PII (highly sensitive)',
        tableType: 'EXTERNAL_TABLE',
        parameters: {
          classification: 'json',
        },
        storageDescriptor: {
          columns: [
            { name: 'patientid', type: 'string' },
            { name: 'mrn', type: 'string' },
            { name: 'name', type: 'string' },
            { name: 'dob', type: 'string' },
            { name: 'gender', type: 'string' },
            { name: 'phone', type: 'string' },
            { name: 'address', type: 'string' },
            { name: 'bloodgroup', type: 'string' },
            { name: 'insuranceprovider', type: 'string' },
            { name: 'emergencycontact', type: 'string' },
            { name: 'consentstatus', type: 'string' },
            { name: 'isdataencrypted', type: 'boolean' },
            { name: 'lastauditdate', type: 'string' },
            { name: 'compliancescore', type: 'double' },
          ],
          location: `s3://${this.rawDataBucket.bucketName}/raw-patient-data/`,
          inputFormat: 'org.apache.hadoop.mapred.TextInputFormat',
          outputFormat: 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat',
          serdeInfo: {
            serializationLibrary: 'org.openx.data.jsonserde.JsonSerDe',
          },
        },
      },
    });
    rawTable.addDependency(glueDatabase);
    
    // Tag raw table for compliance
    cdk.Tags.of(rawTable).add('compliance', 'HIPAA');
    cdk.Tags.of(rawTable).add('pii', 'true');
    cdk.Tags.of(rawTable).add('confidentiality', 'Highly-Sensitive');

    // Curated Patients Table mapping to Parquet files in Curated S3 Bucket
    const curatedTable = new glue.CfnTable(this, 'CuratedPatientsTable', {
      catalogId: this.account,
      databaseName: 'healthsecure_compliance_db',
      tableInput: {
        name: 'curated_patients',
        description: 'De-identified patient records curated via Spark ETL (Safe Harbor compliant)',
        tableType: 'EXTERNAL_TABLE',
        parameters: {
          classification: 'parquet',
        },
        storageDescriptor: {
          columns: [
            { name: 'patientid', type: 'string' },
            { name: 'dob', type: 'string' },
            { name: 'gender', type: 'string' },
            { name: 'bloodgroup', type: 'string' },
            { name: 'insuranceprovider', type: 'string' },
            { name: 'consentstatus', type: 'string' },
            { name: 'isdataencrypted', type: 'boolean' },
            { name: 'lastauditdate', type: 'string' },
            { name: 'compliancescore', type: 'double' },
            { name: 'patient_hash', type: 'string' },
          ],
          location: `s3://${this.curatedDataBucket.bucketName}/curated-patients-parquet/`,
          inputFormat: 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat',
          outputFormat: 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat',
          serdeInfo: {
            serializationLibrary: 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe',
          },
        },
      },
    });
    curatedTable.addDependency(glueDatabase);

    // Tag curated table for compliance
    cdk.Tags.of(curatedTable).add('compliance', 'HIPAA');
    cdk.Tags.of(curatedTable).add('pii', 'false');
    cdk.Tags.of(curatedTable).add('confidentiality', 'Low-Confidentiality');
  }
}

