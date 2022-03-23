import { BaseContract } from 'ethers';
import fs from 'fs';
import { network, run } from 'hardhat';
import { IMainnetStrategy } from '../src/types';
import { VaultV2Implementation } from '../src/utils/constants';
import { CoreProtocol, createStrategy, createVault } from '../src/utils/harvest-utils';

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

export async function deployVaultAndStrategy(
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

  file[strategyName] = {
    ...file[strategyName],
    [chainId]: {
      strategy: strategy.address,
      vault: vaultProxy.address,
    },
  }

  fs.writeFileSync('./scripts/deployments.json', JSON.stringify(file, null, 2), { encoding: 'utf8', flag: 'w' });

  console.log(`========================= ${strategyName} =========================`)
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
