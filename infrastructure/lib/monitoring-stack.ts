import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
import * as sns from 'aws-cdk-lib/aws-sns';
import * as subs from 'aws-cdk-lib/aws-sns-subscriptions';
import * as cw_actions from 'aws-cdk-lib/aws-cloudwatch-actions';

export interface MonitoringStackProps extends cdk.StackProps {
  readonly rawDataBucket: s3.IBucket;
  readonly quarantineDataBucket: s3.IBucket;
  readonly curatedDataBucket: s3.IBucket;
  readonly createPatientFunction: lambda.IFunction;
  readonly validatePatientRecordFunction: lambda.IFunction;
  readonly apiGateway: apigateway.IRestApi;
}

export class MonitoringStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: MonitoringStackProps) {
    super(scope, id, props);

    // Helpers for API Gateway metrics (since IRestApi doesn't have metric helpers)
    const getApiMetric = (metricName: string, statistic: string, label: string, period?: cdk.Duration) => {
      return new cloudwatch.Metric({
        namespace: 'AWS/ApiGateway',
        metricName,
        dimensionsMap: {
          ApiName: props.apiGateway.restApiId,
        },
        statistic,
        period: period ?? cdk.Duration.minutes(5),
        label,
      });
    };

    // Helpers for S3 daily storage metrics (since IBucket does not have daily storage metric methods)
    const getBucketSizeMetric = (bucket: s3.IBucket, label: string) => {
      return new cloudwatch.Metric({
        namespace: 'AWS/S3',
        metricName: 'BucketSizeBytes',
        dimensionsMap: {
          BucketName: bucket.bucketName,
          StorageType: 'StandardStorage',
        },
        statistic: 'Average',
        period: cdk.Duration.days(1),
        label,
      });
    };

    const getBucketObjectCountMetric = (bucket: s3.IBucket, label: string) => {
      return new cloudwatch.Metric({
        namespace: 'AWS/S3',
        metricName: 'NumberOfObjects',
        dimensionsMap: {
          BucketName: bucket.bucketName,
          StorageType: 'AllStorageTypes',
        },
        statistic: 'Average',
        period: cdk.Duration.days(1),
        label,
      });
    };

    // 1. HIPAA-Compliant SNS Topic for Security Compliance Alerts
    const complianceAlertsTopic = new sns.Topic(this, 'HealthSecureComplianceAlertsTopic', {
      topicName: 'healthsecure-compliance-alerts',
      displayName: 'HealthSecure Compliance Telemetry Alerts',
    });

    complianceAlertsTopic.addSubscription(new subs.EmailSubscription('aditirim2006@gmail.com'));

    // 2. Custom CloudWatch Alarms

    // Compute Error Alarm (Create Patient)
    const createPatientErrorsMetric = props.createPatientFunction.metricErrors({
      period: cdk.Duration.minutes(1),
      statistic: 'Sum',
    });

