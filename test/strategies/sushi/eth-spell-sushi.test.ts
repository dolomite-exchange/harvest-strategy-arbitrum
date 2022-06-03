import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BaseContract } from 'ethers';
import { ethers } from 'hardhat';
import {
  EthSpellSushiStrategyMainnet,
  IMiniChefV2,
  IUniswapV2Pair,
  IUniswapV2Pair__factory,
  IUniversalLiquidatorV2,
  IVault,
  StrategyProxy,
  VaultV2,
} from '../../../src/types';
import {
  ETH_SPELL_SLP,
  SPELL,
  SUSHI,
  SUSHI_MINI_CHEF,
  SUSHI_ROUTER,
  SushiWhaleAddress,
  WETH,
} from '../../../src/utils/constants';
import {
  checkHardWorkResults,
  CoreProtocol,
  CoreProtocolSetupConfigV2,
  createStrategy,
  createVault,
  depositIntoVault,
  doHardWork,
  getReceivedAmountBeforeHardWork,
  logYieldData,
  setupCoreProtocol,
  setupSPELLBalance,
  setupWETHBalance,
} from '../../../src/utils/harvest-utils';
import {
  calculateApr,
  calculateApy,
  getLatestTimestamp,
  impersonate,
  revertToSnapshotAndCapture,
  snapshot,
  waitTime,
} from '../../../src/utils/utils';
import { rewardPoolBalanceOf } from './sushi-utils';

