#!/usr/bin/env node
import 'source-map-support/register';
import cdk = require('@aws-cdk/cdk');
import { HiCdkStack } from '../lib/hi-cdk-stack';

const app = new cdk.App();
new HiCdkStack(app, 'HiCdkStack');
app.run();
