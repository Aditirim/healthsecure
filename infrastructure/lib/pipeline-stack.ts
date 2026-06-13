import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as codebuild from 'aws-cdk-lib/aws-codebuild';
import * as codepipeline from 'aws-cdk-lib/aws-codepipeline';
import * as codepipeline_actions from 'aws-cdk-lib/aws-codepipeline-actions';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as iam from 'aws-cdk-lib/aws-iam';

export interface PipelineStackProps extends cdk.StackProps {
  readonly hostingBucket: s3.IBucket;
  readonly distribution: cloudfront.IDistribution;
}

export class PipelineStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: PipelineStackProps) {
    super(scope, id, props);

    // 1. Pipeline Artifact Store S3 Bucket
    const artifactBucket = new s3.Bucket(this, 'PipelineArtifactBucket', {
      bucketName: 'healthsecure-pipeline-artifacts',
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
    });

    // 2. CodeBuild Project for Flutter Web Application Build
    const flutterBuildProject = new codebuild.PipelineProject(this, 'FlutterWebBuildProject', {
      projectName: 'healthsecure-flutter-web-build',
      environment: {
        buildImage: codebuild.LinuxBuildImage.AMAZON_LINUX_2_4,
        computeType: codebuild.ComputeType.MEDIUM,
      },
      buildSpec: codebuild.BuildSpec.fromObject({
        version: '0.2',
        phases: {
          install: {
            commands: [
              'echo "Setting up Flutter environment..."',
              'git clone https://github.com/flutter/flutter.git -b stable --depth 1',
              'export PATH="$PATH:`pwd`/flutter/bin"',
              'flutter doctor -v',
            ],
          },
          pre_build: {
            commands: [
              'echo "Fetching project dependencies..."',
              'flutter pub get',
            ],
          },
          build: {
            commands: [
              'echo "Building Flutter Web in release mode..."',
              'flutter build web --release',
            ],
          },
        },
        artifacts: {
          'base-directory': 'build/web',
          files: ['**/*'],
        },
      }),
    });

    // 3. CodeBuild Project for CDK Infrastructure Deployment
    const cdkDeployProject = new codebuild.PipelineProject(this, 'CdkDeployProject', {
      projectName: 'healthsecure-cdk-deploy',
      environment: {
        buildImage: codebuild.LinuxBuildImage.STANDARD_7_0, // Node.js 18 support
        computeType: codebuild.ComputeType.MEDIUM,
        privileged: true, // Required for running Docker container updates if needed
      },
      buildSpec: codebuild.BuildSpec.fromObject({
        version: '0.2',
        phases: {
          install: {
            commands: [
              'echo "Installing node dependencies..."',
              'cd infrastructure',
              'npm ci',
            ],
          },
          build: {
            commands: [
              'echo "Synthesizing and deploying infrastructure stacks..."',
              'npm run build',
              'npx cdk deploy --all --require-approval=never',
            ],
          },
        },
      }),
    });

    // Grant deploy role full IAM permissions to allow stack deployments
    cdkDeployProject.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['*'],
      resources: ['*'],
    }));

    // 4. CodeBuild Project for CloudFront Cache Invalidation
    const cfInvalidationProject = new codebuild.PipelineProject(this, 'CloudFrontInvalidationProject', {
      projectName: 'healthsecure-cloudfront-invalidation',
      environment: {
        buildImage: codebuild.LinuxBuildImage.STANDARD_7_0,
        computeType: codebuild.ComputeType.SMALL,
      },
      environmentVariables: {
        DISTRIBUTION_ID: {
          value: props.distribution.distributionId,
        },
      },
      buildSpec: codebuild.BuildSpec.fromObject({
        version: '0.2',
        phases: {
          build: {
            commands: [
              'echo "Invalidating CloudFront CDN Cache for updated assets..."',
              'aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"',
            ],
          },
        },
      }),
    });

    // Grant permission to create CloudFront invalidations
    cfInvalidationProject.addToRolePolicy(new iam.PolicyStatement({
      effect: iam.Effect.ALLOW,
      actions: ['cloudfront:CreateInvalidation'],
      resources: [`arn:aws:cloudfront::${this.account}:distribution/${props.distribution.distributionId}`],
    }));

    // 5. CodePipeline Definition
    const sourceArtifact = new codepipeline.Artifact('SourceArtifact');
    const flutterBuildArtifact = new codepipeline.Artifact('FlutterBuildArtifact');

    new codepipeline.Pipeline(this, 'HealthSecureCodePipeline', {
      pipelineName: 'healthsecure-cdk-codepipeline',
      artifactBucket: artifactBucket,
      stages: [
        // Stage 1: Checkout Source from GitHub
        {
          stageName: 'Source',
          actions: [
            new codepipeline_actions.GitHubSourceAction({
              actionName: 'GitHub_Source',
              owner: 'owner', // Repository Owner Placeholder
              repo: 'healthsecure', // Repository Name
              branch: 'main',
              oauthToken: cdk.SecretValue.secretsManager('github-token'), // Secure OAuth Secret Key
              output: sourceArtifact,
              trigger: codepipeline_actions.GitHubTrigger.POLL,
            }),
          ],
        },
        // Stage 2: Compile Flutter Web Static Site
        {
          stageName: 'Build_Flutter_Web',
          actions: [
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Build_Flutter',
              project: flutterBuildProject,
              input: sourceArtifact,
              outputs: [flutterBuildArtifact],
            }),
          ],
        },
        // Stage 3: Deploy AWS Backend Stacks via CDK
        {
          stageName: 'Deploy_CDK_Infrastructure',
          actions: [
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Deploy_CDK',
              project: cdkDeployProject,
              input: sourceArtifact,
            }),
          ],
        },
        // Stage 4: Deploy Compiled Flutter Web Assets to S3 Web Hosting Bucket
        {
          stageName: 'Deploy_Web_Assets',
          actions: [
            new codepipeline_actions.S3DeployAction({
              actionName: 'Upload_To_S3',
              input: flutterBuildArtifact,
              bucket: props.hostingBucket,
            }),
          ],
        },
        // Stage 5: Invalidate CloudFront CDN Cache
        {
          stageName: 'Clear_CDN_Cache',
          actions: [
            new codepipeline_actions.CodeBuildAction({
              actionName: 'Invalidate_Cache',
              project: cfInvalidationProject,
              input: sourceArtifact, // Dummy input, not utilized by buildspec commands
            }),
          ],
        },
      ],
    });
  }
}