const strategyName = 'EthSpellSushi';
describe(strategyName, () => {

  let core: CoreProtocol;
  let strategyProxy: StrategyProxy;
  let strategyMainnet: EthSpellSushiStrategyMainnet;
  let vaultV2: VaultV2;
  let rewardPool: IMiniChefV2;

  let user: SignerWithAddress;

  let snapshotId: string;

  const underlyingToken = ETH_SPELL_SLP;
  const pid = 11;
  const tokenA = WETH;
  const tokenB = SPELL;
  const tokenAAmount = ethers.BigNumber.from('1000000000000000000'); // 1 ETH
  const tokenBAmount = ethers.BigNumber.from('1436490000000000000000000'); // 1436490 SPELL

  before(async () => {
    core = await setupCoreProtocol({
      ...CoreProtocolSetupConfigV2,
      blockNumber: 12882300,
    });
    const UniversalLiquidatorV2Factory = await ethers.getContractFactory('UniversalLiquidatorV2');
    const newUniversalLiquidator = await UniversalLiquidatorV2Factory.deploy();
    await core.universalLiquidator.connect(core.governance).scheduleUpgrade(newUniversalLiquidator.address);
    await core.universalLiquidatorProxy.connect(core.governance).upgrade();
    await (core.universalLiquidator as IUniversalLiquidatorV2)
      .connect(core.governance)
      ['configureSwap(address[],address)'](
      [WETH.address, SPELL.address],
      SUSHI_ROUTER.address,
    );
    await (core.universalLiquidator as IUniversalLiquidatorV2)
      .connect(core.governance)
      ['configureSwap(address[],address)'](
      [SPELL.address, WETH.address],
      SUSHI_ROUTER.address,
    );

    [strategyProxy, strategyMainnet] =
      await createStrategy<EthSpellSushiStrategyMainnet>('EthSpellSushiStrategyMainnet');

    const VaultV2Factory = await ethers.getContractFactory('VaultV2');
    const vaultImplementation = await VaultV2Factory.deploy() as IVault;
    [, , vaultV2] = await createVault(vaultImplementation, core, underlyingToken);
    await strategyMainnet.connect(core.governance)
      .initializeMainnetStrategy(core.storage.address, vaultV2.address, core.strategist.address);
    await core.controller.connect(core.governance).addVaultAndStrategy(vaultV2.address, strategyProxy.address);

    user = await ethers.getSigner(core.hhUser1.address);
    rewardPool = SUSHI_MINI_CHEF.connect(core.governance);

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#deployment', () => {
    it('should work properly', async () => {
      expect(await strategyMainnet.controller()).to.eq(core.controller.address);
      expect(await strategyMainnet.governance()).to.eq(core.governance.address);
      expect(await strategyMainnet.underlying()).to.eq(underlyingToken.address);
      expect(await strategyMainnet.vault()).to.eq(vaultV2.address);
      expect(await strategyMainnet.rewardPool()).to.eq(rewardPool.address);
      expect(await strategyMainnet.rewardTokens()).to.eql([SUSHI.address, SPELL.address]);
      expect(await strategyMainnet.strategist()).to.eq(core.strategist.address);
      expect(await strategyMainnet.underlying()).to.eq(ETH_SPELL_SLP.address);
      expect(await strategyMainnet.pid()).to.eq(pid);

      const pair = new BaseContract(
        underlyingToken.address,
        IUniswapV2Pair__factory.createInterface(),
        user,
      ) as IUniswapV2Pair;

      expect([tokenA.address, tokenB.address]).to.contain(await pair.token0());
      expect([tokenA.address, tokenB.address]).to.contain(await pair.token1());
    });
  });

  describe('deposit, compound, and withdraw', () => {
    it('should work', async () => {
      await setupWETHBalance(user, tokenAAmount, SUSHI_ROUTER);
      await setupSPELLBalance(user, tokenBAmount, SUSHI_ROUTER);
      await SUSHI_ROUTER.connect(user).addLiquidity(
        tokenA.address,
        tokenB.address,
        tokenAAmount,
        tokenBAmount,
        tokenAAmount.mul(9).div(10),
        tokenBAmount.mul(9).div(10),
        user.address,
        ethers.constants.MaxUint256,
      );

      const lpBalance1 = await underlyingToken.connect(user).balanceOf(user.address);
      await depositIntoVault(user, underlyingToken, vaultV2, lpBalance1);

      await vaultV2.connect(core.governance).rebalance(); // move funds to the strategy
      await strategyMainnet.connect(core.governance).enterRewardPool(); // deposit strategy funds into the reward pool

      const lpBalanceAfterReservesTakenOut = lpBalance1.mul('990').div('1000');
      expect(await rewardPoolBalanceOf(rewardPool, pid, strategyProxy)).to.eq(lpBalanceAfterReservesTakenOut);

      expect(await strategyMainnet.callStatic.getRewardPoolValues()).to.eql([ethers.constants.Zero]);

      const waitDurationSeconds = 86400; // 1 day in seconds
      const currentTimestamp = await getLatestTimestamp();
      await waitTime(waitDurationSeconds);
      expect(await getLatestTimestamp()).to.eq(currentTimestamp + waitDurationSeconds);

      const sushiReward = (await strategyMainnet.callStatic.getRewardPoolValues())[0];
      const sushiWhale = await impersonate(SushiWhaleAddress);
      const receivedETH = await getReceivedAmountBeforeHardWork(core, sushiWhale, SUSHI, sushiReward);

      await doHardWork(core, vaultV2, strategyProxy);

      const lpBalance2 = await vaultV2.underlyingBalanceWithInvestment();

      const amountHeldInVault = lpBalance1.sub(lpBalance1.mul('990').div('1000'));
      expect(await rewardPoolBalanceOf(rewardPool, pid, strategyProxy)).to.eq(lpBalance2.sub(amountHeldInVault));

      logYieldData(strategyName, lpBalance1, lpBalance2, waitDurationSeconds);

      const expectedApr = ethers.BigNumber.from('228500000000000000'); // 22.85%
      const expectedApy = ethers.BigNumber.from('256000000000000000'); // 25.6%

      expect(lpBalance2).to.be.gt(lpBalance1);
      expect(calculateApr(lpBalance2, lpBalance1, waitDurationSeconds)).to.be.gt(expectedApr);
      expect(calculateApy(lpBalance2, lpBalance1, waitDurationSeconds)).to.be.gt(expectedApy);

      // check the platform fee and strategist fees accrued properly
      await checkHardWorkResults(core, receivedETH);

      const fBalance = await vaultV2.connect(user).balanceOf(user.address);
      await vaultV2.connect(user).redeem(fBalance, user.address, user.address);
      expect(await underlyingToken.connect(user).balanceOf(user.address)).to.eq(lpBalance2);
    });
  });
});
