import { ethers } from 'hardhat';
import { TwoPoolStrategyMainnet } from '../src/types';
import {
  CRV_EURS_USD_TOKEN,
  CRV_REN_WBTC_TOKEN,
  CRV_TRI_CRYPTO_TOKEN,
  CRV_TWO_POOL_TOKEN,
} from '../src/utils/constants';
import { DefaultCoreProtocolSetupConfig, setupCoreProtocol } from '../src/utils/harvest-utils';
import { deployVaultAndStrategyAndRewardPool, getStrategist } from './deploy-utils';


async function main() {
  const strategist = getStrategist();

  const core = await setupCoreProtocol(DefaultCoreProtocolSetupConfig);
  const chainId = (await ethers.provider.getNetwork()).chainId
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'EursUsdPoolStrategyMainnet',
    CRV_EURS_USD_TOKEN,
  );
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'RenWbtcPoolStrategyMainnet',
    CRV_REN_WBTC_TOKEN,
  );
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'TriCryptoStrategyMainnet',
    CRV_TRI_CRYPTO_TOKEN,
  );
  await deployVaultAndStrategyAndRewardPool(core, chainId, strategist, 'TwoPoolStrategyMainnet', CRV_TWO_POOL_TOKEN);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
