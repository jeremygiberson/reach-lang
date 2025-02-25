import fetch from 'node-fetch';
import waitPort from 'wait-port';

const hostname = "http://localhost"
const port = 3001
const address = `${hostname}:${port}`

const waitForPort = async () => {
  const params = {
    port: port
  }
  const r = await waitPort(params)
  console.log(r)
}

async function interact(method = 'GET', url = '', data = {}) {
  const response = await fetch(url, {
    method: method,
    cache: 'no-cache',
    headers: {
      'Content-Type': 'application/json'
    },
    redirect: 'follow',
    referrerPolicy: 'no-referrer'
    // body: JSON.stringify(data)
  });
  return response.json();
}

const getStates = async () => {
  const r = await interact(`GET`, `${address}/states`)
  console.log(r)
  return r;
}

const getEdges = async () => {
  const r = await interact(`GET`, `${address}/edges`)
  console.log(r)
  return r;
}

const getStatus = async () => {
  const r = await interact(`GET`, `${address}/status`)
  console.log(r)
  return r;
}

async function getStateActions(s) {
  const r = await interact(`GET`, `${address}/states/${s}/actions`)
  console.log(r)
  return r;
}

async function getStateGlobals(s) {
  const r = await interact(`GET`, `${address}/global/${s}`)
  console.log(r)
  return r;
}

async function getStateLocals(s) {
  const r = await interact(`GET`, `${address}/local/${s}`)
  console.log(r)
  return r;
}

const load = async () => {
  const r = await interact('POST', `${address}/load`)
  console.log(r)
  return r;
}

const init = async () => {
  const r = await interact('POST', `${address}/init`)
  console.log(r)
  return r
}

const respondWithVal = async (s,a,v,w=false) => {
  const who = (w || w === 0) ? `&who=${w}` : ``
  const r = await interact('POST', `${address}/states/${s}/actions/${a}/?data=${v}${who}`)
  console.log(r)
  return r
}

const initFor = async (s,a) => {
  const r = await interact('POST', `${address}/init/${a}/${s}`)
  console.log(r)
  return r
}

const ping = async () => {
  const r = await interact(`GET`, `${address}/ping`)
  console.log(r)
  return r;
}

export {
  getStates,
  getStatus,
  getStateActions,
  load,
  init,
  respondWithVal,
  ping,
  waitForPort,
  initFor,
  getStateLocals,
  getStateGlobals,
  getEdges
};
