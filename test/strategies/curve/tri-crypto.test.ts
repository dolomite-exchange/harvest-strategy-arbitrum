// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers, web3 } from 'hardhat';
import { IGauge, IVault, StrategyProxy, TriCryptoStrategyMainnet, VaultV1 } from '../../../src/types/index';
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
import {
  checkHardWorkResults,
  CoreProtocol,
  createStrategy,
  createVault,
  depositIntoVault,
  getReceivedAmountBeforeHardWork,
  setupCoreProtocol,
  setupWETHBalance,
} from '../../utilities/harvest-utils';
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
  let gauge: IGauge;

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
    gauge = CRV_TRI_CRYPTO_GAUGE.connect(core.governance);

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

  describe('deposit and compound', () => {
    it('should work', async () => {
      const amount = ethers.BigNumber.from('1000000000000000000');
      await setupWETHBalance(user, amount, CRV_TRI_CRYPTO_POOL);
      await CRV_TRI_CRYPTO_POOL.connect(user).add_liquidity([0, 0, amount], '0');

      const lpBalance1 = await CRV_TRI_CRYPTO.connect(user).balanceOf(user.address);
      await depositIntoVault(user, CRV_TRI_CRYPTO, vaultV1, lpBalance1);

      await vaultV1.connect(core.governance).rebalance(); // move funds to the strategy
      await triCryptoStrategy.connect(core.governance).enterRewardPool(); // deposit strategy funds into CRV

      const lpBalanceAfterFees = lpBalance1.mul('995').div('1000');
      expect(await gauge.balanceOf(strategyProxy.address)).to.eq(lpBalanceAfterFees);

      expect(await triCryptoStrategy.callStatic.getRewardPoolValues()).to.eql([ethers.constants.Zero]);

      const crvWhale = await impersonate(CrvWhaleAddress);
      await CRV.connect(crvWhale).transfer(CRV_REWARD_NOTIFIER.address, '20000000000000000000000');
      await CRV.connect(crvWhale).approve(core.universalLiquidator.address, ethers.constants.MaxUint256);

      const rewardDistributor = await impersonate(CrvDistributorAddress);
      await CRV_REWARD_NOTIFIER.connect(rewardDistributor).notify_reward_amount(CRV.address);

      const waitDurationSeconds = (86400 * 3) + 43200; // 3.5 days
      await waitTime(waitDurationSeconds);

      const crvReward = (await triCryptoStrategy.callStatic.getRewardPoolValues())[0];
      const receivedWETH = await getReceivedAmountBeforeHardWork(core, crvWhale, CRV, crvReward);

      const result = await core.controller.connect(core.governance)
        .doHardWork(vaultV1.address, ethers.constants.WeiPerEther, '101', '100');
      const latestTimestamp = await getLatestTimestamp();

      const priceFullShare = await vaultV1.getPricePerFullShare();

      await expect(result).to.emit(core.controller, 'SharePriceChangeLog')
        .withArgs(vaultV1.address, strategyProxy.address, '1000000000000000000', priceFullShare, latestTimestamp);
      expect(priceFullShare).to.be.gt('1000000000000000000');

      const lpBalance2 = await vaultV1.underlyingBalanceWithInvestment();

      const amountHeldInVault = lpBalance1.sub(lpBalance1.mul('995').div('1000'));
      expect(await gauge.balanceOf(strategyProxy.address)).to.eq(lpBalance2.sub(amountHeldInVault));

      const apr = calculateApr(lpBalance2, lpBalance1, waitDurationSeconds);
      const apy = calculateApy(lpBalance2, lpBalance1, waitDurationSeconds);
      const balanceDelta = lpBalance2.sub(lpBalance1).toString();

      console.log('\tTriCrypto LP-CRV Before', lpBalance1.toString(), `(${web3.utils.fromWei(lpBalance1.toString())})`);
      console.log('\tTriCrypto LP-CRV After', lpBalance2.toString(), `(${web3.utils.fromWei(lpBalance2.toString())})`);
      console.log('\tTriCrypto LP-CRV Earned', balanceDelta, `(${web3.utils.fromWei(balanceDelta)})`);
      console.log('\tTriCrypto LP-CRV APR', `${web3.utils.fromWei(apr.mul(100).toString())}%`);
      console.log('\tTriCrypto LP-CRV APY', `${web3.utils.fromWei(apy.mul(100).toString())}%`);

      const expectedApr = ethers.BigNumber.from('77000000000000000'); // 7.7%
      const expectedApy = ethers.BigNumber.from('80000000000000000'); // 8.0%

      expect(lpBalance2).to.be.gt(lpBalance1);
      expect(apr).to.be.gt(expectedApr);
      expect(apy).to.be.gt(expectedApy);

      // check the platform fee and strategist fees accrued properly
      await checkHardWorkResults(core, receivedWETH);
    });
  });
});
