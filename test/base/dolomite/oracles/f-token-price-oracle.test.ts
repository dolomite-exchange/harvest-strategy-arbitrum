// Utilities
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { FTokenPriceOracle, IMainnetStrategy, VaultV1 } from '../../../../src/types';
import {
  CRV_TRI_CRYPTO_TOKEN,
  DolomiteMarginAddress,
  OneEth,
  VaultV2Implementation,
} from '../../../../src/utils/constants';
import {
  CoreProtocol,
  createStrategy,
  createVault,
  DefaultCoreProtocolSetupConfig,
  setupCoreProtocol,
} from '../../../../src/utils/harvest-utils';
import { revertToSnapshotAndCapture, snapshot } from '../../../../src/utils/utils';

describe('FTokenPriceOracle', () => {

  let core: CoreProtocol;
  let strategy: IMainnetStrategy;
  let vaultV1: VaultV1;
  let priceOracle: FTokenPriceOracle;

  let snapshotId: string;

  const maxPriceDeviationThreshold = ethers.BigNumber.from('10000000000000000'); // 1%
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

    const factory = await ethers.getContractFactory('TestFTokenPriceOracle');
    priceOracle = await factory.connect(core.governance).deploy(
      DolomiteMarginAddress,
      maxPriceDeviationThreshold,
    ) as FTokenPriceOracle;

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#deployment', () => {
    it('should work', async () => {
      expect(await priceOracle.dolomiteMargin()).to.eq(DolomiteMarginAddress);
      expect(await priceOracle.maxDeviationThreshold()).to.eq(maxPriceDeviationThreshold);
      expect(await priceOracle.owner()).to.eq(core.governance.address);
    });
  });

  describe('#getFTokenParts', () => {
    it('should work', async () => {
      expect(await priceOracle.getFTokenParts(vaultV1.address)).to.eql([]);
    });
  });

  describe('#getPrice', () => {
    it('should work', async () => {
      expect((await priceOracle.getPrice(vaultV1.address)).value).to.eql(OneEth.pow(2));
    });
  });

  describe('#setMaxDeviationThreshold', () => {
    it('should work', async () => {
      const result = await priceOracle.setMaxDeviationThreshold(maxPriceDeviationThreshold.mul(2));
      await expect(result).to.emit(priceOracle, 'MaxDeviationThresholdSet').withArgs(maxPriceDeviationThreshold.mul(2));
      expect(await priceOracle.maxDeviationThreshold()).to.eq(maxPriceDeviationThreshold.mul(2));
    });

    it('should fail when too low', async () => {
      await expect(priceOracle.setMaxDeviationThreshold(maxPriceDeviationThreshold.div(2)))
        .to.revertedWith('max deviation threshold too low');
    });

    it('should fail when not call by owner', async () => {
      await expect(priceOracle.connect(core.hhUser1).setMaxDeviationThreshold(maxPriceDeviationThreshold.mul(2)))
        .to.revertedWith('Ownable: caller is not the owner');
    });
  });
});
