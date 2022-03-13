// noinspection JSUnusedGlobalSymbols

import { assert } from 'chai';
import { BigNumber, BigNumberish } from 'ethers';
import { ethers, network } from 'hardhat';

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
  const secondsPerBlock = 13;
  await ethers.provider.send('hardhat_mine', [`0x${n.toString(16)}`, `0x${secondsPerBlock.toString(16)}`]);
}

export async function waitDays(n: number) {
  await _waitTime((n * 3600 * 24) + 1);
}

export async function waitHours(n: number) {
  await _waitTime(n * 3600 + 1);
}

export async function waitTime(n: number) {
  await _waitTime(n);
}

export async function sendEther(from: string, to: string, value: BigNumberish): Promise<any> {
  await network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [from],
  });

  const signer = await ethers.getSigner(from);
  return signer.sendTransaction({
    from,
    to,
    value,
  });
}

export function assertBNEq(a: BigNumber, b: BigNumber) {
  let msg = a.toString() + ' != ' + b.toString();
  assert.equal(a.eq(b), true, msg);
}

export function assertApproxBNEq(a: BigNumber, b: BigNumber, c: BigNumber) {
  let _a = a.div(c);
  let _b = b.div(c);
  let msg = _a.toString() + ' != ' + _b.toString();
  assert.equal(_a.eq(_b), true, msg);
}

export function assertBNGt(a: BigNumber, b: BigNumber) {
  let msg = a.toString() + ' is not greater than ' + b.toString();
  assert.equal(a.gt(b), true, msg);
}

export function assertBNGte(a: BigNumber, b: BigNumber) {
  let msg = a.toString() + ' is not greater than ' + b.toString();
  assert.equal(a.gte(b), true, msg);
}

export function assertNEqBN(a: BigNumber, b: BigNumber) {
  assert.equal(a.eq(b), false);
}

export async function inBNfixed(a: BigNumber) {
  return a.toString();
}

export function calculateApr(newValue: BigNumber, oldValue: BigNumber) {
  const blocksPerHour = 4800;
  return newValue.div(oldValue).sub(1).mul((24 / (blocksPerHour / 272))).mul(365);
}

export function calculateApy(newValue: BigNumber, oldValue: BigNumber) {
  const blocksPerHour = 4800;
  return (newValue.div(oldValue).sub(1).mul((24 / (blocksPerHour / 272))).add(1));
}

// ========================= Private Functions =========================

async function _waitTime(timeToAddSeconds: number) {
  const currentTimestamp = await ethers.provider.getBlock('latest');
  await ethers.provider.send('evm_setNextBlockTimestamp', [currentTimestamp.timestamp + timeToAddSeconds]);
  await ethers.provider.send('evm_mine', []);
}
