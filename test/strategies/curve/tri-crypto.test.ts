// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumberish } from 'ethers';
import { ethers, web3 } from 'hardhat';
import { IVault, StrategyProxy, TriCryptoStrategyMainnet, VaultV1 } from '../../../src/types/index';
import {
  CRV,
  CRV_REWARD_NOTIFIER,
  CRV_TRI_CRYPTO,
  CRV_TRI_CRYPTO_GAUGE,
  CRV_TRI_CRYPTO_POOL,
  CrvDistributorAddress,
  CrvWhaleAddress,
  WETH,
} from '../../utilities/constants';
import { CoreProtocol, createStrategy, createVault, setupCoreProtocol } from '../../utilities/harvest-utils';
import {
  calculateApr,
  calculateApy,
  getLatestTimestamp,
  impersonate,
  revertToSnapshotAndCapture,
  snapshot,
  waitTime,
} from '../../utilities/utils';

describe('TriCryptoStrategy', () => {

  let core: CoreProtocol;
  let strategyProxy: StrategyProxy;
  let triCryptoStrategy: TriCryptoStrategyMainnet;
  let vaultV1: VaultV1;

  let user: SignerWithAddress;

  let snapshotId: string;

  before(async () => {
    core = await setupCoreProtocol({
      blockNumber: 8216000,
    });
    const TriCryptoStrategyMainnetFactory = await ethers.getContractFactory('TriCryptoStrategyMainnet');
    const strategyImplementation = await TriCryptoStrategyMainnetFactory.deploy() as TriCryptoStrategyMainnet;
    [strategyProxy, triCryptoStrategy] = await createStrategy(strategyImplementation);

    const VaultV1Factory = await ethers.getContractFactory('VaultV1');
    const vaultImplementation = await VaultV1Factory.deploy() as IVault;
    [, vaultV1] = await createVault(vaultImplementation, core, CRV_TRI_CRYPTO);
    await triCryptoStrategy.connect(core.governance)
      .initializeMainnetStrategy(core.storage.address, vaultV1.address, core.strategist.address);
    await core.controller.connect(core.governance).addVaultAndStrategy(vaultV1.address, strategyProxy.address);

    user = await ethers.getSigner(core.hhUser1.address);

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#deployment', () => {
    it('should work properly', async () => {
      expect(await triCryptoStrategy.controller()).to.eq(core.controller.address);
      expect(await triCryptoStrategy.governance()).to.eq(core.governance.address);
      expect(await triCryptoStrategy.underlying()).to.eq(CRV_TRI_CRYPTO.address);
      expect(await triCryptoStrategy.vault()).to.eq(vaultV1.address);
      expect(await triCryptoStrategy.rewardPool()).to.eq(CRV_TRI_CRYPTO_GAUGE.address);
      expect(await triCryptoStrategy.rewardTokens()).to.eql([CRV.address]);
      expect(await triCryptoStrategy.strategist()).to.eq(core.strategist.address);
      expect(await triCryptoStrategy.curveDeposit()).to.eq(CRV_TRI_CRYPTO_POOL.address);
      expect(await triCryptoStrategy.depositToken()).to.eq(WETH.address);
      expect(await triCryptoStrategy.depositArrayPosition()).to.eq(2);
    });
  });

  const setupWETHBalance = async (signer: SignerWithAddress, amount: BigNumberish) => {
    await WETH.connect(signer).deposit({ value: amount });
    await WETH.connect(signer).approve(CRV_TRI_CRYPTO_POOL.address, ethers.constants.MaxUint256);
  }

  describe('deposit and compound', () => {
    it('should work', async () => {
      const amount = ethers.BigNumber.from('1000000000000000000');
      await setupWETHBalance(user, amount);
      await CRV_TRI_CRYPTO_POOL.connect(user).add_liquidity([0, 0, amount], '0');
      await CRV_TRI_CRYPTO.connect(user).approve(vaultV1.address, ethers.constants.MaxUint256);

      const lpBalance = await CRV_TRI_CRYPTO.connect(user).balanceOf(user.address);
      await vaultV1.connect(user).deposit(lpBalance);
      expect(await CRV_TRI_CRYPTO.connect(core.governance).balanceOf(vaultV1.address)).to.eq(lpBalance);
      await vaultV1.connect(core.governance).rebalance();
      await triCryptoStrategy.connect(core.governance).enterRewardPool();

      const lpBalanceAfterFees = lpBalance.mul('995').div('1000');
      expect(await CRV_TRI_CRYPTO_GAUGE.connect(core.governance).balanceOf(strategyProxy.address))
        .to
        .eq(lpBalanceAfterFees);

      expect(await CRV_TRI_CRYPTO_GAUGE.connect(core.governance).claimable_reward(strategyProxy.address, CRV.address))
        .to
        .eq('0');

      const crvWhale = await impersonate(CrvWhaleAddress);
      await CRV.connect(crvWhale).transfer(CRV_REWARD_NOTIFIER.address, '20000000000000000000000');
      await CRV.connect(crvWhale).approve(core.universalLiquidator.address, ethers.constants.MaxUint256);

      const rewardDistributor = await impersonate(CrvDistributorAddress);
      await CRV_REWARD_NOTIFIER.connect(rewardDistributor).notify_reward_amount(CRV.address);

      const waitDurationSeconds = (86400 * 3) + 43200; // 3.5 days
      await waitTime(waitDurationSeconds);

      const crvReward = (await triCryptoStrategy.connect(core.governance).callStatic.getRewardPoolValues())[0];
      const receivedWETH = await core.universalLiquidator.connect(crvWhale).callStatic.swapTokens(
        CRV.address,
        WETH.address,
        crvReward,
        '1',
        core.rewardForwarder.address,
      );

      const result = await core.controller.connect(core.governance)
        .doHardWork(vaultV1.address, ethers.constants.WeiPerEther, '101', '100');
      const latestTimestamp = await getLatestTimestamp();

      const priceFullShare = await vaultV1.getPricePerFullShare();

      await expect(result).to.emit(core.controller, 'SharePriceChangeLog')
        .withArgs(vaultV1.address, strategyProxy.address, '1000000000000000000', priceFullShare, latestTimestamp);

      const balanceNow = await vaultV1.underlyingBalanceWithInvestment();

      const amountHeldInVault = lpBalance.sub(lpBalance.mul('995').div('1000'));
      expect(await CRV_TRI_CRYPTO_GAUGE.connect(core.governance).balanceOf(strategyProxy.address))
        .to
        .eq(balanceNow.sub(amountHeldInVault));

      const apr = calculateApr(balanceNow, lpBalance, waitDurationSeconds);
      const apy = calculateApy(balanceNow, lpBalance, waitDurationSeconds);
      const balanceDelta = balanceNow.sub(lpBalance).toString();

      console.log('\tTriCrypto LP-CRV Before', lpBalance.toString(), `(${web3.utils.fromWei(lpBalance.toString())})`);
      console.log('\tTriCrypto LP-CRV After', balanceNow.toString(), `(${web3.utils.fromWei(balanceNow.toString())})`);
      console.log('\tTriCrypto LP-CRV Earned', balanceDelta, `(${web3.utils.fromWei(balanceDelta)})`);
      console.log('\tTriCrypto LP-CRV APR', `${web3.utils.fromWei(apr.mul(100).toString())}%`);
      console.log('\tTriCrypto LP-CRV APY', `${web3.utils.fromWei(apy.mul(100).toString())}%`);

      const expectedApr = ethers.BigNumber.from('77000000000000000'); // 7.7%
      const expectedApy = ethers.BigNumber.from('80000000000000000'); // 8.0%

      expect(balanceNow).to.be.gt(lpBalance);
      expect(apr).to.be.gt(expectedApr);
      expect(apy).to.be.gt(expectedApy);

      // check the platform fee and strategist fees accrued properly
      const weth = WETH.connect(core.governance);
      expect(await weth.balanceOf(core.profitSharingReceiver.address)).to.be.gte(receivedWETH.mul('15').div('100'));
      expect(await weth.balanceOf(core.strategist.address)).to.be.gte(receivedWETH.mul('5').div('100'));
      expect(await weth.balanceOf(core.governance.address)).to.be.gte(receivedWETH.mul('5').div('100'));
    });
  });
});
