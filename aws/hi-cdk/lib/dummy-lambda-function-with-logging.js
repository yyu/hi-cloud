exports.handler = (event, context, callback) => {
  callback(null, 'Hello worrrrrrrld!');
  console.error('here it logs!');
  console.log('here it logs event ' + JSON.stringify(event) + '.');
  console.log('here it logs context ' + JSON.stringify(context) + '.');

  var AWS = require('aws-sdk');
  var cw = new AWS.CloudWatch({apiVersion: '2010-08-01'});
  var params = {
    MetricData: [
      {
        MetricName: 'CodePipelineState',
        Dimensions: [
          {
            Name: 'NameFoo',
            Value: 'ValueFoo'
          },
        ],
        Unit: 'None',
        Value: 1.0
      },
    ],
    Namespace: 'NamespaceBlah'
  };
  cw.putMetricData(params, function(err, data) {
    if (err) {
      console.log("Error", err);
    } else {
      console.log("Success", JSON.stringify(data));
    }
  });

  console.log('--------------------------------------------------DONE.');
};
