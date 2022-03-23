// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import {
  IController,
  IProfitSharingReceiver,
  IRewardForwarder,
  IUniversalLiquidator,
  Storage,
  UniversalLiquidatorProxy,
} from '../../src/types';
import { CRV, DAI, SUSHI, SUSHI_ROUTER, UNISWAP_V3_ROUTER, USDC, USDT, WBTC, WETH } from '../../src/utils/constants';
import { setupCoreProtocol } from '../../src/utils/harvest-utils';
import { getLatestTimestamp, revertToSnapshotAndCapture, snapshot, waitTime } from '../../src/utils/utils';

/**
 * Tests deployment of `Storage`, `Controller`, `RewardForwarder`, `UniversalLiquidator(Proxy)`
 */
describe('BaseSystem', () => {

  let governance: SignerWithAddress;
  let hhUser1: SignerWithAddress;
  let storage: Storage;
  let profitSharingReceiver: IProfitSharingReceiver;
  let universalLiquidatorProxy: UniversalLiquidatorProxy;
  let universalLiquidator: IUniversalLiquidator;
  let rewardForwarder: IRewardForwarder;
  let controller: IController;
  let implementationDelaySeconds: number;

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
    implementationDelaySeconds = coreProtocol.controllerParams.implementationDelaySeconds;

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

      expect(await controller.governance()).to.eq(governance.address);
      expect(await controller.store()).to.eq(storage.address);
      expect(await controller.targetToken()).to.eq(WETH.address);
      expect(await controller.profitSharingReceiver()).to.eq(profitSharingReceiver.address);
      expect(await controller.rewardForwarder()).to.eq(rewardForwarder.address);
      expect(await controller.nextImplementationDelay()).to.eq(implementationDelaySeconds);
    });
  });

  describe('UniversalLiquidator#scheduleUpgrade', () => {
    it('should work properly', async () => {
      expect(await universalLiquidator.nextImplementation()).to.eq(ethers.constants.AddressZero);
      const universalLiquidatorImplementation = await universalLiquidatorProxy.implementation();
      await universalLiquidator.connect(governance).scheduleUpgrade(universalLiquidatorImplementation);
      expect(await universalLiquidator.nextImplementation()).to.eq(universalLiquidatorImplementation);
      await universalLiquidatorProxy.connect(governance).upgrade();
      expect(await universalLiquidator.nextImplementation()).to.eq(ethers.constants.AddressZero);
    });

    it('should fail if not called by governance', async () => {
      expect(await universalLiquidator.nextImplementation()).to.eq(ethers.constants.AddressZero);
      const universalLiquidatorImplementation = await universalLiquidatorProxy.implementation();
      await expect(universalLiquidator.connect(hhUser1).scheduleUpgrade(universalLiquidatorImplementation))
        .to.be.revertedWith('Not governance');
    })
  });

  describe('Controller#setProfitSharingNumerator', () => {
    it('should work for normal conditions', async () => {
      const profitSharingNumerator = 100;
      const result1 = await controller.connect(governance).setProfitSharingNumerator(profitSharingNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueProfitSharingNumeratorChange')
        .withArgs(profitSharingNumerator, nextImplementationTimestamp);

      expect(await controller.profitSharingNumerator()).to.not.eq(profitSharingNumerator);
      expect(await controller.nextProfitSharingNumerator()).to.eq(profitSharingNumerator);
      expect(await controller.nextProfitSharingNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(implementationDelaySeconds + 1);

      const result2 = await controller.connect(governance).confirmSetProfitSharingNumerator();
      await expect(result2).to.emit(controller, 'ConfirmProfitSharingNumeratorChange')
        .withArgs(profitSharingNumerator)

      expect(await controller.profitSharingNumerator()).to.eq(profitSharingNumerator);
      expect(await controller.nextProfitSharingNumerator()).to.eq(0);
      expect(await controller.nextProfitSharingNumeratorTimestamp()).to.eq(0);
    });

    it('should fail when called before implementation delay', async () => {
      const profitSharingNumerator = 100;
      const result1 = await controller.connect(governance).setProfitSharingNumerator(profitSharingNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueProfitSharingNumeratorChange')
        .withArgs(profitSharingNumerator, nextImplementationTimestamp);

      expect(await controller.profitSharingNumerator()).to.not.eq(profitSharingNumerator);
      expect(await controller.nextProfitSharingNumerator()).to.eq(profitSharingNumerator);
      expect(await controller.nextProfitSharingNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(1);

      await expect(controller.connect(governance).confirmSetProfitSharingNumerator())
        .to.be.revertedWith('invalid timestamp or no new profit sharing numerator confirmed');
    });

    it('should fail when not called by governance', async () => {
      const profitSharingNumerator = 100;
      await expect(controller.connect(hhUser1).setProfitSharingNumerator(profitSharingNumerator))
        .to.be.revertedWith('Not governance');
      const result1 = await controller.connect(governance).setProfitSharingNumerator(profitSharingNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueProfitSharingNumeratorChange')
        .withArgs(profitSharingNumerator, nextImplementationTimestamp);

      expect(await controller.profitSharingNumerator()).to.not.eq(profitSharingNumerator);
      expect(await controller.nextProfitSharingNumerator()).to.eq(profitSharingNumerator);
      expect(await controller.nextProfitSharingNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(1);

      await expect(controller.connect(hhUser1).confirmSetProfitSharingNumerator())
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setStrategistFeeNumerator', () => {
    it('should work for normal conditions', async () => {
      const strategistFeeNumerator = 1000;
      const result1 = await controller.connect(governance).setStrategistFeeNumerator(strategistFeeNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueStrategistFeeNumeratorChange')
        .withArgs(strategistFeeNumerator, nextImplementationTimestamp);

      expect(await controller.strategistFeeNumerator()).to.not.eq(strategistFeeNumerator);
      expect(await controller.nextStrategistFeeNumerator()).to.eq(strategistFeeNumerator);
      expect(await controller.nextStrategistFeeNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(implementationDelaySeconds + 1);

      const result2 = await controller.connect(governance).confirmSetStrategistFeeNumerator();
      await expect(result2).to.emit(controller, 'ConfirmStrategistFeeNumeratorChange')
        .withArgs(strategistFeeNumerator)

      expect(await controller.strategistFeeNumerator()).to.eq(strategistFeeNumerator);
      expect(await controller.nextStrategistFeeNumerator()).to.eq(0);
      expect(await controller.nextStrategistFeeNumeratorTimestamp()).to.eq(0);
    });

    it('should fail when called before implementation delay', async () => {
      const strategistFeeNumerator = 1000;
      const result1 = await controller.connect(governance).setStrategistFeeNumerator(strategistFeeNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueStrategistFeeNumeratorChange')
        .withArgs(strategistFeeNumerator, nextImplementationTimestamp);

      expect(await controller.strategistFeeNumerator()).to.not.eq(strategistFeeNumerator);
      expect(await controller.nextStrategistFeeNumerator()).to.eq(strategistFeeNumerator);
      expect(await controller.nextStrategistFeeNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(1);

      await expect(controller.connect(governance).confirmSetStrategistFeeNumerator())
        .to.be.revertedWith('invalid timestamp or no new strategist fee numerator confirmed');
    });

    it('should fail when not called by governance', async () => {
      const strategistFeeNumerator = 1000;
      await expect(controller.connect(hhUser1).setStrategistFeeNumerator(strategistFeeNumerator))
        .to.be.revertedWith('Not governance');
      const result1 = await controller.connect(governance).setStrategistFeeNumerator(strategistFeeNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueStrategistFeeNumeratorChange')
        .withArgs(strategistFeeNumerator, nextImplementationTimestamp);

      expect(await controller.strategistFeeNumerator()).to.not.eq(strategistFeeNumerator);
      expect(await controller.nextStrategistFeeNumerator()).to.eq(strategistFeeNumerator);
      expect(await controller.nextStrategistFeeNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(1);

      await expect(controller.connect(hhUser1).confirmSetStrategistFeeNumerator())
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setPlatformFeeNumerator', () => {
    it('should work for normal conditions', async () => {
      const platformFeeNumerator = 250;
      const result1 = await controller.connect(governance).setPlatformFeeNumerator(platformFeeNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueuePlatformFeeNumeratorChange')
        .withArgs(platformFeeNumerator, nextImplementationTimestamp);

      expect(await controller.platformFeeNumerator()).to.not.eq(platformFeeNumerator);
      expect(await controller.nextPlatformFeeNumerator()).to.eq(platformFeeNumerator);
      expect(await controller.nextPlatformFeeNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(implementationDelaySeconds + 1);

      const result2 = await controller.connect(governance).confirmSetPlatformFeeNumerator();
      await expect(result2).to.emit(controller, 'ConfirmPlatformFeeNumeratorChange')
        .withArgs(platformFeeNumerator)

      expect(await controller.platformFeeNumerator()).to.eq(platformFeeNumerator);
      expect(await controller.nextPlatformFeeNumerator()).to.eq(0);
      expect(await controller.nextPlatformFeeNumeratorTimestamp()).to.eq(0);
    });

    it('should fail when called before implementation delay', async () => {
      const platformFeeNumerator = 250;
      const result1 = await controller.connect(governance).setPlatformFeeNumerator(platformFeeNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueuePlatformFeeNumeratorChange')
        .withArgs(platformFeeNumerator, nextImplementationTimestamp);

      expect(await controller.platformFeeNumerator()).to.not.eq(platformFeeNumerator);
      expect(await controller.nextPlatformFeeNumerator()).to.eq(platformFeeNumerator);
      expect(await controller.nextPlatformFeeNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(1);

      await expect(controller.connect(governance).confirmSetPlatformFeeNumerator())
        .to.be.revertedWith('invalid timestamp or no new platform fee numerator confirmed');
    });

    it('should fail when not called by governance', async () => {
      const platformFeeNumerator = 250;
      await expect(controller.connect(hhUser1).setPlatformFeeNumerator(platformFeeNumerator))
        .to.be.revertedWith('Not governance');
      const result1 = await controller.connect(governance).setPlatformFeeNumerator(platformFeeNumerator);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueuePlatformFeeNumeratorChange')
        .withArgs(platformFeeNumerator, nextImplementationTimestamp);

      expect(await controller.platformFeeNumerator()).to.not.eq(platformFeeNumerator);
      expect(await controller.nextPlatformFeeNumerator()).to.eq(platformFeeNumerator);
      expect(await controller.nextPlatformFeeNumeratorTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(1);

      await expect(controller.connect(hhUser1).confirmSetPlatformFeeNumerator())
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setNextImplementationDelay', () => {
    it('should work for normal conditions', async () => {
      const tempNextImplementationDelay = 86400;
      const result1 = await controller.connect(governance).setNextImplementationDelay(tempNextImplementationDelay);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueNextImplementationDelay')
        .withArgs(tempNextImplementationDelay, nextImplementationTimestamp);

      expect(await controller.nextImplementationDelay()).to.not.eq(tempNextImplementationDelay);
      expect(await controller.tempNextImplementationDelay()).to.eq(tempNextImplementationDelay);
      expect(await controller.tempNextImplementationDelayTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(implementationDelaySeconds + 1);

      const result2 = await controller.connect(governance).confirmNextImplementationDelay();
      await expect(result2).to.emit(controller, 'ConfirmNextImplementationDelay')
        .withArgs(tempNextImplementationDelay)

      expect(await controller.nextImplementationDelay()).to.eq(tempNextImplementationDelay);
      expect(await controller.tempNextImplementationDelay()).to.eq(0);
      expect(await controller.tempNextImplementationDelayTimestamp()).to.eq(0);
    });

    it('should fail when called before implementation delay', async () => {
      const tempNextImplementationDelay = 86400;
      const result1 = await controller.connect(governance).setNextImplementationDelay(tempNextImplementationDelay);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueNextImplementationDelay')
        .withArgs(tempNextImplementationDelay, nextImplementationTimestamp);

      expect(await controller.nextImplementationDelay()).to.not.eq(tempNextImplementationDelay);
      expect(await controller.tempNextImplementationDelay()).to.eq(tempNextImplementationDelay);
      expect(await controller.tempNextImplementationDelayTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(1);

      await expect(controller.connect(governance).confirmNextImplementationDelay())
        .to.be.revertedWith('invalid timestamp or no new implementation delay confirmed');
    });

    it('should fail when not called by governance', async () => {
      const tempNextImplementationDelay = 250;
      await expect(controller.connect(hhUser1).setNextImplementationDelay(tempNextImplementationDelay))
        .to.be.revertedWith('Not governance');
      const result1 = await controller.connect(governance).setNextImplementationDelay(tempNextImplementationDelay);
      const latestTimestamp = await getLatestTimestamp();
      const nextImplementationTimestamp = latestTimestamp + implementationDelaySeconds;
      await expect(result1).to.emit(controller, 'QueueNextImplementationDelay')
        .withArgs(tempNextImplementationDelay, nextImplementationTimestamp);

      expect(await controller.nextImplementationDelay()).to.not.eq(tempNextImplementationDelay);
      expect(await controller.tempNextImplementationDelay()).to.eq(tempNextImplementationDelay);
      expect(await controller.tempNextImplementationDelayTimestamp()).to.eq(nextImplementationTimestamp);

      await waitTime(1);

      await expect(controller.connect(hhUser1).confirmNextImplementationDelay())
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setTargetToken', () => {
    it('should work normally', async () => {
      await controller.connect(governance).setTargetToken(USDC.address);
      expect(await controller.targetToken()).to.eq(USDC.address);
    });
    it('should fail when not called by governance', async () => {
      await expect(controller.connect(hhUser1).setTargetToken(USDC.address))
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setProfitSharingReceiver', () => {
    it('should work normally', async () => {
      await controller.connect(governance).setProfitSharingReceiver(hhUser1.address);
      expect(await controller.profitSharingReceiver()).to.eq(hhUser1.address);
    });
    it('should fail when not called by governance', async () => {
      await expect(controller.connect(hhUser1).setProfitSharingReceiver(hhUser1.address))
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setRewardForwarder', () => {
    it('should work normally', async () => {
      await controller.connect(governance).setRewardForwarder(hhUser1.address);
      expect(await controller.rewardForwarder()).to.eq(hhUser1.address);
    });
    it('should fail when not called by governance', async () => {
      await expect(controller.connect(hhUser1).setRewardForwarder(hhUser1.address))
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setUniversalLiquidator', () => {
    it('should work normally', async () => {
      await controller.connect(governance).setUniversalLiquidator(hhUser1.address);
      expect(await controller.universalLiquidator()).to.eq(hhUser1.address);
    });
    it('should fail when not called by governance', async () => {
      await expect(controller.connect(hhUser1).setUniversalLiquidator(hhUser1.address))
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setDolomiteYieldFarmingRouter', () => {
    it('should work normally', async () => {
      await controller.connect(governance).setDolomiteYieldFarmingRouter(hhUser1.address);
      expect(await controller.dolomiteYieldFarmingRouter()).to.eq(hhUser1.address);
    });
    it('should fail when not called by governance', async () => {
      await expect(controller.connect(hhUser1).setDolomiteYieldFarmingRouter(hhUser1.address))
        .to.be.revertedWith('Not governance');
    });
  });

  describe('UniversalLiquidator#getSwapRouter', () => {
    it('should work after deployment', async () => {
      expect(await universalLiquidator.getSwapRouter(CRV.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address);
      expect(await universalLiquidator.getSwapRouter(DAI.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address);
      expect(await universalLiquidator.getSwapRouter(SUSHI.address, WETH.address)).to.eq(SUSHI_ROUTER.address);
      expect(await universalLiquidator.getSwapRouter(USDC.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address);
      expect(await universalLiquidator.getSwapRouter(USDT.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address);
      expect(await universalLiquidator.getSwapRouter(WBTC.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address);

      expect(await universalLiquidator.getSwapRouter(WETH.address, USDC.address)).to.eq(UNISWAP_V3_ROUTER.address);
    });

    describe('ProfitSharingReceiverV1#withdrawTokens', () => {
      it('should work when called by governance', async () => {
        const amount = ethers.BigNumber.from('1000000000000000000')
        await WETH.connect(hhUser1).deposit({ value: amount });
        await WETH.connect(hhUser1).transfer(profitSharingReceiver.address, amount);

        expect(await WETH.connect(hhUser1).balanceOf(profitSharingReceiver.address)).to.eq(amount);

        const result = await profitSharingReceiver.connect(governance).withdrawTokens([WETH.address]);
        await expect(result).to.emit(profitSharingReceiver, 'WithdrawToken')
          .withArgs(WETH.address, governance.address, amount);

        expect(await WETH.connect(hhUser1).balanceOf(profitSharingReceiver.address)).to.eq(0);
        expect(await WETH.connect(hhUser1).balanceOf(governance.address)).to.eq(amount);
      });

      it('should failed when not called by governance', async () => {
        const amount = ethers.BigNumber.from('1000000000000000000')
        await WETH.connect(hhUser1).deposit({ value: amount });
        await WETH.connect(hhUser1).transfer(profitSharingReceiver.address, amount);

        expect(await WETH.connect(hhUser1).balanceOf(profitSharingReceiver.address)).to.eq(amount);

        await expect(profitSharingReceiver.connect(hhUser1).withdrawTokens([WETH.address]))
          .to.revertedWith('Not governance');
      });
    });
  })
});
