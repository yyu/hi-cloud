import cdk = require('@aws-cdk/cdk');
import s3 = require('@aws-cdk/aws-s3');
import lambda = require('@aws-cdk/aws-lambda')
import { S3EventSource } from '@aws-cdk/aws-lambda-event-sources';

import fs = require('fs')

export class HiCdkStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // The code that defines your stack goes here
    let s3bucket = new s3.Bucket(this, 'AWSomeCDKBucket', {
        versioned: true,
        encryption: s3.BucketEncryption.KmsManaged
    });

    new lambda.Function(this, 'AWSomeCDKLambda', {
      code: new lambda.InlineCode(fs.readFileSync('lib/dummy-lambda-function.js', { encoding: 'utf-8' })),
      handler: 'index.handler',
      runtime: lambda.Runtime.NodeJS810
    });

    let lambdalss3 = new lambda.Function(this, 'AWSomeCDKLambdaLsS3', {
      code: new lambda.InlineCode(fs.readFileSync('lib/ls-s3-lambda-function.js', { encoding: 'utf-8' })),
      handler: 'index.handler',
      runtime: lambda.Runtime.NodeJS810
    });

    lambdalss3.addEventSource(new S3EventSource(s3bucket, {
      events: [ s3.EventType.ObjectCreated ]
    }));

  }
}
