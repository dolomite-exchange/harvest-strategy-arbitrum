import { artifacts } from 'hardhat';

const Vault = artifacts.require("IVault");
const VaultProxy = artifacts.require("VaultProxy");

export default async function(implementationAddress: string, ...args: any[]) {
  const fromParameter = args[args.length - 1]; // corresponds to {from: governance}
  const vaultAsProxy = await VaultProxy.new(implementationAddress, fromParameter);
  const vault = await Vault.at(vaultAsProxy.address);
  await vault.initializeVault(...args);
  return vault;
};