    const createPatientAlarm = new cloudwatch.Alarm(this, 'CreatePatientErrorsAlarm', {
      metric: createPatientErrorsMetric,
      threshold: 1,
      evaluationPeriods: 1,
      alarmName: 'healthsecure-create-patient-errors-alert',
      alarmDescription: 'Alert: Patient Ingestion Lambda function experienced an execution error.',
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    createPatientAlarm.addAlarmAction(new cw_actions.SnsAction(complianceAlertsTopic));

    // Compute Error Alarm (Validate Patient Record)
    const validateRecordErrorsMetric = props.validatePatientRecordFunction.metricErrors({
      period: cdk.Duration.minutes(1),
      statistic: 'Sum',
    });

    const validateRecordAlarm = new cloudwatch.Alarm(this, 'ValidatePatientRecordErrorsAlarm', {
      metric: validateRecordErrorsMetric,
      threshold: 1,
      evaluationPeriods: 1,
      alarmName: 'healthsecure-validate-patient-record-errors-alert',
      alarmDescription: 'Alert: Ingest Trigger Validation Lambda function experienced an execution error.',
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    validateRecordAlarm.addAlarmAction(new cw_actions.SnsAction(complianceAlertsTopic));

    // API Gateway Server-side Faults (5XX Errors)
    const api5xxMetric = getApiMetric('5XXError', 'Sum', 'Server Errors (5XX)', cdk.Duration.minutes(1));

    const api5xxAlarm = new cloudwatch.Alarm(this, 'ApiGateway5xxErrorAlarm', {
      metric: api5xxMetric,
      threshold: 1,
      evaluationPeriods: 1,
      alarmName: 'healthsecure-api-gateway-5xx-errors-alert',
      alarmDescription: 'Alert: REST API Gateway experienced a server-side 5xx error.',
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    api5xxAlarm.addAlarmAction(new cw_actions.SnsAction(complianceAlertsTopic));

    // API Gateway Latency Warnings
    const apiLatencyMetric = getApiMetric('Latency', 'Average', 'Average Latency (ms)', cdk.Duration.minutes(5));

    const apiLatencyAlarm = new cloudwatch.Alarm(this, 'ApiGatewayLatencyAlarm', {
      metric: apiLatencyMetric,
      threshold: 1000, // Trigger if latency exceeds 1 sec
      evaluationPeriods: 1,
      alarmName: 'healthsecure-api-gateway-latency-alert',
      alarmDescription: 'Alert: REST API average request processing latency exceeds 1000 ms.',
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    apiLatencyAlarm.addAlarmAction(new cw_actions.SnsAction(complianceAlertsTopic));

    // S3 Quarantine Bucket Influx Alarm
    const quarantinePutMetric = new cloudwatch.Metric({
      namespace: 'AWS/S3',
      metricName: 'PutRequests',
      dimensionsMap: {
        BucketName: props.quarantineDataBucket.bucketName,
        FilterId: 'EntireBucket',
      },
      period: cdk.Duration.minutes(5),
      statistic: 'Sum',
    });

    const quarantineInfluxAlarm = new cloudwatch.Alarm(this, 'QuarantineDataBucketInfluxAlarm', {
      metric: quarantinePutMetric,
      threshold: 1,
      evaluationPeriods: 1,
      alarmName: 'healthsecure-quarantine-bucket-influx-alert',
      alarmDescription: 'Alert: Quarantine bucket received malformed patient ingestion charts. Clinical validation failures triggered.',
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    quarantineInfluxAlarm.addAlarmAction(new cw_actions.SnsAction(complianceAlertsTopic));

    // 3. Centralized Operations Console Dashboard
    const dashboard = new cloudwatch.Dashboard(this, 'HealthSecureMonitoringDashboard', {
      dashboardName: 'healthsecure-monitoring-dashboard',
    });

    // Row 1: Dashboard Title & Context
    dashboard.addWidgets(
      new cloudwatch.TextWidget({
        markdown: '# HealthSecure Executive Compliance Telemetry Console\nActive operations monitoring of S3 Ingestion, serverless Compute, and REST APIs.',
        width: 24,
        height: 2,
      })
    );

    // Row 2: API Gateway Ingress Widget Grid
    dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'REST API Ingress Volumes & Latency',
        left: [getApiMetric('Count', 'Sum', 'Request Count')],
        right: [getApiMetric('Latency', 'Average', 'Average Latency (ms)')],
        width: 12,
        height: 6,
      }),
      new cloudwatch.GraphWidget({
        title: 'REST API Ingress Error Faults (4XX vs 5XX)',
        left: [
          getApiMetric('4XXError', 'Sum', 'Client Errors (4XX)'),
          getApiMetric('5XXError', 'Sum', 'Server Errors (5XX)'),
        ],
        width: 12,
        height: 6,
      })
    );

    // Row 3: Serverless Lambda Performance Widget Grid
    dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'Serverless Compute Invocations & Throttles',
        left: [
          props.createPatientFunction.metricInvocations({ statistic: 'Sum', label: 'CreatePatient Invocations' }),
          props.validatePatientRecordFunction.metricInvocations({ statistic: 'Sum', label: 'ValidateRecord Invocations' }),
        ],
        right: [
          props.createPatientFunction.metric('Throttles', { statistic: 'Sum', label: 'CreatePatient Throttled' }),
          props.validatePatientRecordFunction.metric('Throttles', { statistic: 'Sum', label: 'ValidateRecord Throttled' }),
        ],
        width: 12,
        height: 6,
      }),
      new cloudwatch.GraphWidget({
        title: 'Serverless Execution Errors',
        left: [
          props.createPatientFunction.metricErrors({ statistic: 'Sum', label: 'CreatePatient Errors' }),
          props.validatePatientRecordFunction.metricErrors({ statistic: 'Sum', label: 'ValidateRecord Errors' }),
        ],
        width: 12,
        height: 6,
      })
    );

    // Row 4: S3 Active Storage & Ingress Request Telemetry
    dashboard.addWidgets(
      new cloudwatch.GraphWidget({
        title: 'Active Storage Utilization & Capacity',
        left: [
          getBucketSizeMetric(props.rawDataBucket, 'Raw Bucket Size'),
          getBucketSizeMetric(props.curatedDataBucket, 'Curated Bucket Size'),
          getBucketSizeMetric(props.quarantineDataBucket, 'Quarantine Bucket Size'),
        ],
        right: [
          getBucketObjectCountMetric(props.rawDataBucket, 'Raw Object Count'),
          getBucketObjectCountMetric(props.curatedDataBucket, 'Curated Object Count'),
          getBucketObjectCountMetric(props.quarantineDataBucket, 'Quarantine Object Count'),
        ],
        width: 12,
        height: 6,
      }),
      new cloudwatch.GraphWidget({
        title: 'S3 Ingress Request Activity (Put vs All)',
        left: [
          new cloudwatch.Metric({
            namespace: 'AWS/S3',
            metricName: 'PutRequests',
            dimensionsMap: { BucketName: props.rawDataBucket.bucketName, FilterId: 'EntireBucket' },
            label: 'Raw Put Requests',
          }),
          new cloudwatch.Metric({
            namespace: 'AWS/S3',
            metricName: 'PutRequests',
            dimensionsMap: { BucketName: props.quarantineDataBucket.bucketName, FilterId: 'EntireBucket' },
            label: 'Quarantine Put Requests',
          }),
        ],
        right: [
          new cloudwatch.Metric({
            namespace: 'AWS/S3',
            metricName: 'AllRequests',
            dimensionsMap: { BucketName: props.rawDataBucket.bucketName, FilterId: 'EntireBucket' },
            label: 'Raw All Requests',
          }),
          new cloudwatch.Metric({
            namespace: 'AWS/S3',
            metricName: 'AllRequests',
            dimensionsMap: { BucketName: props.curatedDataBucket.bucketName, FilterId: 'EntireBucket' },
            label: 'Curated All Requests',
          }),
        ],
        width: 12,
        height: 6,
      })
    );
  }
}
