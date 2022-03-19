// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { StrategyProxy, TestRewardPool, TestStrategy, VaultProxy, VaultV2 } from '../../src/types';
import { IVault } from '../../types/ethers-contracts';
import { USDC, WETH } from '../utilities/constants';
import { CoreProtocol, createStrategy, createVault, setupCoreProtocol } from '../utilities/harvest-utils';
import { revertToSnapshotAndCapture, snapshot } from '../utilities/utils';


describe('VaultV2', () => {
  let core: CoreProtocol;
  let vaultProxy: VaultProxy;
  let vaultV2: VaultV2;
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

    [vaultProxy, , vaultV2] = await createVault(testVaultImplementation);
    await vaultV2.initializeVault(
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
      vaultV2.address,
      rewardPool.address,
      [USDC.address],
      strategist.address,
    );
    await vaultV2.connect(core.governance).setStrategy(strategy.address);

    snapshotId = await snapshot();
  });

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('Deployment', () => {
    it('should work', async () => {
      expect(await vaultV2.strategy()).to.eq(strategy.address);
      expect(await vaultV2.underlying()).to.eq(WETH.address);
      expect(await vaultV2.underlyingUnit()).to.eq(ethers.constants.WeiPerEther);
      expect(await vaultV2.vaultFractionToInvestNumerator()).to.eq('995');
      expect(await vaultV2.vaultFractionToInvestDenominator()).to.eq('1000');
      expect(await vaultV2.nextImplementation()).to.eq(ethers.constants.AddressZero);
      expect(await vaultV2.nextImplementationTimestamp()).to.eq('0');
      expect(await vaultV2.nextImplementationDelay()).to.eq(core.controllerParams.implementationDelaySeconds);
    });
  });

  describe('', () => {

  });
});
