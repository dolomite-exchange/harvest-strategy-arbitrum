// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { StrategyProxy, TestRewardPool, TestStrategy, VaultProxy, VaultV1 } from '../../src/types';
import { IVault } from '../../types/ethers-contracts';
import { USDC, WETH } from '../utilities/constants';
import { CoreProtocol, createStrategy, createVault, setupCoreProtocol } from '../utilities/harvest-utils';
import { getLatestTimestamp, revertToSnapshotAndCapture, snapshot, waitTime } from '../utilities/utils';


describe('VaultV1', () => {
  let core: CoreProtocol;
  let vaultProxy: VaultProxy;
  let vaultV1: VaultV1;
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

    const VaultV2Factory = await ethers.getContractFactory('VaultV2');
    const testVaultImplementation = await VaultV2Factory.deploy() as IVault;

    [vaultProxy, vaultV1] = await createVault(testVaultImplementation);
    await vaultV1.initializeVault(
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
      vaultV1.address,
      rewardPool.address,
      [USDC.address],
      strategist.address,
    );
    await vaultV1.connect(core.governance).setStrategy(strategy.address);

    snapshotId = await snapshot();
  });

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('Deployment', () => {
    it('should work', async () => {
      expect(await vaultV1.strategy()).to.eq(strategy.address);
      expect(await vaultV1.underlying()).to.eq(WETH.address);
      expect(await vaultV1.underlyingUnit()).to.eq(ethers.constants.WeiPerEther);
      expect(await vaultV1.vaultFractionToInvestNumerator()).to.eq('995');
      expect(await vaultV1.vaultFractionToInvestDenominator()).to.eq('1000');
      expect(await vaultV1.nextImplementation()).to.eq(ethers.constants.AddressZero);
      expect(await vaultV1.nextImplementationTimestamp()).to.eq('0');
      expect(await vaultV1.nextImplementationDelay()).to.eq(core.controllerParams.implementationDelaySeconds);
    });
  });

  describe('#setVaultFractionToInvest', () => {
    it('should work', async () => {
      await vaultV1.connect(core.governance).setVaultFractionToInvest('100', '1000');
      expect(await vaultV1.vaultFractionToInvestNumerator()).to.eq('100');
      expect(await vaultV1.vaultFractionToInvestDenominator()).to.eq('1000');
    });
    it('should not work when not called by governance', async () => {
      await expect(vaultV1.connect(core.hhUser1).setVaultFractionToInvest('100', '1000'))
        .to.revertedWith('Not governance');
    });
    it('should not work when called with bad params', async () => {
      await expect(vaultV1.connect(core.governance).setVaultFractionToInvest('100', '0'))
        .to.revertedWith('denominator must be greater than 0');
      await expect(vaultV1.connect(core.governance).setVaultFractionToInvest('100', '99'))
        .to.revertedWith('denominator must be greater than or equal to the numerator');
    });
  });

  describe('#announceStrategyUpdate/setStrategy', () => {
    it('should work', async () => {
      const TestStrategyFactory = await ethers.getContractFactory('TestStrategy');
      const nextStrategy = await TestStrategyFactory.deploy() as TestStrategy;
      await nextStrategy.initializeBaseStrategy(
        core.storage.address,
        WETH.address,
        vaultV1.address,
        rewardPool.address,
        [USDC.address],
        strategist.address,
      );

      const result1 = await vaultV1.connect(core.governance).announceStrategyUpdate(nextStrategy.address);
      const latestTimestamp = await getLatestTimestamp();
      await expect(result1).to.emit(vaultV1, 'StrategyAnnounced')
        .withArgs(nextStrategy.address, latestTimestamp + core.controllerParams.implementationDelaySeconds);
      expect(await vaultV1.nextStrategy()).to.eq(nextStrategy.address);
      expect(await vaultV1.nextStrategyTimestamp())
        .to.eq(latestTimestamp + core.controllerParams.implementationDelaySeconds);

      await waitTime(core.controllerParams.implementationDelaySeconds + 1);

      const result2 = await vaultV1.connect(core.governance).setStrategy(nextStrategy.address);
      await expect(result2).to.emit(vaultV1, 'StrategyChanged')
        .withArgs(nextStrategy.address, strategy.address);

      expect(await vaultV1.strategy()).to.eq(nextStrategy.address);
      expect(await vaultV1.nextStrategy()).to.eq(ethers.constants.AddressZero);
      expect(await vaultV1.nextStrategyTimestamp()).to.eq(0);
    });

    it('should not work when called before next timestamp', async () => {
      const TestStrategyFactory = await ethers.getContractFactory('TestStrategy');
      const nextStrategy = await TestStrategyFactory.deploy() as TestStrategy;
      await nextStrategy.initializeBaseStrategy(
        core.storage.address,
        WETH.address,
        '0x0000000000000000000000000000000000000001',
        rewardPool.address,
        [USDC.address],
        strategist.address,
      );

      const result1 = await vaultV1.connect(core.governance).announceStrategyUpdate(nextStrategy.address);
      const latestTimestamp = await getLatestTimestamp();
      await expect(result1).to.emit(vaultV1, 'StrategyAnnounced')
        .withArgs(nextStrategy.address, latestTimestamp + core.controllerParams.implementationDelaySeconds);
      expect(await vaultV1.nextStrategy()).to.eq(nextStrategy.address);
      expect(await vaultV1.nextStrategyTimestamp())
        .to.eq(latestTimestamp + core.controllerParams.implementationDelaySeconds);

      await expect(vaultV1.connect(core.governance).setStrategy(nextStrategy.address))
        .to.revertedWith('The strategy exists or the time lock did not elapse yet');
    });

    it('should not work when vault strategy does not match', async () => {
      const TestStrategyFactory = await ethers.getContractFactory('TestStrategy');
      const nextStrategy = await TestStrategyFactory.deploy() as TestStrategy;
      await nextStrategy.initializeBaseStrategy(
        core.storage.address,
        WETH.address,
        '0x0000000000000000000000000000000000000001',
        rewardPool.address,
        [USDC.address],
        strategist.address,
      );

      await vaultV1.connect(core.governance).announceStrategyUpdate(nextStrategy.address);

      await waitTime(core.controllerParams.implementationDelaySeconds + 1);

      await expect(vaultV1.connect(core.governance).setStrategy(nextStrategy.address))
        .to.revertedWith('The strategy does not belong to this vault');
    });

    it('should not work when vault underlying does not match', async () => {
      const TestRewardPoolFactory = await ethers.getContractFactory('TestRewardPool');
      const newRewardPool = await TestRewardPoolFactory.deploy(USDC.address, WETH.address) as TestRewardPool;

      const TestStrategyFactory = await ethers.getContractFactory('TestStrategy');
      const nextStrategy = await TestStrategyFactory.deploy() as TestStrategy;
      await nextStrategy.initializeBaseStrategy(
        core.storage.address,
        USDC.address,
        WETH.address,
        newRewardPool.address,
        [WETH.address],
        strategist.address,
      );

      await vaultV1.connect(core.governance).announceStrategyUpdate(nextStrategy.address);

      await waitTime(core.controllerParams.implementationDelaySeconds + 1);

      await expect(vaultV1.connect(core.governance).setStrategy(nextStrategy.address))
        .to.revertedWith('Vault underlying must match Strategy underlying');
    });

    it('should not work when not called by governance or controller', async () => {
      await expect(vaultV1.connect(core.hhUser1).announceStrategyUpdate('0x0000000000000000000000000000000000000001'))
        .to.revertedWith('The caller must be controller or governance');
    });
  });
});
