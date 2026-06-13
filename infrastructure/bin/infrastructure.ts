#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { InfrastructureStack } from '../lib/infrastructure-stack';
import { MonitoringStack } from '../lib/monitoring-stack';
import { WebHostingStack } from '../lib/hosting-stack';
import { PipelineStack } from '../lib/pipeline-stack';

const app = new cdk.App();
const infraStack = new InfrastructureStack(app, 'InfrastructureStack');

new MonitoringStack(app, 'MonitoringStack', {
  rawDataBucket: infraStack.rawDataBucket,
  quarantineDataBucket: infraStack.quarantineDataBucket,
  curatedDataBucket: infraStack.curatedDataBucket,
  createPatientFunction: infraStack.createPatientFunction,
  validatePatientRecordFunction: infraStack.validatePatientRecordFunction,
  apiGateway: infraStack.apiGateway,
});

const hostingStack = new WebHostingStack(app, 'WebHostingStack');

new PipelineStack(app, 'PipelineStack', {
  hostingBucket: hostingStack.hostingBucket,
  distribution: hostingStack.distribution,
});
