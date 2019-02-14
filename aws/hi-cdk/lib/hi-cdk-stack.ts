import cdk = require('@aws-cdk/cdk');
import s3 = require('@aws-cdk/aws-s3');
import lambda = require('@aws-cdk/aws-lambda')

export class HiCdkStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // The code that defines your stack goes here
    new s3.Bucket(this, 'AWSomeCDKBucket', {
        versioned: true,
        encryption: s3.BucketEncryption.KmsManaged
    });

    new lambda.Function(this, "AWSomeCDKLambda", {
      code: new lambda.InlineCode("exports.handler = (event, context, callback) => { callback(null, 'Hello worrrrrrrld!'); };"),
      handler: "index.handler",
      runtime: lambda.Runtime.NodeJS810
    })
  }
}
