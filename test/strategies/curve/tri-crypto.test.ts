// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import {
  IController,
  IProfitSharingReceiver,
  IRewardForwarder,
  IUniversalLiquidator,
  Storage,
  UniversalLiquidatorProxy,
} from '../../../src/types/index';
import { WETH } from '../../utilities/constants';
import { CoreProtocol, setupCoreProtocol } from '../../utilities/harvest-utils';
import { revertToSnapshotAndCapture, snapshot } from '../../utilities/utils';

describe('TriCryptoStrategy', () => {

  let governance: SignerWithAddress;
  let hhUser1: SignerWithAddress;
  let storage: Storage;
  let profitSharingReceiver: IProfitSharingReceiver;
  let universalLiquidatorProxy: UniversalLiquidatorProxy;
  let universalLiquidator: IUniversalLiquidator;
  let rewardForwarder: IRewardForwarder;
  let controller: IController;
  let core: CoreProtocol;

  let snapshotId: string;

  before(async () => {
    core = await setupCoreProtocol({
      blockNumber: 7642717,
    });
    governance = core.governance;
    hhUser1 = core.hhUser1;
    storage = core.storage;
    profitSharingReceiver = core.profitSharingReceiver;
    universalLiquidatorProxy = core.universalLiquidatorProxy;
    universalLiquidator = core.universalLiquidator;
    rewardForwarder = core.rewardForwarder;
    controller = core.controller;

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
      expect(await rewardForwarder.targetToken()).to.eq(WETH.address);
      expect(await rewardForwarder.profitSharingPool()).to.eq(profitSharingReceiver.address);

      expect(await controller.governance()).to.eq(governance.address);
      expect(await controller.store()).to.eq(storage.address);
      expect(await controller.rewardForwarder()).to.eq(rewardForwarder.address);
      expect(await controller.nextImplementationDelay()).to.eq(core.controllerParams.implementationDelaySeconds);
    });
  });
});
