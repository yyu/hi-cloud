exports.handler = (event, context, callback) => {
  callback(null, 'Hello worrrrrrrld!');
  console.error('here it logs!');
  console.log('here it logs');
};