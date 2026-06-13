import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';

export class WebHostingStack extends cdk.Stack {
  public readonly hostingBucket: s3.IBucket;
  public readonly distribution: cloudfront.IDistribution;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. Secure S3 Bucket for Static Frontend Assets
    this.hostingBucket = new s3.Bucket(this, 'HealthSecureWebHostingBucket', {
      bucketName: 'healthsecure-web-hosting',
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      enforceSSL: true,
      versioned: false, // Standard for static assets which are fully rebuildable
      removalPolicy: cdk.RemovalPolicy.DESTROY, // Allows clean teardown of hosting bucket
      autoDeleteObjects: true, // Cleans up S3 objects upon stack deletion
    });

    // 2. CloudFront Origin Access Identity (OAI)
    const originAccessIdentity = new cloudfront.OriginAccessIdentity(this, 'WebHostingOAI', {
      comment: 'OAI for HealthSecure Flutter Web CloudFront distribution',
    });

    // Grant read permissions to CloudFront OAI
    this.hostingBucket.grantRead(originAccessIdentity);

    // 3. CloudFront CDN Distribution with Single Page Application (SPA) routing
    this.distribution = new cloudfront.Distribution(this, 'HealthSecureWebDistribution', {
      defaultBehavior: {
        origin: new origins.S3Origin(this.hostingBucket, {
          originAccessIdentity: originAccessIdentity,
        }),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD,
        cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD,
      },
      defaultRootObject: 'index.html',
      comment: 'CloudFront CDN serving HealthSecure Flutter Web Application',
      // HIPAA / SPA client-side routing: Redirects 403 & 404 to index.html with 200 OK
      errorResponses: [
        {
          httpStatus: 403,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: cdk.Duration.seconds(0),
        },
        {
          httpStatus: 404,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: cdk.Duration.seconds(0),
        },
      ],
    });

    // Outputs
    new cdk.CfnOutput(this, 'CloudFrontURL', {
      value: `https://${this.distribution.distributionDomainName}`,
      description: 'The secure CloudFront CDN endpoint serving the Flutter Web client app',
    });

    new cdk.CfnOutput(this, 'HostingBucketName', {
      value: this.hostingBucket.bucketName,
      description: 'The S3 bucket holding static web assets',
    });
  }
}
