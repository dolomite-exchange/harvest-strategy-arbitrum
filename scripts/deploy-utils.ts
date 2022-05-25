import { BaseContract } from 'ethers';
import fs from 'fs';
import { network, run } from 'hardhat';
import { IMainnetStrategy, PotPoolV1 } from '../src/types';
import { aiFARM, PotPoolV1Implementation, StorageAddress, VaultV2Implementation } from '../src/utils/constants';
import { CoreProtocol, createPotPool, createStrategy, createVault } from '../src/utils/harvest-utils';
import { OneWeekSeconds } from '../src/utils/no-deps-constants';

type StrategyName = string;
type ChainId = string;

async function verifyContract(address: string, constructorArguments: any[]) {
  try {
    await run('verify:verify', {
      address: address,
      constructorArguments: constructorArguments,
    });
  } catch (e: any) {
    if (e?.message.includes('Already Verified')) {
      console.log('EtherscanVerification: Swallowing already verified error');
    } else {
      throw e;
    }
  }
}

export function getStrategist(): string {
  const strategist = process.env.STRATEGIST;
  if (!strategist) {
    throw new Error('No strategist defined');
  }
  return strategist;
}

export async function deployVaultAndStrategyAndRewardPool(
  core: CoreProtocol,
  chainId: number,
  strategist: string,
  strategyName: StrategyName,
  underlying: BaseContract,
) {
  const fileBuffer = fs.readFileSync('./scripts/deployments.json');

  let file: Record<StrategyName, Record<ChainId, any>>;
  try {
    file = JSON.parse(fileBuffer.toString()) ?? {};
  } catch (e) {
    file = {};
  }

  if (file[strategyName]?.[chainId.toString()]) {
    console.log(`Strategy ${strategyName} has already been deployed to chainId ${chainId}. Skipping...`);
    return
  }

  console.log(`Deploying strategy ${strategyName} to chainId ${chainId}...`);

  const [strategyProxy, strategy, rawStrategy] = await createStrategy<IMainnetStrategy>(strategyName);
  const [vaultProxy] = await createVault(VaultV2Implementation, core, underlying);
  await strategy.initializeMainnetStrategy(
    core.storage.address,
    vaultProxy.address,
    strategist,
  );

  const [potPoolProxy] = await createPotPool<PotPoolV1>(
    PotPoolV1Implementation,
    [aiFARM.address],
    vaultProxy.address,
    OneWeekSeconds,
    [],
    StorageAddress,
  );

  file[strategyName] = {
    ...file[strategyName],
    [chainId]: {
      potPool: potPoolProxy.address,
      strategy: strategy.address,
      vault: vaultProxy.address,
    },
  }

  if (network.name !== 'hardhat') {
    fs.writeFileSync('./scripts/deployments.json', JSON.stringify(file, null, 2), { encoding: 'utf8', flag: 'w' });
  }

  console.log(`========================= ${strategyName} =========================`)
  console.log('Pot Pool:', potPoolProxy.address);
  console.log('Vault:', vaultProxy.address);
  console.log('Strategy:', strategy.address);
  console.log('='.repeat(52 + strategyName.length));

  if (network.name !== 'hardhat') {
    await verifyContract(rawStrategy.address, []);
    await verifyContract(strategyProxy.address, [rawStrategy.address]);
    await verifyContract(vaultProxy.address, [VaultV2Implementation.address]);
  } else {
    console.log('Skipping Etherscan verification...')
  }
}
