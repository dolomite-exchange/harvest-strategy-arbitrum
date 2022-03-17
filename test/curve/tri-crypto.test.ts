// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BaseContract } from 'ethers';
import { ethers } from 'hardhat';
import {
  Controller, IProfitSharingReceiver,
  RewardForwarder,
  Storage,
  UniversalLiquidator,
  UniversalLiquidator__factory,
  UniversalLiquidatorProxy,
} from '../../src/types';
import { CRV, DAI, SUSHI, SUSHI_ROUTER, UNISWAP_V3_ROUTER, USDC, USDT, WBTC, WETH } from '../utilities/constants';
import { resetFork, revertToSnapshot, setupCoreProtocol, snapshot } from '../utilities/harvest-utils';
import { getLatestTimestamp, revertToSnapshotAndCapture, waitTime } from '../utilities/utils';

/**
 * Tests deployment of `Storage`, `Controller`, `RewardForwarder`, `UniversalLiquidator(Proxy)`
 */
describe('BaseSystem', () => {

  let governance: SignerWithAddress;
  let hhUser1: SignerWithAddress;
  let storage: Storage;
  let profitSharingReceiver: IProfitSharingReceiver;
  let universalLiquidatorProxy: UniversalLiquidatorProxy;
  let universalLiquidator: UniversalLiquidator;
  let rewardForwarder: RewardForwarder;
  let controller: Controller;

  let snapshotId: string;

  before(async () => {
    const coreProtocol = await setupCoreProtocol({
      blockNumber: 7642717,
    });
    governance = coreProtocol.governance;
    hhUser1 = coreProtocol.hhUser1;
    storage = coreProtocol.storage;
    profitSharingReceiver = coreProtocol.profitSharingReceiver;
    universalLiquidatorProxy = coreProtocol.universalLiquidatorProxy;
    universalLiquidator = coreProtocol.universalLiquidator;
    rewardForwarder = coreProtocol.rewardForwarder;
    controller = coreProtocol.controller;

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });


  describe('#deployment', () => {
    it('should work properly', async () => {
      expect(await storage.governance()).to.eq(governance.address);
      expect(await storage.controller()).to.eq(controller.address);

      expect(await universalLiquidator.governance()).to.eq(governance.address);
      expect(await universalLiquidator.controller()).to.eq(controller.address);

      expect(await rewardForwarder.store()).to.eq(storage.address);
      expect(await rewardForwarder.governance()).to.eq(governance.address);
      expect(await rewardForwarder.targetToken()).to.eq(USDC.address);
      expect(await rewardForwarder.profitSharingPool()).to.eq(profitSharingReceiver.address);

      expect(await controller.governance()).to.eq(governance.address);
      expect(await controller.store()).to.eq(storage.address);
      expect(await controller.rewardForwarder()).to.eq(rewardForwarder.address);
      expect(await controller.nextImplementationDelay()).to.eq(implementationDelaySeconds);
    });
  });
});
