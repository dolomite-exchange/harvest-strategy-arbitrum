// noinspection JSUnusedGlobalSymbols

import BigNumber from 'bignumber.js';
import { assert } from 'chai';

const BN = require('bn.js');
const { time } = require('@openzeppelin/test-helpers');
BigNumber.config({ DECIMAL_PLACES: 0 });

let gasLogger: any = {};
let gasLoggerNum: any = {};

export async function gasLog(logTo: string, targetPromise: Promise<any>) {
  let tx = await targetPromise;
  let gasUsed = tx.receipt.gasUsed;

  if (gasLogger[logTo] == undefined) {
    gasLogger[logTo] = gasUsed;
    gasLoggerNum[logTo] = 1;
  } else {
    gasLogger[logTo] = (gasLogger[logTo]) / (gasLoggerNum[logTo] + 1) + gasUsed / (gasLoggerNum[logTo] + 1);
    gasLoggerNum[logTo]++;
  }
}

export async function printGasLog() {
  console.log(gasLogger);
}

export async function advanceNBlock(n: number) {
  let startingBlock: typeof BN = await time.latestBlock();
  await time.increase(15 * Math.round(n));
  let endBlock = startingBlock.addn(n);
  await time.advanceBlockTo(endBlock);
}

export async function waitHours(n: number) {
  await time.increase(n * 3600 + 1);
  let startingBlock = await time.latestBlock();
  await time.advanceBlockTo(startingBlock.addn(1));
}

export async function waitTime(n: number) {
  await time.increase(n);
  let startingBlock = await time.latestBlock();
  await time.advanceBlockTo(startingBlock.addn(1));
}

export function assertBNEq(a: BigNumber, b: BigNumber) {
  let _a = new BigNumber(a);
  let _b = new BigNumber(b);
  let msg = _a.toFixed() + ' != ' + _b.toFixed();
  assert.equal(_a.eq(_b), true, msg);
}

export function assertApproxBNEq(a: BigNumber, b: BigNumber, c: BigNumber) {
  let _a = new BigNumber(a).div(c);
  let _b = new BigNumber(b).div(c);
  let msg = _a.toFixed() + ' != ' + _b.toFixed();
  assert.equal(_a.eq(_b), true, msg);
}

export function assertBNGt(a: BigNumber, b: BigNumber) {
  let _a = new BigNumber(a);
  let _b = new BigNumber(b);
  let msg = _a.toFixed() + ' is not greater than ' + _b.toFixed();
  assert.equal(_a.gt(_b), true, msg);
}

export function assertBNGte(a: BigNumber, b: BigNumber) {
  let _a = new BigNumber(a);
  let _b = new BigNumber(b);
  let msg = _a.toFixed() + ' is not greater than ' + _b.toFixed();
  assert.equal(_a.gte(_b), true, msg);
}

export function assertNEqBN(a: BigNumber, b: BigNumber) {
  let _a = new BigNumber(a);
  let _b = new BigNumber(b);
  assert.equal(_a.eq(_b), false);
}

export async function inBNfixed(a: BigNumber) {
  return await (new BigNumber(a)).toFixed();
}

export function calculateApr(newValue: BigNumber, oldValue: BigNumber) {
  const blocksPerHour = 4800;
  return newValue.div(oldValue).minus(1).times((24 / (blocksPerHour / 272))).times(365);
}

export function calculateApy(newValue: BigNumber, oldValue: BigNumber) {
  const blocksPerHour = 4800;
  return (newValue.div(oldValue).minus(1).times((24 / (blocksPerHour / 272))).plus(1));
}
