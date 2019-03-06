import cdk = require('@aws-cdk/cdk');
import s3 = require('@aws-cdk/aws-s3');
import lambda = require('@aws-cdk/aws-lambda')
import { S3EventSource } from '@aws-cdk/aws-lambda-event-sources';
import events = require('@aws-cdk/aws-events')
import iam = require('@aws-cdk/aws-iam')

import fs = require('fs')

export class HiCdkStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // The code that defines your stack goes here

    // S3 Bucket
    const s3bucket = new s3.Bucket(this, 'AWSomeCDKBucket', {
        versioned: true,
        encryption: s3.BucketEncryption.KmsManaged
    });

    // Lambda
    new lambda.Function(this, 'AWSomeCDKLambda', {
      code: new lambda.InlineCode(fs.readFileSync('lib/dummy-lambda-function.js', { encoding: 'utf-8' })),
      handler: 'index.handler',
      runtime: lambda.Runtime.NodeJS810
    });

    // another Lambda, namely LambdaLsS3
    const lambdalss3 = new lambda.Function(this, 'AWSomeCDKLambdaLsS3', {
      code: new lambda.InlineCode(fs.readFileSync('lib/ls-s3-lambda-function.js', { encoding: 'utf-8' })),
      handler: 'index.handler',
      runtime: lambda.Runtime.NodeJS810
    });

    // S3 Bucket --(on object creation)--> LambdaLsS3
    lambdalss3.addEventSource(new S3EventSource(s3bucket, {
      events: [ s3.EventType.ObjectCreated ]
    }));

    // lambda
    const lambda4event = new lambda.Function(this, 'AWSomeCDKLambda4Event', {
      code: new lambda.InlineCode(fs.readFileSync('lib/dummy-lambda-function-with-logging.js', { encoding: 'utf-8' })),
      handler: 'index.handler',
      runtime: lambda.Runtime.NodeJS810
    });
    lambda4event.addToRolePolicy(
      new iam.PolicyStatement()
        .addAction('cloudwatch:PutMetricData')
        .addAllResources()
    );

    // cloudwatch
    new events.EventRule(this, 'Event1', {
      description: 'CodePipeline Event',
      ruleName: 'CodePipelineEvent1',
      enabled: true,
      eventPattern: {
        "source": [
          "aws.codepipeline"
        ]
      },
      targets: [lambda4event]
    });

  }
}
