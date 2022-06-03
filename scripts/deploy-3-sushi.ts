import { ethers } from 'hardhat';
import {
  ETH_DAI_SLP,
  ETH_G_OHM_SLP,
  ETH_MAGIC_SLP,
  ETH_MIM_SLP,
  ETH_SPELL_SLP,
  ETH_SUSHI_SLP,
} from '../src/utils/constants';
import { CoreProtocolSetupConfigV2, setupCoreProtocol } from '../src/utils/harvest-utils';
import { deployVaultAndStrategyAndRewardPool, getStrategist } from './deploy-utils';


async function main() {
  const strategist = getStrategist();

  const core = await setupCoreProtocol(CoreProtocolSetupConfigV2);
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log('Beginning ether balance:', (await core.hhUser1.getBalance()).toString());
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'EthDaiSushiStrategyMainnet',
    ETH_DAI_SLP,
  );
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'EthGOhmSushiStrategyMainnet',
    ETH_G_OHM_SLP,
  );
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'EthMagicSushiStrategyMainnet',
    ETH_MAGIC_SLP,
  );
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'EthMimSushiStrategyMainnet',
    ETH_MIM_SLP,
  );
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'EthSpellSushiStrategyMainnet',
    ETH_SPELL_SLP,
  );
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'EthSushiSushiStrategyMainnet',
    ETH_SUSHI_SLP,
  );
  console.log('Ending ether balance:', (await core.hhUser1.getBalance()).toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
