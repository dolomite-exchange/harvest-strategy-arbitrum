// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BaseContract } from 'ethers';
import { ethers } from 'hardhat';
import {
  Controller,
  RewardForwarder,
  Storage,
  UniversalLiquidator,
  UniversalLiquidator__factory,
  UniversalLiquidatorProxy,
} from '../../src/types';
import { CRV, DAI, SUSHI, SUSHI_ROUTER, UNISWAP_V3_ROUTER, USDC, USDT, WBTC, WETH } from '../utilities/constants';
import { resetFork, revertToSnapshot, snapshot } from '../utilities/hardhat-utils';
import { getLatestTimestamp, waitTime } from '../utilities/utils';

/**
 * Tests deployment of `Storage`, `Controller`, `RewardForwarder`, `UniversalLiquidator(Proxy)`
 */
describe('BaseSystem', () => {

  let governance: SignerWithAddress;
  let profitSharingReceiver: SignerWithAddress;
  let user1: SignerWithAddress;
  let storage: Storage;
  let universalLiquidatorProxy: UniversalLiquidatorProxy;
  let universalLiquidator: UniversalLiquidator;
  let rewardForwarder: RewardForwarder;
  let controller: Controller;

  let snapshotId: string;

  const implementationDelaySeconds = 60 * 60 * 12; // 12 hours

  before(async () => {
    await resetFork();

    [governance, profitSharingReceiver, user1] = await ethers.getSigners();

    const StorageFactory = await ethers.getContractFactory('Storage');
    storage = (await StorageFactory.deploy()) as Storage;

    const UniversalLiquidatorFactory = await ethers.getContractFactory('UniversalLiquidator');
    const universalLiquidatorImplementation = (await UniversalLiquidatorFactory.deploy()) as UniversalLiquidator;

    const UniversalLiquidatorProxyFactory = await ethers.getContractFactory('UniversalLiquidatorProxy');
    universalLiquidatorProxy = (await UniversalLiquidatorProxyFactory.deploy(
      universalLiquidatorImplementation.address,
    )) as UniversalLiquidatorProxy;

    universalLiquidator = new BaseContract(
      universalLiquidatorProxy.address,
      UniversalLiquidator__factory.createInterface(),
      governance,
    ) as UniversalLiquidator;

    await universalLiquidator.connect(governance).initialize(storage.address);

    const RewardForwarderFactory = await ethers.getContractFactory('RewardForwarder');
    rewardForwarder = (await RewardForwarderFactory.deploy(
      storage.address,
      USDC.address,
      profitSharingReceiver.address,
    )) as RewardForwarder;

    const ControllerFactory = await ethers.getContractFactory('Controller');
    controller = (await ControllerFactory.deploy(
      storage.address,
      rewardForwarder.address,
      universalLiquidator.address,
      implementationDelaySeconds,
    )) as Controller;

    const result = await storage.connect(governance).setInitialController(controller.address);
    await expect(result).to.emit(storage, 'ControllerChanged').withArgs(controller.address);

    await waitTime(1);

    snapshotId = await snapshot();
  })

  afterEach(async () => {
    snapshotId = await revertToSnapshot(snapshotId);
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
      await expect(universalLiquidator.connect(user1).scheduleUpgrade(universalLiquidatorImplementation))
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
      await expect(controller.connect(user1).setProfitSharingNumerator(profitSharingNumerator))
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

      await expect(controller.connect(user1).confirmSetProfitSharingNumerator())
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setStrategistFeeNumerator', () => {
    it('should work for normal conditions', async () => {
      const strategistFeeNumerator = 100;
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
      const strategistFeeNumerator = 100;
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
      const strategistFeeNumerator = 100;
      await expect(controller.connect(user1).setStrategistFeeNumerator(strategistFeeNumerator))
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

      await expect(controller.connect(user1).confirmSetStrategistFeeNumerator())
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setPlatformFeeNumerator', () => {
    it('should work for normal conditions', async () => {
      const platformFeeNumerator = 100;
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
      const platformFeeNumerator = 100;
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
      const platformFeeNumerator = 100;
      await expect(controller.connect(user1).setPlatformFeeNumerator(platformFeeNumerator))
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

      await expect(controller.connect(user1).confirmSetPlatformFeeNumerator())
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setRewardForwarder', () => {
    it('should work normally', async () => {
      await controller.connect(governance).setRewardForwarder(user1.address);
      expect(await controller.rewardForwarder()).to.eq(user1.address);
    });
    it('should fail when not called by governance', async () => {
      await expect(controller.connect(user1).setRewardForwarder(user1.address))
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setUniversalLiquidator', () => {
    it('should work normally', async () => {
      await controller.connect(governance).setUniversalLiquidator(user1.address);
      expect(await controller.universalLiquidator()).to.eq(user1.address);
    });
    it('should fail when not called by governance', async () => {
      await expect(controller.connect(user1).setUniversalLiquidator(user1.address))
        .to.be.revertedWith('Not governance');
    });
  });

  describe('Controller#setDolomiteYieldFarmingRouter', () => {
    it('should work normally', async () => {
      await controller.connect(governance).setDolomiteYieldFarmingRouter(user1.address);
      expect(await controller.dolomiteYieldFarmingRouter()).to.eq(user1.address);
    });
    it('should fail when not called by governance', async () => {
      await expect(controller.connect(user1).setDolomiteYieldFarmingRouter(user1.address))
        .to.be.revertedWith('Not governance');
    });
  });

  describe('UniversalLiquidator#getSwapRouter', () => {
    it('should work after deployment', async () => {
      expect(await universalLiquidator.getSwapRouter(CRV.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address)
      expect(await universalLiquidator.getSwapRouter(DAI.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address)
      expect(await universalLiquidator.getSwapRouter(SUSHI.address, WETH.address)).to.eq(SUSHI_ROUTER.address)
      expect(await universalLiquidator.getSwapRouter(USDC.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address)
      expect(await universalLiquidator.getSwapRouter(USDT.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address)
      expect(await universalLiquidator.getSwapRouter(WBTC.address, WETH.address)).to.eq(UNISWAP_V3_ROUTER.address)

      expect(await universalLiquidator.getSwapRouter(WETH.address, USDC.address)).to.eq(UNISWAP_V3_ROUTER.address)
    });
  })
});
