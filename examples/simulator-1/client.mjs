const c = await import('@reach-sh/simulator-client');
const assert = await import('assert');

const main = async () => {
  console.log("Init Testing!")
  await c.waitForPort()
  await c.ping()
  await c.load()
  await c.init()
  await c.initFor(0,0)
  await c.initFor(1,1)
  await c.respondWithVal(2,2,0,0)
  await c.respondWithVal(3,3,0,-1)
  await c.respondWithVal(4,2,-99,0)
  await c.respondWithVal(5,5,-99,1)
  await c.respondWithVal(6,6,1)
  await c.respondWithVal(7,7,1,-1)
  await c.respondWithVal(8,8,-99,0)
  await c.respondWithVal(9,9,-99,1)
  await c.respondWithVal(10,10,-99)
  const r = await c.getStatus()
  assert.equal(r,"Done");
  console.log("Testing Complete!")
}

main()
