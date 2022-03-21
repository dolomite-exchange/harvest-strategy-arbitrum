// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BaseContract, BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import {
  IVault,
  StrategyProxy,
  TestRewardPool,
  TestStrategy,
  VaultProxy,
  VaultV2Payable,
  VaultV2Payable__factory,
} from '../../src/types';
import { USDC, WETH } from '../utilities/constants';
import { CoreProtocol, createStrategy, setupCoreProtocol } from '../utilities/harvest-utils';
import { revertToSnapshotAndCapture, snapshot } from '../utilities/utils';


describe('VaultV2Payable', () => {
  let core: CoreProtocol;
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

    const TestStrategyFactory = await ethers.getContractFactory('TestStrategy');
    const testStrategyImplementation = await TestStrategyFactory.deploy() as TestStrategy;

    const VaultV2PayableFactory = await ethers.getContractFactory('VaultV2Payable');
    const v2PayableImplementation = await VaultV2PayableFactory.deploy() as IVault;

    const VaultProxyFactory = await ethers.getContractFactory('VaultProxy');
    vaultProxy = await VaultProxyFactory.deploy(v2PayableImplementation.address) as VaultProxy;
    vaultPayable = new BaseContract(
      vaultProxy.address,
      VaultV2Payable__factory.createInterface(),
      v2PayableImplementation.signer,
    ) as VaultV2Payable;

    await vaultPayable.initializeVault(
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
      vaultPayable.address,
      rewardPool.address,
      [USDC.address],
      strategist.address,
    );
    await vaultPayable.connect(core.governance).setStrategy(strategy.address);

    snapshotId = await snapshot();
  });

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('Deployment', () => {
    it('should work', async () => {
      expect(await vaultPayable.strategy()).to.eq(strategy.address);
      expect(await vaultPayable.underlying()).to.eq(WETH.address);
      expect(await vaultPayable.underlyingUnit()).to.eq(ethers.constants.WeiPerEther);
      expect(await vaultPayable.vaultFractionToInvestNumerator()).to.eq('995');
      expect(await vaultPayable.vaultFractionToInvestDenominator()).to.eq('1000');
      expect(await vaultPayable.nextImplementation()).to.eq(ethers.constants.AddressZero);
      expect(await vaultPayable.nextImplementationTimestamp()).to.eq('0');
      expect(await vaultPayable.nextImplementationDelay()).to.eq(core.controllerParams.implementationDelaySeconds);
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

      await setupBalance(core.hhUser1, deposit1);
      // deposit 2 uses ETH, which doesn't need setup
      await setupBalance(core.hhUser3, deposit3);

      const depositFunction = 'deposit(uint256)';
      const result1 = await vaultPayable.connect(core.hhUser1)[depositFunction](deposit1);
      await expect(result1).to.emit(vaultPayable, 'Deposit')
        .withArgs(core.hhUser1.address, core.hhUser1.address, deposit1, deposit1);
      expect(await vaultPayable.balanceOf(core.hhUser1.address)).to.eq(deposit1);
      expect(await WETH.connect(core.hhUser1).balanceOf(vaultPayable.address)).to.eq(deposit1);

      await setupBalance(core.hhUser5, deposit1);
      await WETH.connect(core.hhUser5).transfer(strategy.address, reward1);
      expect(await vaultPayable.underlyingBalanceWithInvestment()).to.eq(deposit1.add(reward1));

      const result2 = await vaultPayable.connect(core.hhUser2)
        .depositWithETH(core.hhUser2.address, { value: deposit2 });
      const balance2 = '1600000000000000000'; // this is the user's shares (equity) of the vault
      await expect(result2).to.emit(vaultPayable, 'Deposit')
        .withArgs(core.hhUser2.address, core.hhUser2.address, deposit2, balance2);
      expect(await vaultPayable.balanceOf(core.hhUser2.address)).to.eq(balance2);
      expect(await WETH.connect(core.hhUser2).balanceOf(vaultPayable.address)).to.eq(total1);
      expect(await vaultPayable.underlyingBalanceWithInvestment()).to.eq(total1.add(reward1));
      expect(await vaultPayable.getPricePerFullShare()).to.eq('1250000000000000000');

      // re-balancing keeps 0.5% in the vault and 99.5% in the strategy
      const result3 = await vaultPayable.connect(core.governance).rebalance();
      const toInvestAmount = ethers.BigNumber.from('3233750000000000000').sub(reward1);
      await expect(result3).to.emit(vaultPayable, 'Invest').withArgs(toInvestAmount);
      expect(await vaultPayable.underlyingBalanceWithInvestment()).to.eq(total1.add(reward1));
      const balanceInVault = total1.sub(toInvestAmount);
      expect(await vaultPayable.underlyingBalanceInVault()).to.eq(balanceInVault);

      const result4 = await vaultPayable.connect(core.hhUser3)
        .depositWithETH(core.hhUser4.address, { value: deposit3 });
      const balance3 = '2400000000000000000'; // this is the user's shares (equity) of the vault
      await expect(result4).to.emit(vaultPayable, 'Deposit')
        .withArgs(core.hhUser3.address, core.hhUser4.address, deposit3, balance3);
      expect(await vaultPayable.balanceOf(core.hhUser3.address)).to.eq(0);
      expect(await vaultPayable.balanceOf(core.hhUser4.address)).to.eq(balance3);
      expect(await WETH.connect(core.hhUser3).balanceOf(vaultPayable.address)).to.eq(deposit3.add(balanceInVault));
      expect(await vaultPayable.underlyingBalanceWithInvestment()).to.eq(total2.add(reward1));
      expect(await vaultPayable.getPricePerFullShare()).to.eq('1250000000000000000');

      const receiver = '0x0000000123000000000000000000000000000321';
      await expect(vaultPayable.connect(core.hhUser1)
        .withdrawToETH(deposit1.div(2), receiver, core.hhUser4.address))
        .to.revertedWith('ERC20: transfer amount exceeds allowance');
      await vaultPayable.connect(core.hhUser4).approve(core.hhUser1.address, ethers.constants.MaxUint256);
      const result5 = await vaultPayable.connect(core.hhUser1)
        .withdrawToETH(deposit1.div(2), receiver, core.hhUser4.address);
      await expect(result5).to.emit(vaultPayable, 'Withdraw')
        .withArgs(
          core.hhUser1.address,
          receiver,
          core.hhUser4.address,
          deposit1.div(2),
          deposit1.mul('100').div('125').div(2),
        );
      expect(await vaultPayable.totalSupply()).to.eq('4600000000000000000');
      expect(await vaultPayable.balanceOf(core.hhUser4.address)).to.eq('2000000000000000000');
      expect(await vaultPayable.underlyingBalanceWithInvestment()).to.eq('5750000000000000000');
      expect(await WETH.connect(core.hhUser4).balanceOf(core.hhUser4.address)).to.eq('0');
      expect(await ethers.provider.getBalance(receiver)).to.eq('500000000000000000');

      const result6 = await vaultPayable.connect(core.hhUser1)
        .redeemToETH(deposit1.div(2), receiver, core.hhUser4.address);
      await expect(result6).to.emit(vaultPayable, 'Withdraw')
        .withArgs(
          core.hhUser1.address,
          receiver,
          core.hhUser4.address,
          deposit1.mul('125').div('100').div(2),
          deposit1.div(2),
        );
      expect(await vaultPayable.totalSupply()).to.eq('4100000000000000000');
      expect(await vaultPayable.balanceOf(core.hhUser4.address)).to.eq('1500000000000000000');
      expect(await vaultPayable.underlyingBalanceWithInvestment()).to.eq('5125000000000000000');
      expect(await ethers.provider.getBalance(receiver)).to.eq('1125000000000000000');

      const withdrawFunction = 'withdraw(uint256,address,address)';
      const result7 = await vaultPayable.connect(core.hhUser2)[withdrawFunction](
        deposit2.div(2),
        core.hhUser2.address,
        core.hhUser2.address,
      );
      await expect(result7).to.emit(vaultPayable, 'Withdraw')
        .withArgs(
          core.hhUser2.address,
          core.hhUser2.address,
          core.hhUser2.address,
          deposit2.div(2),
          deposit2.div(2).mul('100').div('125'),
        );
      expect(await vaultPayable.totalSupply()).to.eq('3300000000000000000');
      expect(await vaultPayable.balanceOf(core.hhUser2.address)).to.eq('800000000000000000');
      expect(await vaultPayable.underlyingBalanceWithInvestment()).to.eq('4125000000000000000');
      expect(await WETH.connect(core.hhUser2).balanceOf(core.hhUser2.address)).to.eq(deposit2.div(2));

      const result8 = await vaultPayable.connect(core.hhUser2).redeem(
        deposit2.div(2).mul('100').div('125'),
        core.hhUser2.address,
        core.hhUser2.address,
      );
      await expect(result8).to.emit(vaultPayable, 'Withdraw')
        .withArgs(
          core.hhUser2.address,
          core.hhUser2.address,
          core.hhUser2.address,
          deposit2.div(2),
          deposit2.div(2).mul('100').div('125'),
        );
      expect(await vaultPayable.totalSupply()).to.eq('2500000000000000000');
      expect(await vaultPayable.balanceOf(core.hhUser2.address)).to.eq('0');
      expect(await vaultPayable.underlyingBalanceWithInvestment()).to.eq('3125000000000000000');
      expect(await WETH.connect(core.hhUser2).balanceOf(core.hhUser2.address)).to.eq(deposit2);
    });
  });
});
