// Utilities
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { CrvTriCryptoPriceOracle, IMainnetStrategy, TestTriCryptoFlashLoan, VaultV1 } from '../../../../src/types';
import {
  CRV_TRI_CRYPTO_POOL,
  CRV_TRI_CRYPTO_TOKEN, DolomiteMarginAddress,
  OneEth,
  USDC,
  USDT,
  VaultV2Implementation,
  WBTC,
  WETH,
} from '../../../../src/utils/constants';
import {
  CoreProtocol,
  createStrategy,
  createVault,
  DefaultCoreProtocolSetupConfig,
  setupCoreProtocol,
  setupWETHBalance,
} from '../../../../src/utils/harvest-utils';
import { impersonate, revertToSnapshotAndCapture, setEtherBalance, snapshot } from '../../../../src/utils/utils';

describe('CrvTriCryptoPriceOracle', () => {

  let core: CoreProtocol;
  let strategy: IMainnetStrategy;
  let vaultV1: VaultV1;
  let priceOracle: CrvTriCryptoPriceOracle;

  let snapshotId: string;

  const priceThreshold = '10000000000000000'; // 1%
  const expectedOraclePriceNoDeviation = ethers.BigNumber.from('1535445967567637237507'); // $1,535.44...

  before(async () => {
    core = await setupCoreProtocol({
      ...DefaultCoreProtocolSetupConfig,
      blockNumber: 8467100,
    });

    [, strategy] = await createStrategy<IMainnetStrategy>('TriCryptoStrategyMainnet');
    [, vaultV1] = await createVault(VaultV2Implementation, core, CRV_TRI_CRYPTO_TOKEN);
    await strategy.initializeMainnetStrategy(core.storage.address, vaultV1.address, core.hhUser1.address);
    await core.controller.connect(core.governance).addVaultAndStrategy(vaultV1.address, strategy.address);

    const factory = await ethers.getContractFactory('CrvTriCryptoPriceOracle');
    priceOracle = await factory.deploy(DolomiteMarginAddress, priceThreshold) as CrvTriCryptoPriceOracle;

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#getFTokenParts', () => {
    it('should work', async () => {
      expect(await priceOracle.getFTokenParts(vaultV1.address))
        .to
        .eql([USDT.address, WBTC.address, WETH.address]);
    });
  });

  describe('#getPrice', () => {
    it('should work for normal case', async () => {
      expect((await priceOracle.getPrice(vaultV1.address)).value).to.eq(expectedOraclePriceNoDeviation);
    });

    it('should work for normal case when share price is gt 1', async () => {
      const whale = await impersonate('0xc4b7bedce1e0face52a465d0d9af4a978bca303b');
      await CRV_TRI_CRYPTO_TOKEN.connect(whale).approve(vaultV1.address, ethers.constants.MaxUint256);
      await CRV_TRI_CRYPTO_TOKEN.connect(whale).transfer(strategy.address, OneEth.div(10));
      await vaultV1.connect(whale).deposit(OneEth);

      const fExchangeRate = '1100000000000000000'; // 1.1
      expect(await vaultV1.getPricePerFullShare()).to.eq(fExchangeRate);

      expect((await priceOracle.getPrice(vaultV1.address)).value)
        .to
        .eq(expectedOraclePriceNoDeviation.mul(fExchangeRate).div(OneEth));
    });

    it('should work for WETH flash loan when share price is gt 1', async () => {
      const TestTriCryptoFlashLoanFactory = await ethers.getContractFactory('TestTriCryptoFlashLoan');
      const flashLoan = await TestTriCryptoFlashLoanFactory.deploy() as TestTriCryptoFlashLoan;

      const whale = await impersonate('0xc4b7bedce1e0face52a465d0d9af4a978bca303b');
      await CRV_TRI_CRYPTO_TOKEN.connect(whale).approve(vaultV1.address, ethers.constants.MaxUint256);
      await CRV_TRI_CRYPTO_TOKEN.connect(whale).transfer(strategy.address, OneEth.div(10));
      await vaultV1.connect(whale).deposit(OneEth);

      const fExchangeRate = '1100000000000000000'; // 1.1
      expect(await vaultV1.getPricePerFullShare()).to.eq(fExchangeRate);

      const bytes = ethers.utils.defaultAbiCoder.encode([
        'uint256',
        'uint256',
        'uint256',
        'address',
        'address',
      ], [
        '2', // WETH
        '0', // USDT
        '0', // minOutput
        vaultV1.address, // fToken
        priceOracle.address, // priceOracle
      ]);

      const loanAmount = ethers.BigNumber.from('10000000000000000000000'); // 10,000 WETH
      await setEtherBalance(core.hhUser1.address, loanAmount);
      await setupWETHBalance(core.hhUser1, loanAmount.sub(OneEth), flashLoan);
      await flashLoan.connect(core.hhUser1).executeFlashLoan(USDC.address, WETH.address, '0', loanAmount, bytes);

      expect(await flashLoan.priceBeforeSwap()).to.eq(expectedOraclePriceNoDeviation.mul(fExchangeRate).div(OneEth));

      const normalPriceWithExchangeRate = expectedOraclePriceNoDeviation.mul(fExchangeRate).div(OneEth);
      const priceAfterSwap = await flashLoan.priceAfterSwap();
      let percentDiff;
      if (normalPriceWithExchangeRate > priceAfterSwap) {
        percentDiff = normalPriceWithExchangeRate.mul(OneEth).div(priceAfterSwap);
      } else {
        percentDiff = priceAfterSwap.mul(OneEth).div(normalPriceWithExchangeRate);
      }
      expect(percentDiff).to.be.lt(OneEth.add(priceThreshold)); // the flash loan price is less than priceThreshold
    });
  });
});
