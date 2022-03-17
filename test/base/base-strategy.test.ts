// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { StrategyProxy } from '../../src/types/StrategyProxy';
import { TestRewardPool } from '../../src/types/TestRewardPool';
import { TestStrategy } from '../../src/types/TestStrategy';
import { VaultProxy } from '../../src/types/VaultProxy';
import { IVault } from '../../types/ethers-contracts';
import { CRV, USDC, WETH } from '../utilities/constants';
import { CoreProtocol, createStrategy, createVault, setupCoreProtocol } from '../utilities/harvest-utils';
import { getLatestTimestamp, impersonate, revertToSnapshotAndCapture, snapshot, waitTime } from '../utilities/utils';

describe('BaseUpgradableStrategy', () => {

  let core: CoreProtocol;
  let vaultProxy: VaultProxy;
  let vault: IVault;
  let rewardPool: TestRewardPool;
  let strategyProxy: StrategyProxy;
  let strategy: TestStrategy;

  let strategist: SignerWithAddress;

  let snapshotId: string;


  before(async () => {
    core = await setupCoreProtocol({
      blockNumber: 8049264,
    });

    const TestStrategyFactory = await ethers.getContractFactory('TestStrategy');
    const testStrategyImplementation = await TestStrategyFactory.deploy() as TestStrategy;

    const VaultV1Factory = await ethers.getContractFactory('VaultV1');
    const testVaultImplementation = await VaultV1Factory.deploy() as IVault;

    [vaultProxy, vault] = await createVault(testVaultImplementation);
    await vault.initializeVault(
      core.storage.address,
      WETH.address,
      995,
      1000,
    );

    const TestRewardPoolFactory = await ethers.getContractFactory('TestRewardPool');
    rewardPool = await TestRewardPoolFactory.deploy(WETH.address, USDC.address) as TestRewardPool;

    strategist = core.hhUser1;
    [strategyProxy, strategy] = await createStrategy(testStrategyImplementation);
    await strategy.initializeBaseStrategy(
      core.storage.address,
      WETH.address,
      vault.address,
      rewardPool.address,
      [USDC.address],
      strategist.address,
    );

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#isUnsalvageableToken', () => {
    it('should work properly', async () => {
      expect(await strategy.isUnsalvageableToken(WETH.address)).to.eq(true);
      expect(await strategy.isUnsalvageableToken(USDC.address)).to.eq(true);
      expect(await strategy.isUnsalvageableToken(CRV.address)).to.eq(false);
    });
  });

  describe('#depositArbCheck', () => {
    it('should work properly', async () => {
      expect(await strategy.depositArbCheck()).to.eq(true);
    });
  });

  describe('#getters', () => {
    it('should work properly', async () => {
      expect(await strategy.sell()).to.eq(true);
      expect(await strategy.sellFloor()).to.eq(0);
      expect(await strategy.governance()).to.eq(core.governance.address);
      expect(await strategy.controller()).to.eq(core.controller.address);
      expect(await strategy.underlying()).to.eq(WETH.address);
      expect(await strategy.vault()).to.eq(vault.address);
      expect(await strategy.rewardPool()).to.eq(rewardPool.address);
      expect(await strategy.rewardTokens()).to.eql([USDC.address]);
      expect(await strategy.strategist()).to.eq(core.hhUser1.address);
      expect(await strategy.investedUnderlyingBalance()).to.eq(0);
      expect(await strategy.nextImplementation()).to.eq(ethers.constants.AddressZero);
      expect(await strategy.nextImplementationTimestamp()).to.eq(0);
      expect(await strategy.nextImplementationDelay()).to.eq(core.controllerParams.implementationDelaySeconds);
      expect(await strategy.shouldUpgrade()).to.eql([false, ethers.constants.AddressZero]);
    });
  });

  describe('#sheduleUpgrade', () => {
    it('should work properly', async () => {
      expect(await strategy.nextImplementation()).to.eq(ethers.constants.AddressZero);
      expect(await strategy.nextImplementationTimestamp()).to.eq(0);
      expect(await strategy.nextImplementationDelay()).to.eq(core.controllerParams.implementationDelaySeconds);
      expect(await strategy.shouldUpgrade()).to.eql([false, ethers.constants.AddressZero]);

      const newVersion = await (await ethers.getContractFactory('TestStrategy')).deploy();
      const result1 = await strategy.connect(core.governance).scheduleUpgrade(newVersion.address);
      const latestTimestamp = await getLatestTimestamp();
      await expect(result1).to.emit(strategy, 'UpgradeScheduled')
        .withArgs(newVersion.address, latestTimestamp + core.controllerParams.implementationDelaySeconds);
      expect(await strategy.shouldUpgrade()).to.eql([false, newVersion.address]);

      await waitTime(core.controllerParams.implementationDelaySeconds + 1);
      expect(await strategy.shouldUpgrade()).to.eql([true, newVersion.address]);

      const result2 = await strategyProxy.connect(core.governance).upgrade();
      await expect(result2).to.emit(strategyProxy, 'Upgraded').withArgs(newVersion.address);
      expect(await strategyProxy.implementation()).to.eq(newVersion.address);
      expect(await strategy.nextImplementationTimestamp()).to.eq(0);
      expect(await strategy.nextImplementationDelay()).to.eq(core.controllerParams.implementationDelaySeconds);
      expect(await strategy.shouldUpgrade()).to.eql([false, ethers.constants.AddressZero]);
    });

    it('should fail if delay has not been met or not called by governance', async () => {
      const newVersion = await (await ethers.getContractFactory('TestStrategy')).deploy();
      const result1 = await strategy.connect(core.governance).scheduleUpgrade(newVersion.address);
      const latestTimestamp = await getLatestTimestamp();
      await expect(result1).to.emit(strategy, 'UpgradeScheduled')
        .withArgs(newVersion.address, latestTimestamp + core.controllerParams.implementationDelaySeconds);
      expect(await strategy.shouldUpgrade()).to.eql([false, newVersion.address]);

      await expect(strategyProxy.connect(core.governance).upgrade()).to.revertedWith('Upgrade not scheduled');
      expect(await strategy.shouldUpgrade()).to.eql([false, newVersion.address]);

      await waitTime(core.controllerParams.implementationDelaySeconds + 1);
      expect(await strategy.shouldUpgrade()).to.eql([true, newVersion.address]);

      await expect(strategyProxy.connect(core.hhUser1).upgrade()).to.revertedWith('Could not finalize the upgrade');
    });
  });

  describe('#salvageToken', () => {
    it('should work normally', async () => {
      const crvWhale = await impersonate('0x4a65e76be1b4e8dd6ef618277fa55200e3f8f20a');
      const amount = 100;
      await CRV.connect(crvWhale).transfer(strategy.address, amount);
      await strategy.connect(core.governance).salvageToken(core.governance.address, CRV.address, amount);
      expect(await CRV.connect(crvWhale).balanceOf(strategy.address)).to.eq(0);
      expect(await CRV.connect(crvWhale).balanceOf(core.governance.address)).to.eq(amount);
    });

    it('should fail when called by non-governance nor controller', async () => {
      await expect(strategy.connect(core.hhUser1).salvageToken(core.governance.address, WETH.address, 1))
        .to.revertedWith('The caller must be controller or governance');
    });

    it('should fail for token that is not salvageable', async () => {
      const amount = 100;
      await WETH.connect(core.hhUser1).deposit({ value: amount });
      await WETH.connect(core.hhUser1).transfer(strategy.address, amount);
      await expect(strategy.connect(core.governance).salvageToken(core.governance.address, WETH.address, amount))
        .to.revertedWith('The token must be salvageable');
    });
  });

  describe('#setStrategist', () => {
    it('should work normally', async () => {
      const result = await strategy.connect(strategist).setStrategist(core.hhUser2.address);
      await expect(result).to.emit(strategy, 'StrategistSet').withArgs(core.hhUser2.address);
      expect(await strategy.strategist()).to.eq(core.hhUser2.address);
    });

    it('should fail when called by non-strategist', async () => {
      await expect(strategy.connect(core.governance).setStrategist(core.hhUser2.address))
        .to.revertedWith('Sender must be strategist');
    });
  });

  describe('#setSell', () => {
    it('should work normally', async () => {
      const result = await strategy.connect(core.governance).setSell(false);
      await expect(result).to.emit(strategy, 'SellSet').withArgs(false);
      expect(await strategy.sell()).to.eq(false);
    });

    it('should fail when called by non-governance', async () => {
      await expect(strategy.connect(core.hhUser1).setSell(false))
        .to.revertedWith('Not governance');
    });
  });

  describe('#setSellFloor', () => {
    it('should work normally', async () => {
      const result = await strategy.connect(core.governance).setSellFloor(123);
      await expect(result).to.emit(strategy, 'SellFloorSet').withArgs(123);
      expect(await strategy.sellFloor()).to.eq(123);
    });

    it('should fail when called by non-governance', async () => {
      await expect(strategy.connect(core.hhUser1).setSellFloor(123))
        .to.revertedWith('Not governance');
    });
  });

  describe('#emergencyExit', () => {
    it('should work when no assets are in strategy', async () => {
      expect(await strategy.pausedInvesting()).to.eq(false);

      const result = await strategy.connect(core.governance).emergencyExit();
      await expect(result).to.emit(strategy, 'PausedInvestingSet').withArgs(true);
      expect(await strategy.pausedInvesting()).to.eq(true);
      expect(await strategy.investedUnderlyingBalance()).to.eq(0);
    });

    it('should work when there are assets are in strategy and/or reward pool', async () => {
      expect(await strategy.pausedInvesting()).to.eq(false);

      const amount1 = 100;
      const amount2 = 200;
      const total = amount1 + amount2;

      await WETH.connect(core.hhUser1).deposit({ value: total * 2 });
      await WETH.connect(core.hhUser1).transfer(strategy.address, amount1);
      await WETH.connect(core.hhUser1).transfer(rewardPool.address, amount2);
      expect(await strategy.investedUnderlyingBalance()).to.eq(total);

      const result = await strategy.connect(core.governance).emergencyExit();
      await expect(result).to.emit(strategy, 'PausedInvestingSet').withArgs(true);
      expect(await strategy.pausedInvesting()).to.eq(true);
      expect(await strategy.investedUnderlyingBalance()).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(strategy.address)).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(rewardPool.address)).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(core.governance.address)).to.eq(total);

      await WETH.connect(core.hhUser1).transfer(strategy.address, amount1);
      expect(await strategy.investedUnderlyingBalance()).to.eq(amount1);

      await strategy.connect(core.governance).emergencyExit();
      expect(await strategy.pausedInvesting()).to.eq(true);
      expect(await strategy.investedUnderlyingBalance()).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(strategy.address)).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(rewardPool.address)).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(core.governance.address)).to.eq(total + amount1);

      await WETH.connect(core.hhUser1).transfer(strategy.address, amount2);
      expect(await strategy.investedUnderlyingBalance()).to.eq(amount2);

      await strategy.connect(core.governance).emergencyExit();
      expect(await strategy.pausedInvesting()).to.eq(true);
      expect(await strategy.investedUnderlyingBalance()).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(strategy.address)).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(rewardPool.address)).to.eq(0);
      expect(await WETH.connect(core.hhUser1).balanceOf(core.governance.address)).to.eq(total * 2);
    });

    it('should fail when not called by controller, governance, or vault', async () => {
      await expect(strategy.connect(core.hhUser1).emergencyExit())
        .to.revertedWith('Not governance');
    });
  });

  describe('#continueInvesting', () => {
    it('should fail when not called by controller, governance, or vault', async () => {
      await expect(strategy.connect(core.hhUser1).continueInvesting())
        .to.revertedWith('Not governance');
    });
  });

  describe('#doHardWork', () => {
    it('should fail when not called by controller, governance, or vault', async () => {
      await expect(strategy.connect(core.hhUser1).doHardWork())
        .to.revertedWith('The sender has to be the controller, governance, or vault');
    });
  });

  describe('#withdrawAllToVault', () => {
    it('should fail when not called by controller, governance, or vault', async () => {
      await expect(strategy.connect(core.hhUser1).withdrawAllToVault())
        .to.revertedWith('The sender has to be the controller, governance, or vault');
    });
  });

  describe('#withdrawToVault', () => {
    it('should fail when not called by controller, governance, or vault', async () => {
      await expect(strategy.connect(core.hhUser1).withdrawToVault(100))
        .to.revertedWith('The sender has to be the controller, governance, or vault');
    });
  });
});
