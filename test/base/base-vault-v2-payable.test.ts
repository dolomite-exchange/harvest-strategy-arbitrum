// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import {
  IVault,
  StrategyProxy,
  TestRewardPool,
  TestStrategy,
  VaultProxy,
  VaultV2,
  VaultV2Payable,
} from '../../src/types';
import { USDC, WETH } from '../../src/utils/constants';
import { CoreProtocol, createStrategy, createVault, setupCoreProtocol } from '../../src/utils/harvest-utils';
import { revertToSnapshotAndCapture, snapshot } from '../../src/utils/utils';


describe('VaultV2Payable', () => {
  let core: CoreProtocol;
  let vaultV2: VaultV2;
  let vaultProxy: VaultProxy;
  let vaultPayable: VaultV2Payable;
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
    const vaultV2Implementation = await VaultV2Factory.deploy() as IVault;
    [vaultProxy, , vaultV2] = await createVault(vaultV2Implementation, core, WETH);

    const VaultV2PayableFactory = await ethers.getContractFactory('VaultV2Payable');
    vaultPayable = await VaultV2PayableFactory.deploy(vaultProxy.address) as VaultV2Payable;

    const TestRewardPoolFactory = await ethers.getContractFactory('TestRewardPool');
    rewardPool = await TestRewardPoolFactory.deploy(WETH.address, USDC.address) as TestRewardPool;

    strategist = core.hhUser1;
    [strategyProxy, strategy] = await createStrategy<TestStrategy>('TestStrategy');
    await strategy.initializeBaseStrategy(
      core.storage.address,
      WETH.address,
      vaultProxy.address,
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
      expect(await vaultPayable.vault()).to.eq(vaultProxy.address);
    });
  });

  describe('#deposit/#withdraw/#rebalance', () => {
    const setupBalance = async (user: SignerWithAddress, balance: BigNumber) => {
      await WETH.connect(user).deposit({ value: balance });
      await WETH.connect(user).approve(vaultProxy.address, balance);
    }

    it('should work', async () => {
      const deposit1 = ethers.BigNumber.from('1000000000000000000');
      const deposit2 = ethers.BigNumber.from('2000000000000000000');
      const deposit3 = ethers.BigNumber.from('3000000000000000000');
      const reward1 = ethers.BigNumber.from('250000000000000000'); // 0.25
      const total1 = deposit1.add(deposit2);
      const total2 = total1.add(deposit3);

      const result1 = await vaultPayable.connect(core.hhUser1)
        .depositWithETH(core.hhUser1.address, { value: deposit1 });
      await expect(result1).to.emit(vaultV2, 'Deposit')
        .withArgs(vaultPayable.address, core.hhUser1.address, deposit1, deposit1);
      expect(await vaultV2.balanceOf(core.hhUser1.address)).to.eq(deposit1);
      expect(await WETH.connect(core.hhUser1).balanceOf(vaultV2.address)).to.eq(deposit1);

      await setupBalance(core.hhUser5, deposit1);
      await WETH.connect(core.hhUser5).transfer(strategy.address, reward1);
      expect(await vaultV2.underlyingBalanceWithInvestment()).to.eq(deposit1.add(reward1));

      const result2 = await vaultPayable.connect(core.hhUser2)
        .depositWithETH(core.hhUser2.address, { value: deposit2 });
      const balance2 = '1600000000000000000'; // this is the user's shares (equity) of the vault
      await expect(result2).to.emit(vaultV2, 'Deposit')
        .withArgs(vaultPayable.address, core.hhUser2.address, deposit2, balance2);
      expect(await vaultV2.balanceOf(core.hhUser2.address)).to.eq(balance2);
      expect(await WETH.connect(core.hhUser2).balanceOf(vaultV2.address)).to.eq(total1);
      expect(await vaultV2.underlyingBalanceWithInvestment()).to.eq(total1.add(reward1));
      expect(await vaultV2.getPricePerFullShare()).to.eq('1250000000000000000');

      // re-balancing keeps 0.5% in the vault and 99.5% in the strategy
      const result3 = await vaultV2.connect(core.governance).rebalance();
      const toInvestAmount = ethers.BigNumber.from('3233750000000000000').sub(reward1);
      await expect(result3).to.emit(vaultV2, 'Invest').withArgs(toInvestAmount);
      expect(await vaultV2.underlyingBalanceWithInvestment()).to.eq(total1.add(reward1));
      const balanceInVault = total1.sub(toInvestAmount);
      expect(await vaultV2.underlyingBalanceInVault()).to.eq(balanceInVault);

      const result4 = await vaultPayable.connect(core.hhUser3)
        .depositWithETH(core.hhUser4.address, { value: deposit3 });
      const balance3 = '2400000000000000000'; // this is the user's shares (equity) of the vault
      await expect(result4).to.emit(vaultV2, 'Deposit')
        .withArgs(vaultPayable.address, core.hhUser4.address, deposit3, balance3);
      expect(await vaultV2.balanceOf(core.hhUser3.address)).to.eq(0);
      expect(await vaultV2.balanceOf(core.hhUser4.address)).to.eq(balance3);
      expect(await WETH.connect(core.hhUser3).balanceOf(vaultV2.address)).to.eq(deposit3.add(balanceInVault));
      expect(await vaultV2.underlyingBalanceWithInvestment()).to.eq(total2.add(reward1));
      expect(await vaultV2.getPricePerFullShare()).to.eq('1250000000000000000');

      const receiver1 = '0x0000000123000000000000000000000000000123';
      const receiver2 = '0x0000000321000000000000000000000000000321';

      await expect(vaultPayable.connect(core.hhUser1)
        .withdrawToETH(deposit1.div(2), receiver1, core.hhUser4.address))
        .to.revertedWith('VaultV2PayableProxy: msg.sender is not a trusted operator for owner');

      await expect(vaultPayable.connect(core.hhUser4).setTrustedOperator(core.hhUser1.address, true))
        .to.emit(vaultPayable, 'OperatorSet').withArgs(core.hhUser4.address, core.hhUser1.address, true);
      expect(await vaultPayable.trustedOperators(core.hhUser4.address, core.hhUser1.address)).to.eq(true);

      await expect(vaultPayable.connect(core.hhUser1)
        .withdrawToETH(deposit1.div(2), receiver1, core.hhUser4.address))
        .to.revertedWith('ERC20: transfer amount exceeds allowance');

      await vaultV2.connect(core.hhUser4).approve(vaultPayable.address, ethers.constants.MaxUint256);

      const result5 = await vaultPayable.connect(core.hhUser1)
        .withdrawToETH(deposit1.div(2), receiver1, core.hhUser4.address);
      await expect(result5).to.emit(vaultV2, 'Withdraw')
        .withArgs(
          vaultPayable.address,
          vaultPayable.address,
          core.hhUser4.address,
          deposit1.div(2),
          deposit1.mul('100').div('125').div(2),
        );
      expect(await vaultV2.totalSupply()).to.eq('4600000000000000000');
      expect(await vaultV2.balanceOf(core.hhUser4.address)).to.eq('2000000000000000000');
      expect(await vaultV2.underlyingBalanceWithInvestment()).to.eq('5750000000000000000');
      expect(await WETH.connect(core.hhUser4).balanceOf(core.hhUser4.address)).to.eq('0');
      expect(await ethers.provider.getBalance(receiver1)).to.eq('500000000000000000');

      const result6 = await vaultPayable.connect(core.hhUser1)
        .redeemToETH(deposit1.div(2), receiver1, core.hhUser4.address);
      await expect(result6).to.emit(vaultV2, 'Withdraw')
        .withArgs(
          vaultPayable.address,
          vaultPayable.address,
          core.hhUser4.address,
          deposit1.mul('125').div('100').div(2),
          deposit1.div(2),
        );
      expect(await vaultV2.totalSupply()).to.eq('4100000000000000000');
      expect(await vaultV2.balanceOf(core.hhUser4.address)).to.eq('1500000000000000000');
      expect(await vaultV2.underlyingBalanceWithInvestment()).to.eq('5125000000000000000');
      expect(await ethers.provider.getBalance(receiver1)).to.eq('1125000000000000000');

      await vaultV2.connect(core.hhUser2).approve(vaultPayable.address, ethers.constants.MaxUint256);

      const result7 = await vaultPayable.connect(core.hhUser2).withdrawToETH(
        deposit2.div(2),
        receiver2,
        core.hhUser2.address,
      );
      await expect(result7).to.emit(vaultV2, 'Withdraw')
        .withArgs(
          vaultPayable.address,
          vaultPayable.address,
          core.hhUser2.address,
          deposit2.div(2),
          deposit2.div(2).mul('100').div('125'),
        );
      expect(await vaultV2.totalSupply()).to.eq('3300000000000000000');
      expect(await vaultV2.balanceOf(core.hhUser2.address)).to.eq('800000000000000000');
      expect(await vaultV2.underlyingBalanceWithInvestment()).to.eq('4125000000000000000');
      expect(await WETH.connect(core.hhUser2).balanceOf(receiver2)).to.eq(0);
      expect(await ethers.provider.getBalance(receiver2)).to.eq(deposit2.div(2));

      const result8 = await vaultPayable.connect(core.hhUser2).redeemToETH(
        deposit2.div(2).mul('100').div('125'),
        receiver2,
        core.hhUser2.address,
      );
      await expect(result8).to.emit(vaultV2, 'Withdraw')
        .withArgs(
          vaultPayable.address,
          vaultPayable.address,
          core.hhUser2.address,
          deposit2.div(2),
          deposit2.div(2).mul('100').div('125'),
        );
      expect(await vaultV2.totalSupply()).to.eq('2500000000000000000');
      expect(await vaultV2.balanceOf(core.hhUser2.address)).to.eq('0');
      expect(await vaultV2.underlyingBalanceWithInvestment()).to.eq('3125000000000000000');
      expect(await WETH.connect(core.hhUser2).balanceOf(core.hhUser2.address)).to.eq(0);
      expect(await ethers.provider.getBalance(receiver2)).to.eq(deposit2);
    });
  });
});
