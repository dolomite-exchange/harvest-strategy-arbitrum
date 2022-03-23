// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { IVault, StrategyProxy, TestRewardPool, TestStrategy, VaultProxy, VaultV2 } from '../../src/types';
import { USDC, WETH } from '../../src/utils/constants';
import { CoreProtocol, createStrategy, createVault, setupCoreProtocol } from '../../src/utils/harvest-utils';
import { revertToSnapshotAndCapture, snapshot } from '../../src/utils/utils';


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

    const VaultV2Factory = await ethers.getContractFactory('VaultV2');
    const testVaultImplementation = await VaultV2Factory.deploy() as IVault;

    [vaultProxy, , vaultV2] = await createVault(testVaultImplementation, core, WETH);

    const TestRewardPoolFactory = await ethers.getContractFactory('TestRewardPool');
    rewardPool = await TestRewardPoolFactory.deploy(WETH.address, USDC.address) as TestRewardPool;

    strategist = core.hhUser1;
    [strategyProxy, strategy] = await createStrategy<TestStrategy>('TestStrategy');
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

  const setupBalance = async (user: SignerWithAddress, balance: BigNumber) => {
    await WETH.connect(user).deposit({ value: balance });
    await WETH.connect(user).approve(vaultProxy.address, balance);
  }

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

  describe('#asset', () => {
    it('should work', async () => {
      expect(await vaultV2.asset()).to.eq(WETH.address);
    });
  });

  describe('#totalAssets', () => {
    it('should work', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      await setupBalance(core.hhUser1, deposit1);
      await setupBalance(core.hhUser2, deposit2);

      await WETH.connect(core.hhUser1).transfer(vaultV2.address, deposit1);
      expect(await vaultV2.totalAssets()).to.eq(deposit1);

      await WETH.connect(core.hhUser2).transfer(strategy.address, deposit2);
      expect(await vaultV2.totalAssets()).to.eq(deposit1.add(deposit2));
    });
  });

  describe('#assetsPerShare', () => {
    it('should work', async () => {
      expect(await vaultV2.assetsPerShare()).to.eq('1000000000000000000');

      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');
      await setupBalance(core.hhUser1, deposit1);
      await setupBalance(core.hhUser3, reward1);

      await WETH.connect(core.hhUser3).transfer(strategy.address, reward1);
      expect(await vaultV2.assetsPerShare()).to.eq('1000000000000000000');

      await vaultV2['deposit(uint256)'](deposit1);
      expect(await vaultV2.assetsPerShare()).to.eq('1250000000000000000');
    });
  });

  describe('#assetsOf', () => {
    it('should work', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');
      await setupBalance(core.hhUser1, deposit1);
      await setupBalance(core.hhUser2, deposit2);
      await setupBalance(core.hhUser3, reward1);

      await vaultV2.connect(core.hhUser1)['deposit(uint256)'](deposit1);

      expect(await vaultV2.assetsOf(core.hhUser1.address)).to.eq(deposit1);
      expect(await vaultV2.assetsOf(core.hhUser2.address)).to.eq('0');

      await WETH.connect(core.hhUser3).transfer(strategy.address, reward1);

      expect(await vaultV2.assetsOf(core.hhUser1.address)).to.eq(deposit1.add(reward1));
      expect(await vaultV2.assetsOf(core.hhUser2.address)).to.eq('0');

      await vaultV2.connect(core.hhUser2)['deposit(uint256)'](deposit2);

      expect(await vaultV2.assetsOf(core.hhUser2.address)).to.eq(deposit2);
    });
  });

  describe('#maxDeposit', () => {
    it('should work', async () => {
      expect(await vaultV2.maxDeposit(ethers.constants.AddressZero)).to.eq(ethers.constants.MaxUint256);
    });
  });

  describe('#previewDeposit', () => {
    it('should work', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');
      await setupBalance(core.hhUser1, deposit1);
      await setupBalance(core.hhUser2, deposit2);
      await setupBalance(core.hhUser3, reward1);

      expect(await vaultV2.previewDeposit(deposit1)).to.eq(deposit1);
      await vaultV2.connect(core.hhUser1)['deposit(uint256)'](deposit1);

      await WETH.connect(core.hhUser3).transfer(strategy.address, reward1);
      expect(await vaultV2.previewDeposit(deposit1)).to.eq(deposit1.mul('100').div('125'));
    });
  });

  describe('#deposit', () => {
    it('should work for various receivers', async () => {
      const depositFunction = 'deposit(uint256,address)';
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');

      await setupBalance(core.hhUser1, deposit1);
      await vaultV2.connect(core.hhUser1)[depositFunction](deposit1, core.hhUser1.address);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1);

      await setupBalance(core.hhUser3, reward1);
      await WETH.connect(core.hhUser3).transfer(vaultV2.address, reward1);

      await setupBalance(core.hhUser2, deposit2);
      await vaultV2.connect(core.hhUser2)[depositFunction](deposit2, core.hhUser1.address);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1.add(deposit2.mul('100').div('125')));
      expect(await vaultV2.balanceOf(core.hhUser2.address)).to.eq('0');
    });
  });

  describe('#maxMint', () => {
    it('should work', async () => {
      expect(await vaultV2.maxMint(ethers.constants.AddressZero)).to.eq(ethers.constants.MaxUint256);
    });
  });

  describe('#previewMint', () => {
    it('should work', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');
      await setupBalance(core.hhUser1, deposit1);
      await setupBalance(core.hhUser2, deposit2);
      await setupBalance(core.hhUser3, reward1);

      expect(await vaultV2.previewMint(deposit1)).to.eq(deposit1);
      await vaultV2.connect(core.hhUser1)['deposit(uint256)'](deposit1);

      await WETH.connect(core.hhUser3).transfer(strategy.address, reward1);
      expect(await vaultV2.previewMint(deposit1)).to.eq(deposit1.mul('125').div('100'));
    });
  });

  describe('#mint', () => {
    it('should work for various receivers', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');

      await setupBalance(core.hhUser1, deposit1);
      await vaultV2.connect(core.hhUser1).mint(deposit1, core.hhUser1.address);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1);

      await setupBalance(core.hhUser3, reward1);
      await WETH.connect(core.hhUser3).transfer(vaultV2.address, reward1);

      expect(await vaultV2.getPricePerFullShare()).to.eq('1250000000000000000');

      await setupBalance(core.hhUser2, deposit2);
      await expect(vaultV2.connect(core.hhUser2).mint(deposit2, core.hhUser1.address)).to.be.reverted;
      await vaultV2.connect(core.hhUser2).mint(deposit2.mul('100').div('125'), core.hhUser1.address);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1.add(deposit2.mul('100').div('125')));
      expect(await vaultV2.balanceOf(core.hhUser2.address)).to.eq('0');
    });
  });

  describe('#maxWithdraw', () => {
    it('should work', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');
      await setupBalance(core.hhUser1, deposit1);
      await setupBalance(core.hhUser2, deposit2);
      await setupBalance(core.hhUser3, reward1);

      await vaultV2.connect(core.hhUser1)['deposit(uint256)'](deposit1);

      await WETH.connect(core.hhUser3).transfer(strategy.address, reward1);
      expect(await vaultV2.previewDeposit(deposit1)).to.eq(deposit1.mul('100').div('125'));
    });
  });

  describe('#previewWithdraw', () => {
    it('should work', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');
      await setupBalance(core.hhUser1, deposit1);
      await setupBalance(core.hhUser2, deposit2);
      await setupBalance(core.hhUser3, reward1);

      expect(await vaultV2.previewWithdraw(deposit1)).to.eq(deposit1);
      await vaultV2['deposit(uint256)'](deposit1);

      await WETH.connect(core.hhUser3).transfer(strategy.address, reward1);
      expect(await vaultV2.previewWithdraw(deposit1)).to.eq(deposit1.mul('100').div('125'));
    });
  });

  describe('#withdraw', () => {
    it('should work', async () => {
      const depositFunction = 'deposit(uint256,address)';
      const withdrawFunction = 'withdraw(uint256,address,address)';
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');

      await setupBalance(core.hhUser1, deposit1);
      await vaultV2.connect(core.hhUser1)[depositFunction](deposit1, core.hhUser1.address);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1);

      await setupBalance(core.hhUser3, reward1);
      await WETH.connect(core.hhUser3).transfer(vaultV2.address, reward1);

      await setupBalance(core.hhUser2, deposit2);
      await vaultV2.connect(core.hhUser2)[depositFunction](deposit2, core.hhUser1.address);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1.add(deposit2.mul('100').div('125')));
      expect(await vaultV2.balanceOf(core.hhUser2.address)).to.eq('0');

      await vaultV2.connect(core.hhUser1)[withdrawFunction](
        deposit1,
        core.hhUser3.address,
        core.hhUser1.address,
      );

      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq('1800000000000000000');
      expect(await WETH.connect(core.hhUser1).balanceOf(core.hhUser3.address)).to.eq(deposit1);

      await expect(
        vaultV2.connect(core.hhUser2)[withdrawFunction](
          deposit1,
          core.hhUser3.address,
          core.hhUser1.address,
        ),
      ).to.be.revertedWith('ERC20: transfer amount exceeds allowance');

      await vaultV2.connect(core.hhUser1).approve(core.hhUser2.address, ethers.constants.MaxUint256);

      await vaultV2.connect(core.hhUser2)[withdrawFunction](
        deposit1.div(2),
        core.hhUser1.address,
        core.hhUser1.address,
      );

      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq('1400000000000000000');
      expect(await WETH.connect(core.hhUser1).balanceOf(core.hhUser1.address)).to.eq(deposit1.div(2));
    });
  });

  describe('#maxRedeem', () => {
    it('should work', async () => {
      expect(await vaultV2.maxRedeem(ethers.constants.AddressZero)).to.eq(0);
      expect(await vaultV2.maxRedeem(core.hhUser1.address)).to.eq(0);
    });
  });

  describe('#previewRedeem', () => {
    it('should work', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');
      await setupBalance(core.hhUser1, deposit1);
      await setupBalance(core.hhUser2, deposit2);
      await setupBalance(core.hhUser3, reward1);

      expect(await vaultV2.previewWithdraw(deposit1)).to.eq(deposit1);
      await vaultV2['deposit(uint256)'](deposit1);

      await WETH.connect(core.hhUser3).transfer(strategy.address, reward1);
      expect(await vaultV2.previewRedeem(deposit1)).to.eq(deposit1.mul('125').div('100'));
    });
  });

  describe('#redeem', () => {
    it('should work', async () => {
      const depositFunction = 'deposit(uint256,address)';
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000');

      await setupBalance(core.hhUser1, deposit1);
      await vaultV2.connect(core.hhUser1)[depositFunction](deposit1, core.hhUser1.address);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1);

      await setupBalance(core.hhUser3, reward1);
      await WETH.connect(core.hhUser3).transfer(vaultV2.address, reward1);

      await setupBalance(core.hhUser2, deposit2);
      await vaultV2.connect(core.hhUser2)[depositFunction](deposit2, core.hhUser1.address);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1.add(deposit2.mul('100').div('125')));
      expect(await vaultV2.balanceOf(core.hhUser2.address)).to.eq('0');

      await vaultV2.connect(core.hhUser1)
        .redeem(deposit1.mul('100').div('125'), core.hhUser3.address, core.hhUser1.address);

      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq('1800000000000000000');
      expect(await WETH.connect(core.hhUser1).balanceOf(core.hhUser3.address)).to.eq(deposit1);

      await expect(
        vaultV2.connect(core.hhUser2).redeem(deposit1, core.hhUser3.address, core.hhUser1.address),
      ).to.be.revertedWith('ERC20: transfer amount exceeds allowance');

      await vaultV2.connect(core.hhUser1).approve(core.hhUser2.address, ethers.constants.MaxUint256);

      await vaultV2.connect(core.hhUser2).redeem(deposit1.div(2), core.hhUser1.address, core.hhUser1.address);

      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq('1300000000000000000');
      expect(await WETH.connect(core.hhUser1).balanceOf(core.hhUser1.address))
        .to
        .eq(deposit1.div(2).mul('125').div('100'));
    });
  });
});
