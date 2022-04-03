import { ethers } from 'hardhat';
import { STARGATE_S_USDC, STARGATE_S_USDT } from '../src/utils/constants';
import { CoreProtocolSetupConfigV2, setupCoreProtocol } from '../src/utils/harvest-utils';
import { deployVaultAndStrategyAndRewardPool, getStrategist } from './deploy-utils';


async function main() {
  const strategist = getStrategist();

  const core = await setupCoreProtocol(CoreProtocolSetupConfigV2);
  const chainId = (await ethers.provider.getNetwork()).chainId
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'UsdcStargateStrategyMainnet',
    STARGATE_S_USDC,
  );
  await deployVaultAndStrategyAndRewardPool(
    core,
    chainId,
    strategist,
    'UsdtStargateStrategyMainnet',
    STARGATE_S_USDT,
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
